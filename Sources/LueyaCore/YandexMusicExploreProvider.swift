import Foundation

public enum MusicExploreError: Error, Equatable, Sendable {
    case invalidToken
    case invalidResponse
    case invalidPayload
    case invalidSession
    case unauthorized
    case forbidden
    case rateLimited
    case httpStatus(Int)
}

public enum MusicWaveFeedbackEvent: String, Sendable {
    case radioStarted
    case trackStarted
    case trackFinished
    case skip
}

public struct MusicWaveSession: Equatable, Sendable {
    public let id: String
    public let batchID: String?
    public let tracks: [MusicSearchTrack]
    public let queueIdentifiers: [String]
    public let terminated: Bool

    public init(
        id: String, batchID: String?, tracks: [MusicSearchTrack],
        queueIdentifiers: [String], terminated: Bool
    ) {
        self.id = id
        self.batchID = batchID
        self.tracks = tracks
        self.queueIdentifiers = queueIdentifiers
        self.terminated = terminated
    }
}

public struct MusicWaveBatch: Equatable, Sendable {
    public let batchID: String?
    public let tracks: [MusicSearchTrack]
    public let queueIdentifiers: [String]
    public let terminated: Bool

    public init(
        batchID: String?, tracks: [MusicSearchTrack],
        queueIdentifiers: [String], terminated: Bool
    ) {
        self.batchID = batchID
        self.tracks = tracks
        self.queueIdentifiers = queueIdentifiers
        self.terminated = terminated
    }
}

/// Read-only listening history and the authenticated My Wave radio session.
/// Session feedback is limited to the events needed to keep recommendations relevant.
public struct YandexMusicExploreProvider: Sendable {
    private static let origin = URL(string: "https://api.music.yandex.net")!
    private let transport: any MusicHTTPTransport

    public init(transport: any MusicHTTPTransport = EphemeralMusicHTTPTransport()) {
        self.transport = transport
    }

    public func recentTracks(
        accessToken: String, limit: Int = 8
    ) async throws -> [MusicSearchTrack] {
        try Self.validateToken(accessToken)
        guard (1...20).contains(limit) else { throw MusicExploreError.invalidPayload }

        var components = URLComponents(
            url: Self.origin.appendingPathComponent("music-history"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "fullModelsCount", value: String(limit))
        ]
        guard let url = components.url else { throw MusicExploreError.invalidResponse }
        let data = try await perform(url: url, method: "GET", token: accessToken)
        guard let result = try? Self.decode(HistoryEnvelope.self, from: data).result,
              let tabs = result.historyTabs else {
            throw MusicExploreError.invalidPayload
        }

        var seen = Set<String>()
        var tracks: [MusicSearchTrack] = []
        for tab in tabs {
            for group in tab.items ?? [] {
                for item in group.tracks ?? [] {
                    guard item.type == "track",
                          let fullModel = item.data?.fullModel,
                          let track = Self.decodeTrack(fullModel),
                          seen.insert(track.id).inserted else { continue }
                    tracks.append(track)
                    if tracks.count == limit { return tracks }
                }
            }
        }
        return tracks
    }

    public func startMyWave(accessToken: String) async throws -> MusicWaveSession {
        try Self.validateToken(accessToken)
        let url = Self.origin.appendingPathComponent("rotor/session/new")
        let body = try JSONEncoder().encode(NewWaveRequest(
            seeds: ["user:onyourwave"],
            includeTracksInResponse: true,
            includeWaveModel: true,
            interactive: true
        ))
        let data = try await perform(
            url: url, method: "POST", token: accessToken, body: body
        )
        guard let result = try? Self.decode(WaveSessionEnvelope.self, from: data).result,
              let sessionID = result.radioSessionId,
              Self.validatedSessionID(sessionID) != nil else {
            throw MusicExploreError.invalidPayload
        }
        let tracks = Self.decodeSequence(result.sequence ?? [])
        return MusicWaveSession(
            id: sessionID,
            batchID: result.batchId,
            tracks: tracks,
            queueIdentifiers: tracks.map(\.radioQueueIdentifier),
            terminated: result.terminated ?? false
        )
    }

    public func nextMyWaveBatch(
        sessionID: String, queue: [String], accessToken: String
    ) async throws -> MusicWaveBatch {
        guard let id = Self.validatedSessionID(sessionID),
              queue.count <= 500,
              queue.allSatisfy({ Self.validatedQueueIdentifier($0) != nil }) else {
            throw MusicExploreError.invalidSession
        }
        try Self.validateToken(accessToken)
        let url = Self.origin
            .appendingPathComponent("rotor/session")
            .appendingPathComponent(id)
            .appendingPathComponent("tracks")
        let body = try JSONEncoder().encode(NextWaveRequest(queue: Array(queue.suffix(100))))
        let data = try await perform(
            url: url, method: "POST", token: accessToken, body: body
        )
        guard let result = try? Self.decode(WaveBatchEnvelope.self, from: data).result,
              result.unknownSession != true else {
            throw MusicExploreError.invalidSession
        }
        let tracks = Self.decodeSequence(result.sequence ?? [])
        return MusicWaveBatch(
            batchID: result.batchId,
            tracks: tracks,
            queueIdentifiers: tracks.map(\.radioQueueIdentifier),
            terminated: result.terminated ?? false
        )
    }

