import Foundation

public enum MusicAPIError: Error, Equatable, Sendable {
    case invalidToken
    case invalidResponse
    case invalidPayload
    case unauthorized
    case forbidden
    case rateLimited
    case httpStatus(Int)
}

public struct MusicAccountStatus: Decodable, Sendable {
    public struct Account: Decodable, Sendable {
        public let uid: Int64?
        public let login: String?
    }

    public let account: Account?
}

public protocol MusicHTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct EphemeralMusicHTTPTransport: MusicHTTPTransport {
    private let session: URLSession

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(
            configuration: configuration,
            delegate: RejectRedirects(),
            delegateQueue: nil
        )
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw MusicAPIError.invalidResponse
        }
        return (data, response)
    }

    private final class RejectRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest
        ) async -> URLRequest? {
            nil
        }
    }
}

public struct YandexMusicAPIClient: Sendable {
    private static let accountStatusURL = URL(
        string: "https://api.music.yandex.net/account/status"
    )!

    private let transport: any MusicHTTPTransport

    public init(transport: any MusicHTTPTransport = EphemeralMusicHTTPTransport()) {
        self.transport = transport
    }

    public func accountStatus(accessToken: String) async throws -> MusicAccountStatus {
        guard !accessToken.isEmpty,
              accessToken.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              accessToken.unicodeScalars.allSatisfy({ !$0.properties.isControl }) else {
            throw MusicAPIError.invalidToken
        }

        var request = URLRequest(
            url: Self.accountStatusURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 15
        )
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("OAuth \\(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await transport.data(for: request)

        guard response.url?.scheme == "https",
              response.url?.host == "api.music.yandex.net",
              response.url?.port == nil else {
            throw MusicAPIError.invalidResponse
        }

        switch response.statusCode {
        case 200:
            break
        case 401:
            throw MusicAPIError.unauthorized
        case 403:
            throw MusicAPIError.forbidden
        case 429:
            throw MusicAPIError.rateLimited
        default:
            throw MusicAPIError.httpStatus(response.statusCode)
        }

        guard let envelope = try? JSONDecoder().decode(AccountStatusEnvelope.self, from: data),
              let result = envelope.result else {
            throw MusicAPIError.invalidPayload
        }
        return result
    }

    private struct AccountStatusEnvelope: Decodable {
        let result: MusicAccountStatus?
    }
}
