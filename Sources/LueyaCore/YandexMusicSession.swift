import Foundation

public actor YandexMusicSession {
    private let oauth: YandexOAuthClient
    private let api: YandexMusicAPIClient
    private let store: any OAuthTokenStoring
    private var tokens: OAuthTokens?
    private var sessionGeneration: UInt64 = 0

    public init(
        oauth: YandexOAuthClient = YandexOAuthClient(),
        api: YandexMusicAPIClient = YandexMusicAPIClient(),
        store: any OAuthTokenStoring = KeychainOAuthTokenStore()
    ) {
        self.oauth = oauth
        self.api = api
        self.store = store
    }

    public func beginSignIn() async throws -> OAuthDeviceCode {
        try await oauth.requestDeviceCode()
    }

    public func completeSignIn(code: OAuthDeviceCode) async throws -> MusicAccountStatus {
        let generation = sessionGeneration
        let obtained = try await oauth.awaitAuthorization(code)
        try Task.checkCancellation()

        // Do not persist a token that cannot access this user's Music account.
        let account = try await api.accountStatus(accessToken: obtained.accessToken)
        guard let uid = account.account?.uid, uid > 0 else {
            throw MusicAPIError.unauthorized
        }
        try Task.checkCancellation()
        guard sessionGeneration == generation else { throw CancellationError() }

        try store.save(obtained)
        tokens = obtained
        return account
    }

    public func restoreAccount() async throws -> MusicAccountStatus? {
        let stored: OAuthTokens
        if let tokens {
            // Avoid repeating Keychain authorization after a network failure.
            stored = tokens
        } else {
            guard let saved = try store.load() else { return nil }
            stored = saved
            tokens = saved
        }

        let generation = sessionGeneration
        do {
            let (active, account) = try await validatedAccount(
                using: stored, generation: generation
            )
            try Task.checkCancellation()
            guard sessionGeneration == generation else { throw CancellationError() }
            tokens = active
            return account
        } catch {
            try Task.checkCancellation()
            guard sessionGeneration == generation else { throw CancellationError() }
            if Self.isTemporaryNetworkFailure(error) {
                // The saved token is still present. A temporary network outage
                // must not turn session restoration into a new OAuth login.
                return MusicAccountStatus(account: nil)
            }
            throw error
        }
    }

    private static func isTemporaryNetworkFailure(_ error: Error) -> Bool {
        if error is URLError { return true }
        if let failure = error as? MusicAPIError {
            switch failure {
            case .rateLimited: return true
            case .httpStatus(let code): return code >= 500
            default: return false
            }
        }
        if let failure = error as? YandexOAuthError {
            switch failure {
            case .rateLimited: return true
            case .httpStatus(let code): return code >= 500
            default: return false
            }
        }
        return false
    }

    public func validAccessToken() async throws -> String? {
        let stored: OAuthTokens?
        if let tokens {
            stored = tokens
        } else {
            stored = try store.load()
        }
        guard let current = stored else { return nil }
        if current.needsRefresh() {
            guard current.refreshToken != nil else {
                throw YandexOAuthError.expired
            }
            let generation = sessionGeneration
            let updated = try await oauth.refresh(current)
            try Task.checkCancellation()
            guard sessionGeneration == generation else { throw CancellationError() }
            try store.save(updated)
            tokens = updated
            return updated.accessToken
        }
        tokens = current
        return current.accessToken
    }

    public func signOut() throws {
        try store.delete()
        sessionGeneration &+= 1
        tokens = nil
    }

    private func validatedAccount(
        using initial: OAuthTokens,
        generation: UInt64
    ) async throws -> (OAuthTokens, MusicAccountStatus) {
        var current = initial
        if current.needsRefresh() {
            guard current.refreshToken != nil else {
                throw YandexOAuthError.expired
            }
            current = try await oauth.refresh(current)
        }

        let account: MusicAccountStatus
        do {
            account = try await api.accountStatus(accessToken: current.accessToken)
        } catch MusicAPIError.unauthorized {
            guard current.refreshToken != nil else { throw MusicAPIError.unauthorized }
            current = try await oauth.refresh(current)
            account = try await api.accountStatus(accessToken: current.accessToken)
        }

        guard let uid = account.account?.uid, uid > 0 else {
            throw MusicAPIError.unauthorized
        }

        if current.accessToken != initial.accessToken ||
            current.refreshToken != initial.refreshToken {
            try Task.checkCancellation()
            guard sessionGeneration == generation else { throw CancellationError() }
            try store.save(current)
        }

        return (current, account)
    }
}
