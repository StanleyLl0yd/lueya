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
    private enum Backend {
        case dataProtection
        case traditional
    }

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
        let (status, data) = read(.dataProtection)
        switch status {
        case errSecSuccess:
            return try decode(data)
        case errSecItemNotFound, errSecMissingEntitlement:
            // An ad-hoc development signature might not have an app-ID entitlement.
            // The traditional login Keychain is still encrypted by macOS.
            let (legacyStatus, legacyData) = read(.traditional)
            switch legacyStatus {
            case errSecSuccess:
                return try decode(legacyData)
            case errSecItemNotFound:
                return nil
            default:
                throw TokenStorageError.keychainStatus(legacyStatus)
            }
        default:
            throw TokenStorageError.keychainStatus(status)
        }
    }

    public func save(_ tokens: OAuthTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        let status = upsert(data, backend: .dataProtection)

        switch status {
        case errSecSuccess:
            // Migrate from the legacy Keychain when a signed build later gains
            // Data Protection access; leave the new item intact if migration fails.
            let legacyStatus = SecItemDelete(query(.traditional) as CFDictionary)
            guard legacyStatus == errSecSuccess || legacyStatus == errSecItemNotFound else {
                throw TokenStorageError.keychainStatus(legacyStatus)
            }
        case errSecMissingEntitlement:
            let legacyStatus = upsert(data, backend: .traditional)
            guard legacyStatus == errSecSuccess else {
                throw TokenStorageError.keychainStatus(legacyStatus)
            }
        default:
            throw TokenStorageError.keychainStatus(status)
        }
    }

    public func delete() throws {
        let primary = SecItemDelete(query(.dataProtection) as CFDictionary)
        guard primary == errSecSuccess || primary == errSecItemNotFound ||
                primary == errSecMissingEntitlement else {
            throw TokenStorageError.keychainStatus(primary)
        }

        let traditional = SecItemDelete(query(.traditional) as CFDictionary)
        guard traditional == errSecSuccess || traditional == errSecItemNotFound else {
            throw TokenStorageError.keychainStatus(traditional)
        }
    }

    private func read(_ backend: Backend) -> (OSStatus, Data?) {
        var attributes = query(backend)
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(attributes as CFDictionary, &result)
        return (status, result as? Data)
    }

    private func upsert(_ data: Data, backend: Backend) -> OSStatus {
        var attributes = query(backend)
        attributes[kSecValueData as String] = data
        if backend == .dataProtection {
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecDuplicateItem else { return status }
        return SecItemUpdate(
            query(backend) as CFDictionary,
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

    private func query(_ backend: Backend) -> [String: Any] {
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
