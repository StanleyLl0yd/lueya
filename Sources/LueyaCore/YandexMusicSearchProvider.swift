import Foundation

/// Lightweight, authenticated catalog results. No artwork or audio is persisted.
public struct MusicSearchTrack: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let artists: [String]
    public let durationMilliseconds: Int?

    public var artistName: String {
        artists.isEmpty ? "Unknown artist" : artists.joined(separator: ", ")
    }

    public init(id: String, title: String, artists: [String], durationMilliseconds: Int?) {
        self.id = id
        self.title = title
        self.artists = artists
        self.durationMilliseconds = durationMilliseconds
    }
}

public enum MusicSearchError: Error, Equatable, Sendable {
    case invalidQuery
    case invalidToken
    case invalidResponse
    case invalidPayload
    case unauthorized
    case forbidden
    case rateLimited
    case httpStatus(Int)
}

/// Read-only search over the provider's unofficial interface.
/// The response must match the requested HTTPS origin and URL exactly.
public struct YandexMusicSearchProvider: Sendable {
    private static let origin = URL(string: "https://api.music.yandex.net/search")!
    private let transport: any MusicHTTPTransport

    public init(transport: any MusicHTTPTransport = EphemeralMusicHTTPTransport()) {
        self.transport = transport
    }

    public func tracks(matching input: String, accessToken: String) async throws -> [MusicSearchTrack] {
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, query.count <= 120,
              !query.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw MusicSearchError.invalidQuery
        }
        guard !accessToken.isEmpty,
              accessToken.utf8.allSatisfy({ $0 >= 0x21 && $0 <= 0x7e }) else {
            throw MusicSearchError.invalidToken
        }
        try Task.checkCancellation()

        var urlParts = URLComponents(url: Self.origin, resolvingAgainstBaseURL: false)!
        urlParts.queryItems = [
            URLQueryItem(name: "text", value: query),
            URLQueryItem(name: "type", value: "track"),
            URLQueryItem(name: "page", value: "0")
        ]
        guard let url = urlParts.url else { throw MusicSearchError.invalidQuery }
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 15
        )
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("OAuth \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await transport.data(for: request)
        try Task.checkCancellation()

        guard response.url == url else { throw MusicSearchError.invalidResponse }
        switch response.statusCode {
        case 200: break
        case 401: throw MusicSearchError.unauthorized
        case 403: throw MusicSearchError.forbidden
        case 429: throw MusicSearchError.rateLimited
        default: throw MusicSearchError.httpStatus(response.statusCode)
        }

        guard data.count <= 1_000_000,
              let payload = try? JSONDecoder().decode(SearchEnvelope.self, from: data),
              let searchResult = payload.result else {
            throw MusicSearchError.invalidPayload
        }

        var unique = Set<String>()
        return (searchResult.tracks?.results ?? [])
            .compactMap { result -> MusicSearchTrack? in
                guard let id = result.id?.value,
                      id.count <= 19, let numeric = Int64(id), numeric > 0,
                      id.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
                      let rawTitle = result.title?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !rawTitle.isEmpty, result.available != false else { return nil }
                let normalized = String(numeric)
                guard unique.insert(normalized).inserted else { return nil }
                return MusicSearchTrack(
                    id: normalized,
                    title: String(rawTitle.prefix(200)),
                    artists: (result.artists ?? []).compactMap { artist in
                        artist.name.map { String($0.prefix(100)) }
                    },
                    durationMilliseconds: result.durationMs
                )
            }
            .prefix(20)
            .map { $0 }
    }

    private struct SearchEnvelope: Decodable {
        let result: SearchPayload?
    }

    private struct SearchPayload: Decodable {
        let tracks: TrackResults?
    }

    private struct TrackResults: Decodable {
        let results: [TrackResult]?
    }

    private struct TrackResult: Decodable {
        let id: StringOrNumber?
        let title: String?
        let artists: [Artist]?
        let durationMs: Int?
        let available: Bool?
    }

    private struct Artist: Decodable {
        let name: String?
    }

    private struct StringOrNumber: Decodable {
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
}
