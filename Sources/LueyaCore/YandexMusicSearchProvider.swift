import Foundation

/// Lightweight, authenticated catalog results. No artwork or audio is persisted.
public struct MusicSearchTrack: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let artists: [String]
    public let durationMilliseconds: Int?
    public let coverURI: String?
    public let artist: MusicSearchArtist?
    public let album: MusicSearchAlbum?

    public var coverURL: URL? {
        MusicArtworkURL.validatedURL(from: coverURI)
    }

    public var artistName: String {
        artists.isEmpty ? "Unknown artist" : artists.joined(separator: ", ")
    }

    public init(
        id: String, title: String, artists: [String],
        durationMilliseconds: Int?, coverURI: String? = nil,
        artist: MusicSearchArtist? = nil, album: MusicSearchAlbum? = nil
    ) {
        self.id = id
        self.title = title
        self.artists = artists
        self.durationMilliseconds = durationMilliseconds
        self.coverURI = coverURI
        self.artist = artist
        self.album = album
    }
}

public struct MusicSearchArtist: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct MusicSearchAlbum: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let artists: [String]
    public let year: Int?
    public let coverURI: String?

    public var artistName: String {
        artists.isEmpty ? "Unknown artist" : artists.joined(separator: ", ")
    }
    public var coverURL: URL? { MusicArtworkURL.validatedURL(from: coverURI) }

    public init(id: String, title: String, artists: [String], year: Int?, coverURI: String?) {
        self.id = id
        self.title = title
        self.artists = artists
        self.year = year
        self.coverURI = coverURI
    }
}

public struct MusicArtistAlbumPage: Equatable, Sendable {
    public let albums: [MusicSearchAlbum]
    public let hasMore: Bool
    public init(albums: [MusicSearchAlbum], hasMore: Bool) {
        self.albums = albums
        self.hasMore = hasMore
    }
}

/// Artwork URL construction is deliberately restricted to the provider's
/// public artwork CDN; no OAuth headers or signed audio links are involved.
public enum MusicArtworkURL {
    public static func validatedURL(from template: String?) -> URL? {
        guard let template, template.count < 500,
              template.hasPrefix("avatars.yandex.net/get-music-content/"),
              template.contains("%%"),
              !template.contains("?"), !template.contains("#"),
              !template.contains("@"), !template.contains(":"),
              !template.unicodeScalars.contains(where: {
                  CharacterSet.controlCharacters.contains($0)
              }),
              let url = URL(string: "https://" +
                  template.replacingOccurrences(of: "%%", with: "200x200")),
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "https", parts.host == "avatars.yandex.net",
              parts.port == nil, parts.user == nil, parts.password == nil,
              parts.query == nil, parts.fragment == nil,
              parts.path.hasPrefix("/get-music-content/") else {
            return nil
        }
        return url
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
        let query = try Self.validatedQuery(input)
        try Self.validateToken(accessToken)
        let tracks = try await fetchTracks(
            matching: query, type: "track", accessToken: accessToken
        )
        if !tracks.isEmpty { return tracks }
        return try await fetchTracks(
            matching: query, type: "all", accessToken: accessToken
        )
    }

    public func artists(matching input: String, accessToken: String) async throws -> [MusicSearchArtist] {
        let query = try Self.validatedQuery(input)
        try Self.validateToken(accessToken)
        let data = try await fetchSearchData(
            matching: query, type: "artist", accessToken: accessToken
        )
        guard let envelope = try? JSONDecoder().decode(SearchEnvelope.self, from: data),
              let results = envelope.result?.artists?.results else {
            throw MusicSearchError.invalidPayload
        }
        var seen = Set<String>()
        return results.compactMap { artist -> MusicSearchArtist? in
            guard let id = artist.id?.value,
                  let normalized = Self.validatedNumericID(id),
                  let name = artist.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty, artist.available != false,
                  seen.insert(normalized).inserted else { return nil }
            return MusicSearchArtist(id: normalized, name: String(name.prefix(200)))
        }.prefix(20).map { $0 }
    }

    public func albums(matching input: String, accessToken: String) async throws -> [MusicSearchAlbum] {
        let query = try Self.validatedQuery(input)
        try Self.validateToken(accessToken)
        let data = try await fetchSearchData(
            matching: query, type: "album", accessToken: accessToken
        )
        guard let envelope = try? JSONDecoder().decode(SearchEnvelope.self, from: data),
              let results = envelope.result?.albums?.results else {
            throw MusicSearchError.invalidPayload
        }
        return Self.decodedAlbums(results)
    }

