import Foundation
import CoreEngine
import Security
@preconcurrency import os.log

/// Adapter wrapping KeychainService to conform to Engine expectations (minimal).
public struct KeychainServiceAdapter: Sendable {
    private let logger = Logger(subsystem: "chat.entelechia.uiconnections", category: "Keychain")

    public init() {}

    public func loadPassword(service: String, account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess else {
            logger.error("Keychain load failed for \(account, privacy: .private) status \(status)")
            throw KeychainError(status: status)
        }
        guard let data = result as? Data, let password = String(data: data, encoding: .utf8) else {
            throw KeychainError(status: errSecInternalError)
        }
        return password
    }

    public func savePassword(_ password: String, service: String, account: String) throws {
        guard let data = password.data(using: .utf8) else {
            throw KeychainError(status: errSecParam)
        }
        // Delete existing
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ] as CFDictionary)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("Keychain save failed for \(account, privacy: .private) status \(status)")
            throw KeychainError(status: status)
        }
    }

    public func deletePassword(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Keychain delete failed for \(account, privacy: .private) status \(status)")
            throw KeychainError(status: status)
        }
    }
}

public struct KeychainError: Error {
    public let status: OSStatus
}

