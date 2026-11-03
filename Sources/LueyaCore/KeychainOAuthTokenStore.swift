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

public struct KeychainOAuthTokenStore: OAuthTokenStoring {
    private let service: String
    private let account: String

    public init(
        service: String = "com.stanleylloyd.lueya.yandex-music",
        account: String = "oauth-session"
    ) {
        self.service = service
        self.account = account
    }

    public func load() throws -> OAuthTokens? {
        var query = itemQuery
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw TokenStorageError.keychainStatus(status)
        }
        guard let data = result as? Data,
              let tokens = try? JSONDecoder().decode(OAuthTokens.self, from: data) else {
            throw TokenStorageError.invalidStoredData
        }
        return tokens
    }

    public func save(_ tokens: OAuthTokens) throws {
        let data = try JSONEncoder().encode(tokens)

        var attributes = itemQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let updated = SecItemUpdate(
                itemQuery as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
            guard updated == errSecSuccess else {
                throw TokenStorageError.keychainStatus(updated)
            }
        default:
            throw TokenStorageError.keychainStatus(status)
        }
    }

    public func delete() throws {
        let status = SecItemDelete(itemQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TokenStorageError.keychainStatus(status)
        }
    }

    private var itemQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true
        ]
    }
}
