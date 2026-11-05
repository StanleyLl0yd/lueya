import Foundation
import Security

public enum TokenStorageError: Error, Equatable, Sendable {
    case keychainStatus(OSStatus)
    case invalidStoredData
}

public protocol OAuthTokenStoring: Sendable {
    func load() throws -> OAuthTokens?
    func save(_ tokens: OAuthTokens) throws
    func delete() throws
}

/// A versioned account avoids reusing an ACL created by older ad-hoc builds.
/// The service remains unchanged; no tokens leave the local macOS Keychain.
public struct KeychainOAuthTokenStore: OAuthTokenStoring {
    private enum Backend {
        case dataProtection
        case traditional
    }

    private let service: String
    private let account: String
    private let legacyAccount: String?

    public init(
        service: String = "com.stanleylloyd.lueya.yandex-music",
        account: String = "oauth-session-v2"
    ) {
        self.service = service
        self.account = account
        self.legacyAccount = account == "oauth-session-v2" ? "oauth-session" : nil
    }

    public func load() throws -> OAuthTokens? {
        if let current = try load(account: account) {
            return current
        }
        guard let legacyAccount,
              let old = try load(account: legacyAccount) else {
            return nil
        }

        // Once permitted to read the old item, create a separate account
        // under the stable, currently signed app's default Keychain ACL.
        // Never delete the only copy when creating the replacement fails.
        do {
            try save(old)
        } catch {
            return old
        }
        return old
    }

    public func save(_ tokens: OAuthTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        let primary = upsert(data, backend: .dataProtection, account: account)

        switch primary {
        case errSecSuccess:
            break
        case errSecMissingEntitlement:
            let fallback = upsert(data, backend: .traditional, account: account)
            guard fallback == errSecSuccess else {
                throw TokenStorageError.keychainStatus(fallback)
            }
        default:
            throw TokenStorageError.keychainStatus(primary)
        }

        // Check the new Keychain entry before removing the old one.
        guard let verified = try load(account: account),
              verified.accessToken == tokens.accessToken,
              verified.refreshToken == tokens.refreshToken else {
            throw TokenStorageError.invalidStoredData
        }
        switch (verified.expiresAt, tokens.expiresAt) {
        case (nil, nil):
            break
        case (let actual?, let expected?) where
            abs(actual.timeIntervalSince(expected)) < 0.01:
            break
        default:
            throw TokenStorageError.invalidStoredData
        }

        // A failed legacy cleanup must not invalidate a verified new item.
        if let legacyAccount {
            removeLegacyIfPermitted(legacyAccount)
        }
    }

    public func delete() throws {
        // Explicit sign-out deletes both current and historical entries.
        let accounts = [account] + (legacyAccount.map { [$0] } ?? [])
        var failure: OSStatus?
        for account in accounts {
            for backend in [Backend.dataProtection, .traditional] {
                let status = SecItemDelete(query(backend, account: account) as CFDictionary)
                if status != errSecSuccess && status != errSecItemNotFound &&
                    status != errSecMissingEntitlement {
                    failure = failure ?? status
                }
            }
        }
        if let failure {
            throw TokenStorageError.keychainStatus(failure)
        }
    }

    private func load(account: String) throws -> OAuthTokens? {
        let (primaryStatus, primaryData) = read(.dataProtection, account: account)
        switch primaryStatus {
        case errSecSuccess:
            return try decode(primaryData)
        case errSecItemNotFound, errSecMissingEntitlement:
            let (status, data) = read(.traditional, account: account)
            switch status {
            case errSecSuccess: return try decode(data)
            case errSecItemNotFound: return nil
            default: throw TokenStorageError.keychainStatus(status)
            }
        default:
            throw TokenStorageError.keychainStatus(primaryStatus)
        }
    }

    private func removeLegacyIfPermitted(_ legacyAccount: String) {
        for backend in [Backend.dataProtection, .traditional] {
            var attributes = query(backend, account: legacyAccount)
            // Do not show another permission prompt solely to remove the
            // historical copy. An inaccessible item is removed on sign-out.
            attributes[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
            _ = SecItemDelete(attributes as CFDictionary)
        }
    }

    private func read(_ backend: Backend, account: String) -> (OSStatus, Data?) {
        var attributes = query(backend, account: account)
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(attributes as CFDictionary, &result)
        return (status, result as? Data)
    }

    private func upsert(_ data: Data, backend: Backend, account: String) -> OSStatus {
        var attributes = query(backend, account: account)
        attributes[kSecValueData as String] = data
        if backend == .dataProtection {
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecDuplicateItem else { return status }
        return SecItemUpdate(
            query(backend, account: account) as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
    }

    private func decode(_ data: Data?) throws -> OAuthTokens {
        guard let data,
              let tokens = try? JSONDecoder().decode(OAuthTokens.self, from: data) else {
            throw TokenStorageError.invalidStoredData
        }
        return tokens
    }

    private func query(_ backend: Backend, account: String) -> [String: Any] {
        var attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if backend == .dataProtection {
            attributes[kSecUseDataProtectionKeychain as String] = true
        }
        return attributes
    }
}