    public func albums(
        forArtistID artistID: String, page: Int = 0, accessToken: String
    ) async throws -> MusicArtistAlbumPage {
        guard let id = Self.validatedNumericID(artistID),
              (0...100).contains(page) else { throw MusicSearchError.invalidQuery }
        try Self.validateToken(accessToken)
        let url = URL(string:
            "https://api.music.yandex.net/artists/\(id)/direct-albums?sort-by=year&page=\(page)&page-size=20"
        )!
        let data = try await perform(requestURL: url, accessToken: accessToken)
        guard let payload = try? JSONDecoder().decode(ArtistAlbumEnvelope.self, from: data),
              let result = payload.result else { throw MusicSearchError.invalidPayload }
        let albums = Self.decodedAlbums(result.albums ?? [])
        let hasMore = result.pager?.total.map { (page + 1) * 20 < $0 } ?? (result.albums?.count == 20)
        return MusicArtistAlbumPage(albums: albums, hasMore: hasMore)
    }

    /// Album volumes contain the authoritative disc-ordered track list.
    public func tracks(
        forAlbum album: MusicSearchAlbum, accessToken: String
    ) async throws -> [MusicSearchTrack] {
        guard let id = Self.validatedNumericID(album.id) else {
            throw MusicSearchError.invalidQuery
        }
        try Self.validateToken(accessToken)
        let url = URL(string: "https://api.music.yandex.net/albums/\(id)/with-tracks")!
        let data = try await perform(requestURL: url, accessToken: accessToken)
        guard let envelope = try? JSONDecoder().decode(AlbumTracksEnvelope.self, from: data),
              let volumes = envelope.result?.volumes else {
            throw MusicSearchError.invalidPayload
        }
        // A defensive cap bounds UI and in-memory queue sizes.
        return Self.decodedTracks(Array(volumes.joined().prefix(150)), fallbackAlbum: album)
    }

    /// Read-only bounded first page of an explicitly selected artist's tracks.
    public func tracks(forArtistID artistID: String, accessToken: String) async throws -> [MusicSearchTrack] {
        guard let id = Self.validatedNumericID(artistID) else {
            throw MusicSearchError.invalidQuery
        }
        try Self.validateToken(accessToken)
        try Task.checkCancellation()

        let url = URL(string:
            "https://api.music.yandex.net/artists/\(id)/tracks?page=0&page-size=20"
        )!
        let data = try await perform(requestURL: url, accessToken: accessToken)
        guard let envelope = try? JSONDecoder().decode(ArtistTracksEnvelope.self, from: data),
              let tracks = envelope.result?.tracks else {
            throw MusicSearchError.invalidPayload
        }
        return Self.decodedTracks(tracks)
    }

    private static func validatedQuery(_ input: String) throws -> String {
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, query.count <= 120,
              !query.unicodeScalars.contains(where: {
                  CharacterSet.controlCharacters.contains($0)
              }) else {
            throw MusicSearchError.invalidQuery
        }
        return query
    }

    private static func validateToken(_ token: String) throws {
        guard !token.isEmpty,
              token.utf8.allSatisfy({ $0 >= 0x21 && $0 <= 0x7e }) else {
            throw MusicSearchError.invalidToken
        }
    }

    private static func validatedNumericID(_ input: String) -> String? {
        guard input.count <= 19, !input.isEmpty,
              input.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
              let number = Int64(input), number > 0 else { return nil }
        return String(number)
    }

