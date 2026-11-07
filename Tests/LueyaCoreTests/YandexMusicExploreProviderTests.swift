import Foundation
import XCTest
@testable import LueyaCore

final class YandexMusicExploreProviderTests: XCTestCase {
    func testRecentHistoryReturnsNewestUniqueFullTrackModels() async throws {
        let body = """
        {"result":{"historyTabs":[{"items":[{"tracks":[
          {"type":"track","data":{"fullModel":{"id":701,"title":"Muse in Motion",
            "durationMs":150000,"artists":[{"id":77,"name":"Yodelice"}],
            "albums":[{"id":41,"title":"Tree of Life","year":2019,
              "artists":[{"id":77,"name":"Yodelice"}],
              "coverUri":"avatars.yandex.net/get-music-content/12/a/%%"}],
            "coverUri":"avatars.yandex.net/get-music-content/12/a/%%"}}},
          {"type":"album","data":{"fullModel":{"id":41,"title":"Tree of Life"}}},
          {"type":"track","data":{"fullModel":{"id":702,"title":"The Answer",
            "artists":[{"name":"Yodelice"}],
            "albums":[{"id":41,"title":"Tree of Life"}]}}},
          {"type":"track","data":{"fullModel":{"id":701,"title":"Duplicate"}}}
        ]}]}]}}
        """
        let provider = YandexMusicExploreProvider(transport: StubTransport(
            path: "/music-history", method: "GET", body: body,
            expectedQuery: "full_models_count=8"
        ))
        let tracks = try await provider.recentTracks(accessToken: "my-test-token", limit: 8)
        XCTAssertEqual(tracks.map(\.id), ["701", "702"])
        XCTAssertEqual(tracks[0].title, "Muse in Motion")
        XCTAssertEqual(tracks[0].artist, MusicSearchArtist(id: "77", name: "Yodelice"))
        XCTAssertEqual(tracks[0].album?.id, "41")
        XCTAssertEqual(tracks[0].album?.year, 2019)
        XCTAssertEqual(tracks[1].title, "The Answer")
    }

    func testMyWaveCreatesPersonalSessionAndMapsTrackMetadata() async throws {
        let body = """
        {"result":{"radioSessionId":"session-abc_123","batchId":"batch-1",
          "terminated":false,"sequence":[
            {"type":"track","track":{"id":1001,"title":"Muse in Motion",
              "durationMs":150000,"artists":[{"id":77,"name":"Yodelice",
                "cover":{"uri":"avatars.yandex.net/get-music-content/artist/a/%%"}}],
              "albums":[{"id":41,"title":"Tree of Life","year":2019,
                "artists":[{"id":77,"name":"Yodelice"}],
                "coverUri":"avatars.yandex.net/get-music-content/album/a/%%"}]}},
            {"type":"ad"},
            {"type":"track","track":{"id":1002,"title":"The Answer",
              "artists":[{"name":"Yodelice"}],"albums":[{"id":41,"title":"Tree of Life"}]}}
          ]}}
        """
        let provider = YandexMusicExploreProvider(transport: StubTransport(
            path: "/rotor/session/new", method: "POST", body: body,
            expectedBodyContains: "user:onyourwave"
        ))
        let session = try await provider.startMyWave(accessToken: "my-test-token")
        XCTAssertEqual(session.id, "session-abc_123")
        XCTAssertEqual(session.batchID, "batch-1")
        XCTAssertEqual(session.tracks.map(\.title), ["Muse in Motion", "The Answer"])
        XCTAssertEqual(session.queueIdentifiers, ["1001:41", "1002:41"])
        XCTAssertEqual(session.tracks[0].artist?.coverURL?.host, "avatars.yandex.net")
        XCTAssertEqual(session.tracks[0].album?.title, "Tree of Life")
        XCTAssertFalse(session.terminated)
    }

