import Foundation

public enum YandexOAuthError: Error, Equatable, Sendable {
    case invalidResponse
    case invalidVerificationURL
    case invalidCredentials
    case authorizationDenied
    case expired
    case rateLimited
    case invalidClient
    case httpStatus(Int)
}

public struct OAuthDeviceCode: Sendable {
    public let userCode: String
    public let verificationURL: URL
    public let expiresIn: Int
    public let interval: Int
    fileprivate let deviceCode: String

    fileprivate init(
        userCode: String,
        verificationURL: URL,
        expiresIn: Int,
        interval: Int,
        deviceCode: String
    ) {
        self.userCode = userCode
        self.verificationURL = verificationURL
        self.expiresIn = expiresIn
        self.interval = interval
        self.deviceCode = deviceCode
    }
}

public struct OAuthTokens: Codable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: Date?

    public var description: String { "OAuthTokens(redacted)" }
    public var debugDescription: String { description }

    public func needsRefresh(now: Date = Date(), leeway: TimeInterval = 120) -> Bool {
        guard let expiresAt else { return false }
        return now.addingTimeInterval(leeway) >= expiresAt
    }

    fileprivate init(accessToken: String, refreshToken: String?, expiresAt: Date?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }
}

public enum OAuthPollingResult: Sendable {
    case pending
    case slowDown
    case authorized(OAuthTokens)
}

public struct YandexOAuthClient: Sendable {
    // Public credentials of the official Yandex Music Android client, documented by
    // MarshalX/yandex-music-api. These are NOT credentials issued to lueya.
    // Use is unofficial and can be revoked by the provider without notice.
    public static let publicClientID = "23cabbbdc6cd418abb4b39c32c41195d"
    public static let publicClientSecret = "53bc75238f0c4d08a118e51fe9203300"

    private static let codeURL = URL(string: "https://oauth.yandex.ru/device/code")!
    private static let tokenURL = URL(string: "https://oauth.yandex.ru/token")!

    private let transport: any MusicHTTPTransport
    private let clientID: String
    private let clientSecret: String

    public init(
        transport: any MusicHTTPTransport = EphemeralMusicHTTPTransport(),
        clientID: String = publicClientID,
        clientSecret: String = publicClientSecret
    ) {
        self.transport = transport
        self.clientID = clientID
        self.clientSecret = clientSecret
    }

    public func requestDeviceCode() async throws -> OAuthDeviceCode {
        let payload = try await post(
            to: Self.codeURL,
            fields: [
                ("client_id", clientID),
                ("device_id", UUID().uuidString.replacingOccurrences(of: "-", with: "")),
                ("device_name", "lueya")
            ]
        )
        let model = try decode(DeviceCodeResponse.self, from: payload)
        guard !model.deviceCode.isEmpty,
              !model.userCode.isEmpty,
              model.expiresIn > 0,
              model.expiresIn <= 86_400,
              model.interval > 0,
              model.interval <= 300,
              let verificationURL = URL(string: model.verificationUrl),
              Self.isTrustedVerificationURL(verificationURL) else {
            throw YandexOAuthError.invalidResponse
        }
        return OAuthDeviceCode(
            userCode: model.userCode,
            verificationURL: verificationURL,
            expiresIn: model.expiresIn,
            interval: model.interval,
            deviceCode: model.deviceCode
        )
    }

    public func pollDeviceToken(_ code: OAuthDeviceCode) async throws -> OAuthPollingResult {
        let payload: Data
        do {
            payload = try await post(
                to: Self.tokenURL,
                fields: [
                    ("grant_type", "device_code"),
                    ("code", code.deviceCode),
                    ("client_id", clientID),
                    ("client_secret", clientSecret)
                ]
            )
        } catch YandexOAuthError.httpStatus(400) {
            throw YandexOAuthError.invalidResponse
        }

        if let error = try? JSONDecoder().decode(OAuthErrorResponse.self, from: payload) {
            return try interpretOAuthError(error.error)
        }

        return .authorized(try parseTokens(from: payload, replacing: nil))
    }