    private func fetchTracks(
        matching query: String, type: String, accessToken: String
    ) async throws -> [MusicSearchTrack] {
        try Task.checkCancellation()

        var urlParts = URLComponents(url: Self.origin, resolvingAgainstBaseURL: false)!
        urlParts.queryItems = [
            URLQueryItem(name: "text", value: query),
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "page", value: "0")
        ]
        guard let url = urlParts.url else { throw MusicSearchError.invalidQuery }
        let data = try await perform(requestURL: url, accessToken: accessToken)
        guard let payload = try? JSONDecoder().decode(SearchEnvelope.self, from: data),
              let searchResult = payload.result else {
            throw MusicSearchError.invalidPayload
        }
        return Self.decodedTracks(searchResult.tracks?.results ?? [])
    }

    private func fetchSearchData(
        matching query: String, type: String, accessToken: String
    ) async throws -> Data {
        var urlParts = URLComponents(url: Self.origin, resolvingAgainstBaseURL: false)!
        urlParts.queryItems = [
            URLQueryItem(name: "text", value: query),
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "page", value: "0")
        ]
        guard let url = urlParts.url else { throw MusicSearchError.invalidQuery }
        return try await perform(requestURL: url, accessToken: accessToken)
    }

    private func perform(requestURL url: URL, accessToken: String) async throws -> Data {
        try Task.checkCancellation()
        var request = URLRequest(
            url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15
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
        guard data.count <= 1_000_000 else { throw MusicSearchError.invalidPayload }
        return data
    }

    private static func decodedTracks(
        _ items: [TrackResult], fallbackAlbum: MusicSearchAlbum? = nil
    ) -> [MusicSearchTrack] {
        var unique = Set<String>()
        return items.compactMap { result -> MusicSearchTrack? in
            guard let id = result.id?.value,
                  let normalized = validatedNumericID(id),
                  let title = result.title?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty, result.available != false,
                  unique.insert(normalized).inserted else { return nil }
            let artists = (result.artists ?? []).compactMap { artist in
                artist.name.map { String($0.prefix(100)) }
            }
            let firstArtist = result.artists?.first.flatMap { artist -> MusicSearchArtist? in
                guard let id = artist.id.flatMap { validatedNumericID($0.value) },
                      let name = artist.name, !name.isEmpty else { return nil }
                return MusicSearchArtist(id: id, name: String(name.prefix(200)))
            }
            let album = result.albums?.compactMap { decodedAlbum($0) }.first ?? fallbackAlbum
            return MusicSearchTrack(
                id: normalized,
                title: String(title.prefix(200)),
                artists: artists.isEmpty ? (fallbackAlbum?.artists ?? []) : artists,
                durationMilliseconds: result.durationMs,
                coverURI: result.coverUri ?? album?.coverURI,
                artist: firstArtist,
                album: album
            )
        }.prefix(fallbackAlbum == nil ? 20 : 150).map { $0 }
    }

    private static func decodedAlbum(_ album: AlbumResult) -> MusicSearchAlbum? {
        guard let id = album.id.flatMap { validatedNumericID($0.value) },
              let title = album.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty, album.available != false else { return nil }
        return MusicSearchAlbum(
            id: id, title: String(title.prefix(200)),
            artists: (album.artists ?? []).compactMap { $0.name.map { String($0.prefix(100)) } },
            year: album.year, coverURI: album.coverUri
        )
    }

    private static func decodedAlbums(_ albums: [AlbumResult]) -> [MusicSearchAlbum] {
        var seen = Set<String>()
        return albums.compactMap { album in
            guard let result = decodedAlbum(album),
                  seen.insert(result.id).inserted else { return nil }
            return result
        }.prefix(20).map { $0 }
    }

    private struct SearchEnvelope: Decodable {
        let result: SearchPayload?
    }

    private struct SearchPayload: Decodable {
        let tracks: TrackResults?
        let artists: ArtistResults?
        let albums: AlbumResults?
    }

    private struct AlbumResults: Decodable {
        let results: [AlbumResult]?
    }

    private struct ArtistResults: Decodable {
        let results: [ArtistResult]?
    }

    private struct ArtistResult: Decodable {
        let id: StringOrNumber?
        let name: String?
        let available: Bool?
    }

    private struct ArtistAlbumEnvelope: Decodable {
        let result: ArtistAlbumPayload?
    }
    private struct ArtistAlbumPayload: Decodable {
        let albums: [AlbumResult]?
        let pager: AlbumPager?
    }
    private struct AlbumPager: Decodable {
        let total: Int?
    }
    private struct AlbumTracksEnvelope: Decodable {
        let result: AlbumTracksPayload?
    }
    private struct AlbumTracksPayload: Decodable {
        let volumes: [[TrackResult]]?
    }

    private struct ArtistTracksEnvelope: Decodable {
        let result: ArtistTracksPayload?
    }

    private struct ArtistTracksPayload: Decodable {
        let tracks: [TrackResult]?
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
        let coverUri: String?
        let albums: [AlbumResult]?
    }

    private struct AlbumResult: Decodable {
        let id: StringOrNumber?
        let title: String?
        let artists: [Artist]?
        let year: Int?
        let coverUri: String?
        let available: Bool?
    }

    private struct Artist: Decodable {
        let id: StringOrNumber?
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