    public func sendFeedback(
        sessionID: String,
        event: MusicWaveFeedbackEvent,
        trackIdentifier: String? = nil,
        totalPlayedSeconds: Double? = nil,
        batchID: String? = nil,
        accessToken: String
    ) async throws {
        guard let id = Self.validatedSessionID(sessionID) else {
            throw MusicExploreError.invalidSession
        }
        try Self.validateToken(accessToken)

        switch event {
        case .radioStarted:
            guard trackIdentifier == nil, totalPlayedSeconds == nil else {
                throw MusicExploreError.invalidPayload
            }
        case .trackStarted:
            guard let trackIdentifier,
                  Self.validatedQueueIdentifier(trackIdentifier) != nil,
                  totalPlayedSeconds == nil else {
                throw MusicExploreError.invalidPayload
            }
        case .trackFinished, .skip:
            guard let trackIdentifier,
                  Self.validatedQueueIdentifier(trackIdentifier) != nil,
                  let totalPlayedSeconds,
                  totalPlayedSeconds.isFinite, totalPlayedSeconds >= 0 else {
                throw MusicExploreError.invalidPayload
            }
        }

        let url = Self.origin
            .appendingPathComponent("rotor/session")
            .appendingPathComponent(id)
            .appendingPathComponent("feedback")
        let eventBody = FeedbackEvent(
            type: event.rawValue,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            trackId: trackIdentifier,
            totalPlayedSeconds: totalPlayedSeconds
        )
        let body = try JSONEncoder().encode(FeedbackRequest(
            event: eventBody, batchId: batchID
        ))
        _ = try await perform(url: url, method: "POST", token: accessToken, body: body)
    }

