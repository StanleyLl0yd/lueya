import Foundation
import XCTest
@testable import LueyaCore

final class YandexMusicAPIClientTests: XCTestCase {
    func testAccountStatusUsesFixedOriginAndOAuthAuthorization() async throws {
        let transport = StubTransport(
            status: 200,
            body: #"{"result":{"account":{"uid":42,"login":"example"}}}"#
        )
        let result = try await YandexMusicAPIClient(transport: transport)
            .accountStatus(accessToken: "test-token")

        XCTAssertEqual(result.account?.uid, 42)
        XCTAssertEqual(result.account?.login, "example")
    }

    func testRejectsMissingAndMalformedTokensBeforeNetworkAccess() async {
        for token in ["", "has space", "contains\nnewline", "токен"] {
            await expect(.invalidToken, token: token, transport: StubTransport())
        }
    }

    func testClassifiesUnauthorizedResponse() async {
        await expect(.unauthorized, token: "test-token", transport: StubTransport(status: 401))
    }

    func testClassifiesForbiddenResponse() async {
        await expect(.forbidden, token: "test-token", transport: StubTransport(status: 403))
    }

    func testClassifiesRateLimitResponse() async {
        await expect(.rateLimited, token: "test-token", transport: StubTransport(status: 429))
    }

    func testRejectsRedirectResponses() async {
        await expect(.httpStatus(302), token: "test-token", transport: StubTransport(status: 302))
    }

    func testRejectsResponsesFromDifferentOrigins() async {
        await expect(
            .invalidResponse,
            token: "test-token",
            transport: StubTransport(status: 200, responseURL: "https://example.org/")
        )
    }

    func testRejectsInvalidPayload() async {
        await expect(
            .invalidPayload,
            token: "test-token",
            transport: StubTransport(status: 200, body: #"{"result":null}"#)
        )
    }

    private func expect(
        _ expected: MusicAPIError,
        token: String,
        transport: StubTransport
    ) async {
        do {
            _ = try await YandexMusicAPIClient(transport: transport)
                .accountStatus(accessToken: token)
            XCTFail("Expected \(expected)")
        } catch let error as MusicAPIError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    private struct StubTransport: MusicHTTPTransport {
        let status: Int
        let body: String
        let responseURL: String?

        init(
            status: Int = 200,
            body: String = #"{"result":{"account":{}}}"#,
            responseURL: String? = nil
        ) {
            self.status = status
            self.body = body
            self.responseURL = responseURL
        }

        func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            XCTAssertEqual(request.url?.absoluteString, "https://api.music.yandex.net/account/status")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "OAuth test-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            let url = URL(string: responseURL ?? request.url!.absoluteString)!
            let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(body.utf8), response)
        }
    }
}