    public func refresh(_ old: OAuthTokens) async throws -> OAuthTokens {
        guard let refreshToken = old.refreshToken, !refreshToken.isEmpty else {
            throw YandexOAuthError.invalidCredentials
        }
        let payload = try await post(
            to: Self.tokenURL,
            fields: [
                ("grant_type", "refresh_token"),
                ("refresh_token", refreshToken),
                ("client_id", clientID),
                ("client_secret", clientSecret)
            ]
        )
        return try parseTokens(from: payload, replacing: old.refreshToken)
    }

    public func awaitAuthorization(_ code: OAuthDeviceCode) async throws -> OAuthTokens {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(code.expiresIn))
        var interval = code.interval

        while clock.now < deadline {
            try Task.checkCancellation()
            try await Task.sleep(for: .seconds(interval))
            try Task.checkCancellation()
            guard clock.now < deadline else { break }

            switch try await pollDeviceToken(code) {
            case .pending:
                break
            case .slowDown:
                interval = min(300, interval + 5)
            case .authorized(let tokens):
                return tokens
            }
        }
        throw YandexOAuthError.expired
    }

    private func post(to url: URL, fields: [(String, String)]) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let form = fields.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed)!
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed)!
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
        request.httpBody = Data(form.utf8)

        let (data, response) = try await transport.data(for: request)
        guard response.url?.scheme == "https",
              response.url?.host == "oauth.yandex.ru",
              response.url?.port == nil,
              response.url?.path == url.path else {
            throw YandexOAuthError.invalidResponse
        }

        if response.statusCode == 400 || response.statusCode == 401 || response.statusCode == 403 {
            if let error = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
                switch try interpretOAuthError(error.error) {
                case .pending, .slowDown:
                    return data
                case .authorized:
                    throw YandexOAuthError.invalidResponse
                }
            }
        }
        switch response.statusCode {
        case 200: return data
        case 401, 403: throw YandexOAuthError.invalidCredentials
        case 429: throw YandexOAuthError.rateLimited
        default: throw YandexOAuthError.httpStatus(response.statusCode)
        }
    }

    private func interpretOAuthError(_ value: String) throws -> OAuthPollingResult {
        switch value {
        case "authorization_pending": return .pending
        case "slow_down": return .slowDown
        case "access_denied": throw YandexOAuthError.authorizationDenied
        case "expired_token": throw YandexOAuthError.expired
        case "invalid_client": throw YandexOAuthError.invalidClient
        case "invalid_grant", "invalid_token": throw YandexOAuthError.invalidCredentials
        default: throw YandexOAuthError.invalidResponse
        }
    }

    private func parseTokens(from data: Data, replacing previousRefreshToken: String?) throws -> OAuthTokens {
        let model = try decode(TokenResponse.self, from: data)
        guard Self.isValidToken(model.accessToken),
              model.tokenType == nil || model.tokenType?.lowercased() == "bearer" else {
            throw YandexOAuthError.invalidResponse
        }
        let refreshToken = model.refreshToken ?? previousRefreshToken
        guard refreshToken == nil || Self.isValidToken(refreshToken!) else {
            throw YandexOAuthError.invalidResponse
        }
        if let seconds = model.expiresIn, seconds <= 0 {
            throw YandexOAuthError.invalidResponse
        }
        let expiresAt = model.expiresIn.map { Date().addingTimeInterval(TimeInterval($0)) }
        return OAuthTokens(
            accessToken: model.accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt
        )
    }

    private static func isValidToken(_ token: String) -> Bool {
        !token.isEmpty && token.utf8.allSatisfy { $0 >= 0x21 && $0 <= 0x7E }
    }

    public static func isTrustedVerificationURL(_ url: URL) -> Bool {
        guard url.scheme == "https", url.user == nil, url.password == nil,
              url.port == nil, let host = url.host?.lowercased() else {
            return false
        }
        return host == "yandex.ru" || host.hasSuffix(".yandex.ru")
            || host == "ya.ru" || host.hasSuffix(".ya.ru")
            || host == "yandex.com" || host.hasSuffix(".yandex.com")
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let value = try? decoder.decode(type, from: data) else {
            throw YandexOAuthError.invalidResponse
        }
        return value
    }

    private struct DeviceCodeResponse: Decodable {
        let deviceCode: String
        let userCode: String
        let verificationUrl: String
        let expiresIn: Int
        let interval: Int
    }

    private struct OAuthErrorResponse: Decodable {
        let error: String
    }

    private struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: Int?
        let tokenType: String?
    }
}