    func testNextWaveBatchAndFeedbackPayload() async throws {
        let next = StubTransport(
            path: "/rotor/session/session-abc/tracks", method: "POST",
            body: #"{"result":{"batchId":"batch-2","terminated":true,"sequence":[{"type":"track","track":{"id":1003,"title":"New track","artists":[{"name":"Yodelice"}],"albums":[{"id":41,"title":"Tree of Life"}]}}]}}"#,
            expectedBodyContains: "1001:41"
        )
        let batch = try await YandexMusicExploreProvider(transport: next).nextMyWaveBatch(
            sessionID: "session-abc", queue: ["1001:41", "1002:41"],
            accessToken: "my-test-token"
        )
        XCTAssertEqual(batch.batchID, "batch-2")
        XCTAssertEqual(batch.queueIdentifiers, ["1003:41"])
        XCTAssertTrue(batch.terminated)

        let feedback = StubTransport(
            path: "/rotor/session/session-abc/feedback", method: "POST",
            body: #"{"result":{}}"#,
            expectedBodyContains: #""type":"trackStarted""#
        )
        try await YandexMusicExploreProvider(transport: feedback).sendFeedback(
            sessionID: "session-abc", event: .trackStarted,
            trackIdentifier: "1001:41", batchID: "batch-1",
            accessToken: "my-test-token"
        )
    }

    func testRejectsInvalidIDsAndTokensBeforeNetwork() async {
        let provider = YandexMusicExploreProvider(transport: NeverCalledTransport())
        do {
            _ = try await provider.nextMyWaveBatch(
                sessionID: "../other", queue: [], accessToken: "my-test-token"
            )
            XCTFail("Accepted malformed session ID")
        } catch let error as MusicExploreError {
            XCTAssertEqual(error, .invalidSession)
        } catch { XCTFail("Unexpected error: \(error)") }
        do {
            _ = try await provider.nextMyWaveBatch(
                sessionID: "session-abc", queue: ["1/../2"], accessToken: "my-test-token"
            )
            XCTFail("Accepted malformed queue ID")
        } catch let error as MusicExploreError {
            XCTAssertEqual(error, .invalidSession)
        } catch { XCTFail("Unexpected error: \(error)") }
        do {
            _ = try await provider.recentTracks(accessToken: "has spaces")
            XCTFail("Accepted malformed token")
        } catch let error as MusicExploreError {
            XCTAssertEqual(error, .invalidToken)
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    func testRejectsCrossOriginAndForbiddenResponses() async {
        let redirected = StubTransport(
            path: "/music-history", method: "GET",
            body: #"{"result":{"historyTabs":[]}}"#,
            responseURL: "https://evil.example/music-history?full_models_count=8"
        )
        do {
            _ = try await YandexMusicExploreProvider(transport: redirected)
                .recentTracks(accessToken: "my-test-token")
            XCTFail("Accepted cross-origin response")
        } catch let error as MusicExploreError {
            XCTAssertEqual(error, .invalidResponse)
        } catch { XCTFail("Unexpected error: \(error)") }

        let forbidden = StubTransport(
            path: "/music-history", method: "GET", body: #"{"error":"forbidden"}"#,
            status: 403
        )
        do {
            _ = try await YandexMusicExploreProvider(transport: forbidden)
                .recentTracks(accessToken: "my-test-token")
            XCTFail("Accepted HTTP 403")
        } catch let error as MusicExploreError {
            XCTAssertEqual(error, .forbidden)
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    private struct StubTransport: MusicHTTPTransport {
        let path: String
        let method: String
        let body: String
        var status = 200
        var responseURL: String?
        var expectedQuery: String?
        var expectedBodyContains: String?

        func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            guard let url = request.url else { throw MusicExploreError.invalidResponse }
            XCTAssertEqual(url.scheme, "https")
            XCTAssertEqual(url.host, "api.music.yandex.net")
            XCTAssertNil(url.port)
            XCTAssertEqual(url.path, path)
            XCTAssertEqual(url.query, expectedQuery)
            XCTAssertEqual(request.httpMethod, method)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "OAuth my-test-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            if let expectedBodyContains {
                let text = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
                XCTAssertTrue(text.contains(expectedBodyContains), text)
            }
            let returnedURL = URL(string: responseURL ?? url.absoluteString)!
            let response = HTTPURLResponse(
                url: returnedURL, statusCode: status, httpVersion: nil, headerFields: nil
            )!
            return (Data(body.utf8), response)
        }
    }

    private struct NeverCalledTransport: MusicHTTPTransport {
        func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            XCTFail("Network must not be called for invalid input")
            throw MusicExploreError.invalidResponse
        }
    }
}
