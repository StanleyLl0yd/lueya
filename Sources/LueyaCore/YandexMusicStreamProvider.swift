import CryptoKit
import Foundation

public struct TrackMetadata: Sendable, Equatable {
    public let id: String
    public let title: String
    public let artists: [String]
    public let durationMilliseconds: Int?
    public let available: Bool
    public let premiumRequired: Bool
}

public enum AudioQuality: String, Sendable {
    case lossless
    case hq
    case nq
}

public enum AudioCodec: String, Sendable {
    // Only formats expected to be playable directly by AVFoundation.
    // FLAC, including FLAC in MP4, must be proven on both target macOS versions.
    case aacMP4 = "aac-mp4"
    case heAACMP4 = "he-aac-mp4"
    case aac
    case heAAC = "he-aac"
    case mp3
}

public struct PlayableSource: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let url: URL
    public let quality: AudioQuality
    public let codec: AudioCodec
    public let bitrateKbps: Int?
    public let resolvedAt: Date

    // CDN URLs contain short-lived bearer-like signatures. Never print them.
    public var description: String {
        "PlayableSource(quality: \(quality.rawValue), codec: \(codec.rawValue), url: redacted)"
    }
    public var debugDescription: String { description }

    init(url: URL, quality: AudioQuality, codec: AudioCodec, bitrateKbps: Int?, resolvedAt: Date) {
        self.url = url
        self.quality = quality
        self.codec = codec
        self.bitrateKbps = bitrateKbps
        self.resolvedAt = resolvedAt
    }

    public func isFresh(now: Date = Date()) -> Bool {
        // This is a conservative client-side reuse limit, not a provider-guaranteed TTL.
        now >= resolvedAt && now.timeIntervalSince(resolvedAt) < 45
    }
}

public struct ResolvedTrack: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let metadata: TrackMetadata
    public let source: PlayableSource

    public var description: String {
        "ResolvedTrack(id: \(metadata.id), source: \(source.description))"
    }
    public var debugDescription: String { description }
}

public enum MusicStreamError: Error, Equatable, Sendable {
    case invalidTrackID
    case invalidToken
    case invalidResponse
    case invalidPayload
    case unavailable
    case unsupportedEncryptedTransport
    case unsupportedCodec
    case untrustedMediaURL
    case unauthorized
    case forbidden
    case rateLimited
    case httpStatus(Int)
}

public enum MusicCDNPolicy {
    public static func accepts(_ url: URL) -> Bool {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme?.lowercased() == "https",
              parts.user == nil, parts.password == nil, parts.port == nil,
              parts.fragment == nil, let host = parts.host?.lowercased(),
              !parts.path.isEmpty else {
            return false
        }

        // Narrow provider-owned CDN zones. Do not accept generic yandex.net,
        // DNS lookalikes, IP addresses or third-party signed URLs.
        return host.hasSuffix(".strm.yandex.net") ||
            host.hasSuffix(".storage.yandex.net")
    }
}

public protocol MusicProvider: Sendable {
    func resolveTrack(id: String, accessToken: String) async throws -> ResolvedTrack
}

/// Experimental adapter for a documented but unofficial provider interface.
/// No media bytes, OAuth headers or cookies are downloaded or cached here.
public struct YandexMusicStreamProvider: MusicProvider {
    private static let apiOrigin = "api.music.yandex.net"
    private static let trackURL = URL(string: "https://api.music.yandex.net/tracks")!
    private static let fileInfoURL = URL(string: "https://api.music.yandex.net/get-file-info")!

    // Identifiers published in the upstream community client, NOT lueya keys.
    // Can change or be revoked by the service.
    private static let desktopClient = "YandexMusicDesktopAppWindows/5.95.0"
    private static let publicSigningKey = "kzqU4XhfCaY6B6JTHODeq5"
    private static let requestedCodecs = ["flac-mp4", "aac-mp4", "mp3"]

    private let transport: any MusicHTTPTransport
    private let now: @Sendable () -> Date

