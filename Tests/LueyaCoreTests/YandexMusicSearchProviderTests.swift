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

    private struct StubTransport: MusicHTTPTransport {
        let status: Int
        let body: String
        let responseURL: String?

        init(
            status: Int = 200,
            body: String = #"{"result":{"tracks":{"results":[]}}}"#,
            responseURL: String? = nil
        ) {
            self.status = status
            self.body = body
            self.responseURL = responseURL
        }

        func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            guard let url = request.url else { throw MusicSearchError.invalidResponse }
            XCTAssertEqual(url.scheme, "https")
            XCTAssertEqual(url.host, "api.music.yandex.net")
            XCTAssertEqual(url.path, "/search")
            let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
            XCTAssertEqual(parts?.queryItems?.first(where: { $0.name == "type" })?.value, "track")
            XCTAssertEqual(parts?.queryItems?.first(where: { $0.name == "page" })?.value, "0")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "OAuth my-test-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")

            let returnedURL = URL(string: responseURL ?? url.absoluteString)!
            let response = HTTPURLResponse(
                url: returnedURL, statusCode: status,
                httpVersion: nil, headerFields: nil
            )!
            return (Data(body.utf8), response)
        }
    }
}
