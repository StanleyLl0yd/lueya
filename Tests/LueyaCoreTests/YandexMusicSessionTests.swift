import Foundation
import XCTest
@testable import LueyaCore

final class YandexMusicSessionTests: XCTestCase {
    func testSignInVerifiesAccountBeforeSavingTokens() async throws {
        let oauthTransport = SessionOAuthTransport()
        let accountTransport = AccountStatusTransport(
            status: 200,
            body: #"{"result":{"account":{"uid":42,"login":"listener"}}}"#
        )
        let store = MemoryTokenStore()
        let session = YandexMusicSession(
            oauth: YandexOAuthClient(transport: oauthTransport, clientID: "id", clientSecret: "secret"),
            api: YandexMusicAPIClient(transport: accountTransport),
            store: store
        )

        XCTAssertNil(try store.load())
        let code = try await session.beginSignIn()
        let result = try await session.completeSignIn(code: code)
        XCTAssertEqual(result.account?.uid, 42)
        XCTAssertEqual(result.account?.login, "listener")
        XCTAssertEqual(try store.load()?.accessToken, "sample-token")
        let accessToken = try await session.validAccessToken()
        XCTAssertEqual(accessToken, "sample-token")
        let authorization = await accountTransport.receivedAuthorization()
        XCTAssertEqual(authorization, "OAuth sample-token")

        try await session.signOut()
        XCTAssertNil(try store.load())
        let afterSignOut = try await session.validAccessToken()
        XCTAssertNil(afterSignOut)
    }

    func testGuestStatusNeverPersistsCredentials() async throws {
        let store = MemoryTokenStore()
        let session = YandexMusicSession(
            oauth: YandexOAuthClient(
                transport: SessionOAuthTransport(),
                clientID: "id",
                clientSecret: "secret"
            ),
            api: YandexMusicAPIClient(
                transport: AccountStatusTransport(status: 200, body: #"{"result":{"account":null}}"#)
            ),
            store: store
        )
        let code = try await session.beginSignIn()
        do {
            _ = try await session.completeSignIn(code: code)
            XCTFail("Unexpected guest account acceptance")
        } catch let error as MusicAPIError {
            XCTAssertEqual(error, .unauthorized)
        }
        XCTAssertNil(try store.load())
    }

    func testRestoreWithoutStoredSession() async throws {
        let session = YandexMusicSession(
            oauth: YandexOAuthClient(transport: SessionOAuthTransport()),
            api: YandexMusicAPIClient(transport: AccountStatusTransport()),
            store: MemoryTokenStore()
        )
        let result = try await session.restoreAccount()
        XCTAssertNil(result)
    }

    func testTemporaryAccountOutagePreservesSavedSessionWithoutNewLogin() async throws {
        let store = MemoryTokenStore()
        let oauth = YandexOAuthClient(
            transport: SessionOAuthTransport(),
            clientID: "id", clientSecret: "secret"
        )
        let original = YandexMusicSession(
            oauth: oauth,
            api: YandexMusicAPIClient(transport: AccountStatusTransport()),
            store: store
        )
        let code = try await original.beginSignIn()
        _ = try await original.completeSignIn(code: code)

        let restored = YandexMusicSession(
            oauth: oauth,
            api: YandexMusicAPIClient(transport: AccountStatusTransport(status: 503)),
            store: store
        )
        let beforeLoad = store.loadCount()
        let status = try await restored.restoreAccount()
        XCTAssertNotNil(status)
        XCTAssertNil(status?.account)
        XCTAssertEqual(store.loadCount(), beforeLoad + 1)

        let token = try await restored.validAccessToken()
        XCTAssertEqual(token, "sample-token")
        XCTAssertEqual(store.loadCount(), beforeLoad + 1)

        let again = try await restored.restoreAccount()
        XCTAssertNil(again?.account)
        XCTAssertEqual(store.loadCount(), beforeLoad + 1)
    }

    func testUnauthorizedRestoreDoesNotEraseStoredCredentials() async throws {
        let store = MemoryTokenStore()
        let oauth = YandexOAuthClient(
            transport: SessionOAuthTransport(),
            clientID: "id", clientSecret: "secret"
        )
        let original = YandexMusicSession(
            oauth: oauth,
            api: YandexMusicAPIClient(transport: AccountStatusTransport()),
            store: store
        )
        let code = try await original.beginSignIn()
        _ = try await original.completeSignIn(code: code)

        let restored = YandexMusicSession(
            oauth: oauth,
            api: YandexMusicAPIClient(transport: AccountStatusTransport(status: 401)),
            store: store
        )
        do {
            _ = try await restored.restoreAccount()
            XCTFail("Unauthorized account must not be silently accepted")
        } catch let error as MusicAPIError {
            XCTAssertEqual(error, .unauthorized)
        }
        XCTAssertEqual(try store.load()?.accessToken, "sample-token")
    }

    private actor SessionOAuthTransport: MusicHTTPTransport {
        func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            guard request.url?.host == "oauth.yandex.ru" else {
                throw YandexOAuthError.invalidResponse
            }
            let json: String
            switch request.url?.path {
            case "/device/code":
                json = #"{"device_code":"private-code","user_code":"1111-2222","verification_url":"https://yandex.ru/activate","interval":1,"expires_in":30}"#
            case "/token":
                json = #"{"access_token":"sample-token","refresh_token":"sample-refresh","expires_in":3600,"token_type":"bearer"}"#
            default:
                throw YandexOAuthError.invalidResponse
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(json.utf8), response)
        }
    }

    private actor AccountStatusTransport: MusicHTTPTransport {
        let status: Int
        let body: String
        private var authorization: String?

        init(
            status: Int = 200,
            body: String = #"{"result":{"account":{"uid":42}}}"#
        ) {
            self.status = status
            self.body = body
        }

        func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            authorization = request.value(forHTTPHeaderField: "Authorization")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(body.utf8), response)
        }

        func receivedAuthorization() -> String? { authorization }
    }

    private final class MemoryTokenStore: OAuthTokenStoring, @unchecked Sendable {
        private let lock = NSLock()
        private var tokens: OAuthTokens?
        private var reads = 0

        func loadCount() -> Int {
            lock.withLock { reads }
        }

        func load() throws -> OAuthTokens? {
            lock.withLock {
                reads += 1
                return tokens
            }
        }

        func save(_ value: OAuthTokens) throws {
            lock.withLock { tokens = value }
        }

        func delete() throws {
            lock.withLock { tokens = nil }
        }
    }
}