    public init(
        transport: any MusicHTTPTransport = EphemeralMusicHTTPTransport(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.transport = transport
        self.now = now
    }

    public func resolveTrack(id: String, accessToken: String) async throws -> ResolvedTrack {
        let trackID = try Self.validatedTrackID(id)
        try Self.validateToken(accessToken)
        try Task.checkCancellation()

        let track = try await trackMetadata(id: trackID, accessToken: accessToken)
        guard track.available else { throw MusicStreamError.unavailable }

        let source = try await resolveSource(id: trackID, accessToken: accessToken)
        return ResolvedTrack(metadata: track, source: source)
    }

    private func trackMetadata(id: String, accessToken: String) async throws -> TrackMetadata {
        var request = Self.makeAPIRequest(to: Self.trackURL, accessToken: accessToken)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("track-ids=\(id)".utf8)

        let data = try await responseData(for: request)
        guard let payload = try? JSONDecoder().decode(Envelope<[TrackPayload]>.self, from: data),
              let track = payload.result?.first,
              track.id.value == id else {
            throw MusicStreamError.invalidPayload
        }
        return TrackMetadata(
            id: id,
            title: track.title ?? "Untitled",
            artists: (track.artists ?? []).compactMap(\.name),
            durationMilliseconds: track.durationMs,
            available: track.available != false,
            premiumRequired: track.availableForPremiumUsers == true
        )
    }

    private func resolveSource(id: String, accessToken: String) async throws -> PlayableSource {
        var encounteredEncrypted = false
        var encounteredUnsupportedCodec = false
        var encounteredUntrustedURL = false

        // A format request is explicitly raw. No 'encraw' decryption is supported.
        // The service chooses the actual quality/codec, which is checked below.
        for preference in ["lossless", "hq", "nq"] {
            try Task.checkCancellation()
            let requestedAt = now()
            let timestamp = Int64(requestedAt.timeIntervalSince1970)
            let codecs = Self.requestedCodecs
            let message = "\(timestamp)\(id)\(preference)\(codecs.joined())raw"
            let signature = HMAC<SHA256>.authenticationCode(
                for: Data(message.utf8),
                using: SymmetricKey(data: Data(Self.publicSigningKey.utf8))
            )
            let encodedSignature = String(Data(signature).base64EncodedString().dropLast())

            var components = URLComponents(url: Self.fileInfoURL, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "ts", value: String(timestamp)),
                URLQueryItem(name: "trackId", value: id),
                URLQueryItem(name: "quality", value: preference),
                URLQueryItem(name: "codecs", value: codecs.joined(separator: ",")),
                URLQueryItem(name: "transports", value: "raw"),
                URLQueryItem(name: "sign", value: encodedSignature)
            ]
            guard let url = components.url else { throw MusicStreamError.invalidResponse }

            var request = Self.makeAPIRequest(to: url, accessToken: accessToken)
            request.setValue(Self.desktopClient, forHTTPHeaderField: "X-Yandex-Music-Client")
            let data = try await responseData(for: request)

            guard let response = try? JSONDecoder().decode(Envelope<FileInfoPayload>.self, from: data) else {
                throw MusicStreamError.invalidPayload
            }
            guard let info = response.result?.downloadInfo else { continue }
            guard info.transport == "raw" else {
                encounteredEncrypted = true
                continue
            }
            guard let codec = AudioCodec(rawValue: info.codec ?? ""),
                  let quality = AudioQuality(rawValue: info.quality ?? "") else {
                encounteredUnsupportedCodec = true
                continue
            }
            let candidates = (info.urls ?? []) + [info.url].compactMap { $0 }
            if let accepted = candidates.compactMap(URL.init(string:)).first(where: MusicCDNPolicy.accepts) {
                return PlayableSource(
                    url: accepted,
                    quality: quality,
                    codec: codec,
                    bitrateKbps: info.bitrate,
                    resolvedAt: requestedAt
                )
            }
            encounteredUntrustedURL = true
        }

        if encounteredEncrypted { throw MusicStreamError.unsupportedEncryptedTransport }
        if encounteredUnsupportedCodec { throw MusicStreamError.unsupportedCodec }
        if encounteredUntrustedURL { throw MusicStreamError.untrustedMediaURL }
        throw MusicStreamError.unavailable
    }

    private func responseData(for request: URLRequest) async throws -> Data {
        try Task.checkCancellation()
        let (data, response) = try await transport.data(for: request)
        guard let requestURL = request.url, let responseURL = response.url,
              responseURL.scheme == "https", responseURL.host == Self.apiOrigin,
              responseURL.port == nil, responseURL.user == nil,
              responseURL.password == nil,
              responseURL.path == requestURL.path,
              responseURL.query == requestURL.query else {
            throw MusicStreamError.invalidResponse
        }
        switch response.statusCode {
        case 200: return data
        case 401: throw MusicStreamError.unauthorized
        case 403: throw MusicStreamError.forbidden
        case 429: throw MusicStreamError.rateLimited
        default: throw MusicStreamError.httpStatus(response.statusCode)
        }
    }

    private static func makeAPIRequest(to url: URL, accessToken: String) -> URLRequest {
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 15
        )
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("OAuth \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private static func validatedTrackID(_ id: String) throws -> String {
        // A single numeric identifier, not an arbitrary URL or path.
        guard id.count >= 1, id.count <= 19,
              id.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
              let value = Int64(id), value > 0 else {
            throw MusicStreamError.invalidTrackID
        }
        return String(value)
    }

    private static func validateToken(_ token: String) throws {
        guard !token.isEmpty,
              token.utf8.allSatisfy({ $0 >= 0x21 && $0 <= 0x7E }) else {
            throw MusicStreamError.invalidToken
        }
    }

    private struct Envelope<T: Decodable>: Decodable {
        let result: T?
    }

    private struct StringOrInteger: Decodable {
        let value: String

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                value = string
            } else {
                value = String(try container.decode(Int64.self))
            }
        }
    }

    private struct TrackPayload: Decodable {
        struct Artist: Decodable { let name: String? }
        let id: StringOrInteger
        let title: String?
        let artists: [Artist]?
        let durationMs: Int?
        let available: Bool?
        let availableForPremiumUsers: Bool?
    }

    private struct FileInfoPayload: Decodable {
        let downloadInfo: DownloadInfo?
    }

    private struct DownloadInfo: Decodable {
        let quality: String?
        let codec: String?
        let bitrate: Int?
        let transport: String?
        let url: String?
        let urls: [String]?
    }
}
