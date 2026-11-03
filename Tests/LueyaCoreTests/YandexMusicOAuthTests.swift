import Foundation
import XCTest
@testable import LueyaCore

final class YandexMusicOAuthTests: XCTestCase {
    func testDeviceCodeIsRequestedFromFixedOAuthHost() async throws {
        let transport = QueueTransport([
            .init(status: 200, json: Self.deviceCodeJSON)
        ])
        let client = YandexOAuthClient(
            transport: transport,
            clientID: "public-client",
            clientSecret: "public-credential"
        )
        let code = try await client.requestDeviceCode()
        XCTAssertEqual(code.userCode, "ABCD-1234")
        XCTAssertEqual(code.verificationURL.absoluteString, "https://yandex.ru/activate")
        XCTAssertEqual(code.interval, 5)
        XCTAssertEqual(code.expiresIn, 600)
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://oauth.yandex.ru/device/code")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        let form = String(decoding: try XCTUnwrap(request.httpBody), as: UTF8.self)
        XCTAssertTrue(form.contains("client_id=public-client"))
        XCTAssertTrue(form.contains("device_name=lueya"))
        XCTAssertTrue(form.contains("device_id="))
        XCTAssertFalse(form.contains("public-credential"))
    }

    func testPollPendingAndAuthorizedToken() async throws {
        let transport = QueueTransport([
            .init(status: 200, json: Self.deviceCodeJSON),
            .init(status: 400, json: #"{"error":"authorization_pending"}"#),
            .init(status: 200, json: #"{"access_token":"account-access","refresh_token":"account-refresh","expires_in":3600,"token_type":"bearer"}"#)
        ])
        let client = YandexOAuthClient(transport: transport, clientID: "id", clientSecret: "secret")
        let code = try await client.requestDeviceCode()
        guard case .pending = try await client.pollDeviceToken(code) else {
            return XCTFail("Expected authorization_pending")
        }
        guard case .authorized(let tokens) = try await client.pollDeviceToken(code) else {
            return XCTFail("Expected tokens")
        }
        XCTAssertEqual(tokens.accessToken, "account-access")
        XCTAssertEqual(tokens.refreshToken, "account-refresh")
        XCTAssertFalse(tokens.needsRefresh())
        XCTAssertFalse(String(describing: tokens).contains("account-access"))
        XCTAssertFalse(String(reflecting: tokens).contains("account-refresh"))
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 3)
        let form = String(decoding: try XCTUnwrap(requests.last?.httpBody), as: UTF8.self)
        XCTAssertTrue(form.contains("grant_type=device_code"))
        XCTAssertTrue(form.contains("code=internal-device-code"))
        XCTAssertTrue(form.contains("client_secret=secret"))
    }

    func testSlowDownSignal() async throws {
        let clientAndCode = try await makeClientAndCode(
            tokenStatus: 400,
            tokenJSON: #"{"error":"slow_down"}"#
        )
        guard case .slowDown = try await clientAndCode.client.pollDeviceToken(clientAndCode.code) else {
            return XCTFail("Expected slow_down")
        }
    }

    func testAuthorizationDenied() async throws {
        try await assertOAuthFailure("access_denied", expected: .authorizationDenied)
    }

    func testExpiredDeviceCode() async throws {
        try await assertOAuthFailure("expired_token", expected: .expired)
    }

    func testInvalidClient() async throws {
        try await assertOAuthFailure("invalid_client", expected: .invalidClient)
    }

    func testRejectsUnsafeVerificationLink() async {
        for url in [
            "http://yandex.ru/activate",
            "https://yandex.ru.evil.example/activate",
            "https://user@yandex.ru/activate",
            "https://yandex.ru:8443/activate",
            "https://evil.example/activate"
        ] {
            XCTAssertFalse(YandexOAuthClient.isTrustedVerificationURL(URL(string: url)!))
        }
    }

    func testRejectsUntrustedOAuthResponseOrigin() async throws {
        let transport = QueueTransport([
            .init(status: 200, json: Self.deviceCodeJSON, url: "https://evil.example/device/code")
        ])
        let client = YandexOAuthClient(transport: transport)
        do {
            _ = try await client.requestDeviceCode()
            XCTFail("Unexpected successful request")
        } catch let error as YandexOAuthError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    func testRejectsMalformedDeviceCode() async throws {
        let transport = QueueTransport([
            .init(status: 200, json: #"{"device_code":"abc","user_code":"code","verification_url":"https://evil.example/","expires_in":60,"interval":2}"#)
        ])
        let client = YandexOAuthClient(transport: transport)
        do {
            _ = try await client.requestDeviceCode()
            XCTFail("Unexpected acceptance of untrusted verification URL")
        } catch let error as YandexOAuthError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    func testRefreshUsesExistingRefreshTokenWhenNotRotated() async throws {
        let transport = QueueTransport([
            .init(status: 200, json: Self.deviceCodeJSON),
            .init(status: 200, json: #"{"access_token":"first-access","refresh_token":"first-refresh","expires_in":10}"#),
            .init(status: 200, json: #"{"access_token":"second-access","expires_in":3600}"#)
        ])
        let client = YandexOAuthClient(transport: transport, clientID: "id", clientSecret: "secret")
        let code = try await client.requestDeviceCode()
        guard case .authorized(let first) = try await client.pollDeviceToken(code) else {
            return XCTFail("Expected initial token")
        }
        let second = try await client.refresh(first)
        XCTAssertEqual(second.accessToken, "second-access")
        XCTAssertEqual(second.refreshToken, "first-refresh")
        let requests = await transport.recordedRequests()
        let body = String(decoding: try XCTUnwrap(requests.last?.httpBody), as: UTF8.self)
        XCTAssertTrue(body.contains("grant_type=refresh_token"))
        XCTAssertTrue(body.contains("refresh_token=first-refresh"))
    }

    func testRefusesUntrustedAccessTokenPayload() async throws {
        let clientAndCode = try await makeClientAndCode(
            tokenStatus: 200,
            tokenJSON: #"{"access_token":"bad token with spaces","token_type":"bearer"}"#
        )
        do {
            _ = try await clientAndCode.client.pollDeviceToken(clientAndCode.code)
            XCTFail("Expected validation failure")
        } catch let error as YandexOAuthError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    func testRateLimitMappedToTypedError() async throws {
        let clientAndCode = try await makeClientAndCode(
            tokenStatus: 429,
            tokenJSON: #"{"error":"rate_limited"}"#
        )
        do {
            _ = try await clientAndCode.client.pollDeviceToken(clientAndCode.code)
            XCTFail("Expected rate-limit response")
        } catch let error as YandexOAuthError {
            XCTAssertEqual(error, .rateLimited)
        }
    }

    private func assertOAuthFailure(
        _ code: String,
        expected: YandexOAuthError
    ) async throws {
        let session = try await makeClientAndCode(
            tokenStatus: 400,
            tokenJSON: #"{"error":"\#(code)"}"#
        )
        do {
            _ = try await session.client.pollDeviceToken(session.code)
            XCTFail("Expected \(expected)")
        } catch let error as YandexOAuthError {
            XCTAssertEqual(error, expected)
        }
    }

    private func makeClientAndCode(
        tokenStatus: Int,
        tokenJSON: String
    ) async throws -> (client: YandexOAuthClient, code: OAuthDeviceCode) {
        let transport = QueueTransport([
            .init(status: 200, json: Self.deviceCodeJSON),
            .init(status: tokenStatus, json: tokenJSON)
        ])
        let client = YandexOAuthClient(transport: transport)
        return (client, try await client.requestDeviceCode())
    }

    private static let deviceCodeJSON =
        #"{"device_code":"internal-device-code","user_code":"ABCD-1234","verification_url":"https://yandex.ru/activate","expires_in":600,"interval":5}"#
}

actor QueueTransport: MusicHTTPTransport {
    struct Reply: Sendable {
        let status: Int
        let json: String
        let url: String?

        init(status: Int, json: String, url: String? = nil) {
            self.status = status
            self.json = json
            self.url = url
        }
    }

    private var replies: [Reply]
    private var captured: [URLRequest] = []

    init(_ replies: [Reply]) {
        self.replies = replies
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        captured.append(request)
        guard !replies.isEmpty else { throw YandexOAuthError.invalidResponse }
        let reply = replies.removeFirst()
        let responseURL = URL(string: reply.url ?? request.url!.absoluteString)!
        let response = HTTPURLResponse(
            url: responseURL,
            statusCode: reply.status,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(reply.json.utf8), response)
    }

    func recordedRequests() -> [URLRequest] { captured }
}