    private func perform(
        url: URL, method: String, token: String, body: Data? = nil
    ) async throws -> Data {
        try Task.checkCancellation()
        guard url.scheme == "https", url.host == "api.music.yandex.net",
              url.port == nil, url.user == nil, url.password == nil,
              url.fragment == nil else {
            throw MusicExploreError.invalidResponse
        }
        var request = URLRequest(
            url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15
        )
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await transport.data(for: request)
        try Task.checkCancellation()
        guard response.url == url else { throw MusicExploreError.invalidResponse }
        switch response.statusCode {
        case 200: break
        case 401: throw MusicExploreError.unauthorized
        case 403: throw MusicExploreError.forbidden
        case 429: throw MusicExploreError.rateLimited
        default: throw MusicExploreError.httpStatus(response.statusCode)
        }
        guard !data.isEmpty, data.count <= 2_000_000 else {
            throw MusicExploreError.invalidPayload
        }
        return data
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: data)
    }

    private static func validateToken(_ token: String) throws {
        guard !token.isEmpty,
              token.utf8.allSatisfy({ $0 >= 0x21 && $0 <= 0x7e }) else {
            throw MusicExploreError.invalidToken
        }
    }

    private static func validatedSessionID(_ input: String) -> String? {
        guard !input.isEmpty, input.utf8.count <= 128,
              input.utf8.allSatisfy({
                  ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90) ||
                  ($0 >= 97 && $0 <= 122) || $0 == 45 || $0 == 95
              }) else { return nil }
        return input
    }

    private static func validatedQueueIdentifier(_ input: String) -> String? {
        let parts = input.split(separator: ":", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count) else { return nil }
        let ids = parts.compactMap { part -> String? in
            let value = String(part)
            guard value.count <= 19,
                  value.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
                  let number = Int64(value), number > 0 else { return nil }
            return String(number)
        }
        guard ids.count == parts.count else { return nil }
        return ids.joined(separator: ":")
    }

    private static func decodeSequence(_ sequence: [SequencePayload]) -> [MusicSearchTrack] {
        var seen = Set<String>()
        return sequence.compactMap { item in
            guard item.type == "track", let payload = item.track,
                  let track = decodeTrack(payload),
                  seen.insert(track.id).inserted else { return nil }
            return track
        }.prefix(30).map { $0 }
    }

    private static func decodeTrack(
        _ payload: TrackPayload, fallbackAlbum: MusicSearchAlbum? = nil
    ) -> MusicSearchTrack? {
        guard let rawID = payload.id?.value,
              let id = validatedQueueIdentifier(rawID)?.split(separator: ":").first.map(String.init),
              let title = payload.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty, payload.available != false else { return nil }

        let album = payload.albums?.compactMap(decodeAlbum).first ?? fallbackAlbum
        let artistModels = payload.artists ?? []
        let artistNames = artistModels.compactMap { $0.name.map { String($0.prefix(100)) } }
        let artist = artistModels.first.flatMap { model -> MusicSearchArtist? in
            guard let rawArtistID = model.id?.value,
                  let artistID = validatedQueueIdentifier(rawArtistID)?.split(separator: ":").first.map(String.init),
                  let name = model.name, !name.isEmpty else { return nil }
            return MusicSearchArtist(
                id: artistID, name: String(name.prefix(200)),
                coverURI: model.cover?.uri ?? model.opImage ?? model.ogImage
            )
        }
        return MusicSearchTrack(
            id: id,
            title: String(title.prefix(200)),
            artists: artistNames.isEmpty ? (fallbackAlbum?.artists ?? album?.artists ?? []) : artistNames,
            durationMilliseconds: payload.durationMs,
            coverURI: payload.coverUri ?? album?.coverURI,
            artist: artist,
            album: album
        )
    }

    private static func decodeAlbum(_ payload: AlbumPayload) -> MusicSearchAlbum? {
        guard let rawID = payload.id?.value,
              let id = validatedQueueIdentifier(rawID)?.split(separator: ":").first.map(String.init),
              let title = payload.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty, payload.available != false else { return nil }
        return MusicSearchAlbum(
            id: id, title: String(title.prefix(200)),
            artists: (payload.artists ?? []).compactMap { $0.name.map { String($0.prefix(100)) } },
            year: payload.year ?? payload.originalReleaseYear,
            coverURI: payload.coverUri ?? payload.cover?.uri
        )
    }

    private struct NewWaveRequest: Encodable {
        let seeds: [String]
        let includeTracksInResponse: Bool
        let includeWaveModel: Bool
        let interactive: Bool
    }

    private struct NextWaveRequest: Encodable {
        let queue: [String]
    }

    private struct FeedbackRequest: Encodable {
        let event: FeedbackEvent
        let batchId: String?
        enum CodingKeys: String, CodingKey { case event, batchId }
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(event, forKey: .event)
            try container.encodeIfPresent(batchId, forKey: .batchId)
        }
    }

    private struct FeedbackEvent: Encodable {
        let type: String
        let timestamp: String
        let trackId: String?
        let totalPlayedSeconds: Double?
        enum CodingKeys: String, CodingKey {
            case type, timestamp, trackId, totalPlayedSeconds
        }
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encode(timestamp, forKey: .timestamp)
            try container.encodeIfPresent(trackId, forKey: .trackId)
            try container.encodeIfPresent(totalPlayedSeconds, forKey: .totalPlayedSeconds)
        }
    }

    private struct HistoryEnvelope: Decodable { let result: HistoryPayload? }
    private struct HistoryPayload: Decodable { let historyTabs: [HistoryTab]? }
    private struct HistoryTab: Decodable { let items: [HistoryGroup]? }
    private struct HistoryGroup: Decodable { let tracks: [HistoryItem]? }
    private struct HistoryItem: Decodable {
        let type: String?
        let data: HistoryItemData?
    }
    private struct HistoryItemData: Decodable {
        let fullModel: TrackPayload?
    }

    private struct WaveSessionEnvelope: Decodable { let result: WaveSessionPayload? }
    private struct WaveSessionPayload: Decodable {
        let radioSessionId: String?
        let batchId: String?
        let sequence: [SequencePayload]?
        let terminated: Bool?
    }
    private struct WaveBatchEnvelope: Decodable { let result: WaveBatchPayload? }
    private struct WaveBatchPayload: Decodable {
        let batchId: String?
        let sequence: [SequencePayload]?
        let terminated: Bool?
        let unknownSession: Bool?
    }
    private struct SequencePayload: Decodable {
        let type: String?
        let track: TrackPayload?
    }
    private struct TrackPayload: Decodable {
        let id: StringOrNumber?
        let title: String?
        let available: Bool?
        let artists: [ArtistPayload]?
        let albums: [AlbumPayload]?
        let durationMs: Int?
        let coverUri: String?
    }
    private struct ArtistPayload: Decodable {
        let id: StringOrNumber?
        let name: String?
        let cover: CoverPayload?
        let opImage: String?
        let ogImage: String?
    }
    private struct AlbumPayload: Decodable {
        let id: StringOrNumber?
        let title: String?
        let artists: [ArtistPayload]?
        let year: Int?
        let originalReleaseYear: Int?
        let coverUri: String?
        let cover: CoverPayload?
        let available: Bool?
    }
    private struct CoverPayload: Decodable { let uri: String? }

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
