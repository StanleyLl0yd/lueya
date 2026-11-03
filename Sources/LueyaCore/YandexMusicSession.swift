import Foundation

public actor YandexMusicSession {
    private let oauth: YandexOAuthClient
    private let api: YandexMusicAPIClient
    private let store: any OAuthTokenStoring
    private var tokens: OAuthTokens?

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
        let obtained = try await oauth.awaitAuthorization(code)
        try Task.checkCancellation()

        // Do not persist a token that cannot access this user's Music account.
        let account = try await api.accountStatus(accessToken: obtained.accessToken)
        guard let uid = account.account?.uid, uid > 0 else {
            throw MusicAPIError.unauthorized
        }
        try Task.checkCancellation()

        try store.save(obtained)
        tokens = obtained
        return account
    }

    public func restoreAccount() async throws -> MusicAccountStatus? {
        guard let stored = try store.load() else { return nil }
        let (active, account) = try await validatedAccount(using: stored)
        try Task.checkCancellation()
        tokens = active
        return account
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
            let updated = try await oauth.refresh(current)
            try Task.checkCancellation()
            try store.save(updated)
            tokens = updated
            return updated.accessToken
        }
        tokens = current
        return current.accessToken
    }

    public func signOut() throws {
        try store.delete()
        tokens = nil
    }

    private func validatedAccount(
        using initial: OAuthTokens
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
            try store.save(current)
        }

        return (current, account)
    }
}
