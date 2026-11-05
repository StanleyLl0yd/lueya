import Foundation
import XCTest
@testable import LueyaCore

final class YandexMusicSearchProviderTests: XCTestCase {
    func testSearchUsesAuthenticatedFixedEndpointAndDecodesBoundedTracks() async throws {
        let body = """
        {"result":{"tracks":{"results":[
            {"id":99338938,"title":"Fade Away","artists":[{"name":"Yodelice"}],
             "durationMs":249000,"available":true},
            {"id":"101","title":"Second","artists":[{"name":"An Artist"}]},
            {"id":"101","title":"Duplicate"},
            {"id":"not-a-number","title":"Invalid"},
            {"id":102,"title":"Unavailable","available":false}
        ]}}}
        """
        let matches = try await YandexMusicSearchProvider(
            transport: StubTransport(body: body)
        ).tracks(matching: "Yodelice & more", accessToken: "my-test-token")

        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0].id, "99338938")
        XCTAssertEqual(matches[0].title, "Fade Away")
        XCTAssertEqual(matches[0].artistName, "Yodelice")
        XCTAssertEqual(matches[0].durationMilliseconds, 249000)
        XCTAssertEqual(matches[1].id, "101")
    }

    func testEmptyResultsAreValid() async throws {
        let matches = try await YandexMusicSearchProvider(
            transport: StubTransport(body: #"{"result":{"tracks":{"results":[]}}}"#)
        ).tracks(matching: "something", accessToken: "my-test-token")
        XCTAssertTrue(matches.isEmpty)
    }

    func testArtistNameFallsBackToAllCategories() async throws {
        let allResults = """
        {"result":{"tracks":{"results":[
            {"id":123456,"title":"Группа крови","artists":[{"name":"Кино"}],
             "durationMs":287000,"available":true}
        ]}}}
        """
        let results = try await YandexMusicSearchProvider(
            transport: StubTransport(
                body: #"{"result":{"tracks":{"results":[]}}}"#,
                allBody: allResults
            )
        ).tracks(matching: "кино", accessToken: "my-test-token")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "Группа крови")
        XCTAssertEqual(results[0].artistName, "Кино")
    }

    func testArtistSearchAndSelectedArtistTracks() async throws {
        let provider = YandexMusicSearchProvider(transport: ArtistLookupTransport())
        let artists = try await provider.artists(matching: "кино", accessToken: "my-test-token")
        XCTAssertEqual(artists, [
            MusicSearchArtist(id: "77", name: "Кино"),
            MusicSearchArtist(id: "88", name: "КИНО tribute")
        ])
        let tracks = try await provider.tracks(
            forArtistID: artists[0].id, accessToken: "my-test-token"
        )
        XCTAssertEqual(tracks.count, 2)
        XCTAssertEqual(tracks[0].title, "Звезда по имени Солнце")
        XCTAssertEqual(tracks[0].artistName, "Кино")
        XCTAssertEqual(tracks[0].coverURL?.host, "avatars.yandex.net")
        XCTAssertEqual(tracks[1].title, "Пачка сигарет")
    }

    func testRejectsUntrustedArtworkHostsAndMalformedIDs() async {
        let good = "avatars.yandex.net/get-music-content/123/abcdef/%%"
        XCTAssertEqual(
            MusicArtworkURL.validatedURL(from: good)?.absoluteString,
            "https://avatars.yandex.net/get-music-content/123/abcdef/200x200"
        )
        for invalid in [
            "https://avatars.yandex.net/get-music-content/123/%%",
            "avatars.yandex.net.evil.test/get-music-content/123/%%",
            "avatars.yandex.net/other/%%",
            "avatars.yandex.net/get-music-content/123/%%?redirect=evil",
            "avatars.yandex.net/get-music-content/123/%%#frag",
            "evil.test/get-music-content/123/%%"
        ] {
            XCTAssertNil(MusicArtworkURL.validatedURL(from: invalid))
        }
        let provider = YandexMusicSearchProvider(transport: ArtistLookupTransport())
        for id in ["", "0", "-1", "foo", "12/other", "99999999999999999999"] {
            do {
                _ = try await provider.tracks(forArtistID: id, accessToken: "my-test-token")
                XCTFail("Invalid artist id was accepted")
            } catch let error as MusicSearchError {
                XCTAssertEqual(error, .invalidQuery)
            } catch {
                XCTFail("Unexpected \(error)")
            }
        }
    }

    func testRejectsInvalidQueriesBeforeNetwork() async {
        for query in ["", " \n ", String(repeating: "a", count: 121), "bad\u{0000}query"] {
            await expect(
                .invalidQuery,
                query: query,
                token: "my-test-token",
                transport: StubTransport()
            )
        }
    }

    func testRejectsMalformedTokensBeforeNetwork() async {
        for token in ["", "has space", "contains\nnewline", "токен"] {
            await expect(
                .invalidToken,
                query: "test",
                token: token,
                transport: StubTransport()
            )
        }
    }

    func testRejectsCrossOriginResponsesEvenOnSuccess() async {
        await expect(
            .invalidResponse,
            transport: StubTransport(
                body: #"{"result":{"tracks":{"results":[]}}}"#,
                responseURL: "https://evil.example/search?text=test&type=track&page=0"
            )
        )
    }

    func testRejectsAlteredSearchResponseURL() async {
        await expect(
            .invalidResponse,
            transport: StubTransport(
                body: #"{"result":{"tracks":{"results":[]}}}"#,
                responseURL: "https://api.music.yandex.net/search?text=other&type=track&page=0"
            )
        )
    }

    func testClassifiesHTTPFailures() async {
        for (status, expected) in [
            (401, MusicSearchError.unauthorized),
            (403, .forbidden),
            (429, .rateLimited),
            (500, .httpStatus(500)),
            (302, .httpStatus(302))
        ] {
            await expect(expected, transport: StubTransport(status: status))
        }
    }

    func testRejectsMissingResponseEnvelope() async {
        await expect(
            .invalidPayload,
            transport: StubTransport(body: #"{"result":null}"#)
        )
    }

    private func expect(
        _ expected: MusicSearchError,
        query: String = "test",
        token: String = "my-test-token",
        transport: StubTransport
    ) async {
        do {
            _ = try await YandexMusicSearchProvider(transport: transport)
                .tracks(matching: query, accessToken: token)
            XCTFail("Expected \(expected)")
        } catch let error as MusicSearchError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error type: \(type(of: error))")
        }
    }

    func testAlbumSearchAndArtistDiscographyWithPaging() async throws {
        let provider = YandexMusicSearchProvider(transport: AlbumLookupTransport())
        let results = try await provider.albums(
            matching: "Yodelice", accessToken: "my-test-token"
        )
        XCTAssertEqual(results.map(\.title), ["Tree of Life", "Cardioid"])
        XCTAssertEqual(results.first?.artistName, "Yodelice")
        XCTAssertEqual(results.first?.coverURL?.host, "avatars.yandex.net")
        XCTAssertEqual(results.first?.year, 2019)

        let first = try await provider.albums(
            forArtistID: "77", page: 0, accessToken: "my-test-token"
        )
        XCTAssertEqual(first.albums.count, 2)
        XCTAssertTrue(first.hasMore)
        let second = try await provider.albums(
            forArtistID: "77", page: 1, accessToken: "my-test-token"
        )
        XCTAssertEqual(second.albums.map(\.id), ["43"])
        XCTAssertFalse(second.hasMore)
    }

    func testAlbumTrackVolumesPreserveOrderedTrackMetadata() async throws {
        let provider = YandexMusicSearchProvider(transport: AlbumLookupTransport())
        let album = MusicSearchAlbum(
            id: "41", title: "Tree of Life", artists: ["Yodelice"],
            year: 2019, coverURI: "avatars.yandex.net/get-music-content/12/a/%%"
        )
        let songs = try await provider.tracks(
            forAlbum: album, accessToken: "my-test-token"
        )
        XCTAssertEqual(songs.map(\.title), ["Muse in Motion", "The Answer", "Second disc"])
        XCTAssertEqual(songs[0].album?.id, "41")
        XCTAssertEqual(songs[0].album?.title, "Tree of Life")
        XCTAssertEqual(songs[0].artist, MusicSearchArtist(id: "77", name: "Yodelice"))
        XCTAssertEqual(songs[0].coverURL?.host, "avatars.yandex.net")
        XCTAssertEqual(songs[1].album?.title, "Tree of Life")
        XCTAssertEqual(songs[2].artistName, "Yodelice")
    }

    func testRejectsMalformedAlbumIDsAndInvalidPageBeforeNetwork() async {
        let provider = YandexMusicSearchProvider(transport: AlbumLookupTransport())
        for badID in ["", "-1", "0", "../123", "4%2f5", "abc"] {
            let album = MusicSearchAlbum(
                id: badID, title: "Test", artists: [], year: nil, coverURI: nil
            )
            do {
                _ = try await provider.tracks(forAlbum: album, accessToken: "my-test-token")
                XCTFail("Accepted album ID \(badID)")
            } catch let error as MusicSearchError {
                XCTAssertEqual(error, .invalidQuery)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
        for badPage in [-1, 101] {
            do {
                _ = try await provider.albums(
                    forArtistID: "77", page: badPage, accessToken: "my-test-token"
                )
                XCTFail("Accepted invalid page \(badPage)")
            } catch let error as MusicSearchError {
                XCTAssertEqual(error, .invalidQuery)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    private struct AlbumLookupTransport: MusicHTTPTransport {
        func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            guard let url = request.url else { throw MusicSearchError.invalidResponse }
            XCTAssertEqual(url.scheme, "https")
            XCTAssertEqual(url.host, "api.music.yandex.net")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "OAuth my-test-token")
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let params = components?.queryItems ?? []
            let body: String
            switch url.path {
            case "/search":
                XCTAssertEqual(params.first(where: { $0.name == "type" })?.value, "album")
                body = """
                {"result":{"albums":{"results":[
                    {"id":41,"title":"Tree of Life","artists":[{"id":77,"name":"Yodelice"}],
                     "year":2019,"coverUri":"avatars.yandex.net/get-music-content/12/a/%%"},
                    {"id":42,"title":"Cardioid","artists":[{"name":"Yodelice"}]},
                    {"id":41,"title":"duplicate","artists":[]}
                ]}}}
                """
            case "/artists/77/direct-albums":
                XCTAssertEqual(params.first(where: { $0.name == "sort-by" })?.value, "year")
                XCTAssertEqual(params.first(where: { $0.name == "page-size" })?.value, "20")
                if params.first(where: { $0.name == "page" })?.value == "0" {
                    body = """
                    {"result":{"albums":[
                        {"id":41,"title":"Tree of Life","artists":[{"name":"Yodelice"}]},
                        {"id":42,"title":"Cardioid"}
                    ],"pager":{"total":21}}}
                    """
                } else {
                    XCTAssertEqual(params.first(where: { $0.name == "page" })?.value, "1")
                    body = """
                    {"result":{"albums":[
                        {"id":43,"title":"New Album","artists":[{"name":"Yodelice"}]}
                    ],"pager":{"total":21}}}
                    """
                }
            case "/albums/41/with-tracks":
                body = """
                {"result":{"id":41,"title":"Tree of Life","volumes":[[
                    {"id":701,"title":"Muse in Motion",
                     "artists":[{"id":77,"name":"Yodelice"}],"durationMs":150000},
                    {"id":702,"title":"The Answer","artists":[{"name":"Yodelice"}]}
                ],[
                    {"id":703,"title":"Second disc","artists":[]}
                ]]}}
                """
            default:
                XCTFail("Unexpected endpoint: \(url.path)")
                throw MusicSearchError.invalidResponse
            }
            return (
                Data(body.utf8),
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
        }
    }

    private struct ArtistLookupTransport: MusicHTTPTransport {
        func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            guard let url = request.url else { throw MusicSearchError.invalidResponse }
            XCTAssertEqual(url.scheme, "https")
            XCTAssertEqual(url.host, "api.music.yandex.net")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "OAuth my-test-token")

            let body: String
            if url.path == "/search" {
                let type = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "type" })?.value
                XCTAssertEqual(type, "artist")
                body = """
                {"result":{"artists":{"results":[
                    {"id":77,"name":"Кино","available":true},
                    {"id":88,"name":"КИНО tribute"},
                    {"id":77,"name":"Duplicate"}
                ]}}}
                """
            } else {
                XCTAssertEqual(url.path, "/artists/77/tracks")
                let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
                XCTAssertEqual(items?.first(where: { $0.name == "page" })?.value, "0")
                XCTAssertEqual(items?.first(where: { $0.name == "page-size" })?.value, "20")
                body = """
                {"result":{"tracks":[
                    {"id":701,"title":"Звезда по имени Солнце",
                     "artists":[{"name":"Кино"}],"coverUri":"avatars.yandex.net/get-music-content/12/a/%%"},
                    {"id":702,"title":"Пачка сигарет","artists":[{"name":"Кино"}]}
                ],"pager":{"total":2}}}
                """
            }
            return (
                Data(body.utf8),
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
        }
    }

    private struct StubTransport: MusicHTTPTransport {
        let status: Int
        let body: String
        let allBody: String?
        let responseURL: String?

        init(
            status: Int = 200,
            body: String = #"{"result":{"tracks":{"results":[]}}}"#,
            allBody: String? = nil,
            responseURL: String? = nil
        ) {
            self.status = status
            self.body = body
            self.allBody = allBody
            self.responseURL = responseURL
        }

        func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            guard let url = request.url else { throw MusicSearchError.invalidResponse }
            XCTAssertEqual(url.scheme, "https")
            XCTAssertEqual(url.host, "api.music.yandex.net")
            XCTAssertEqual(url.path, "/search")
            let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let type = parts?.queryItems?.first(where: { $0.name == "type" })?.value
            XCTAssertTrue(type == "track" || type == "all")
            XCTAssertEqual(parts?.queryItems?.first(where: { $0.name == "page" })?.value, "0")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "OAuth my-test-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")

            let returnedURL = URL(string: responseURL ?? url.absoluteString)!
            let response = HTTPURLResponse(
                url: returnedURL, statusCode: status,
                httpVersion: nil, headerFields: nil
            )!
            let responseBody = type == "all" ? (allBody ?? body) : body
            return (Data(responseBody.utf8), response)
        }
    }
}
