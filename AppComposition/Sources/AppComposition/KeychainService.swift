import Foundation
import Security
import os.log

public struct KeychainCredential: Equatable {
    public let service: String
    public let account: String

    public static let codexAPIKey = KeychainCredential(
        service: "chat.entelechia.codex",
        account: "CODEX_API_KEY"
    )

    public init(service: String, account: String) {
        self.service = service
        self.account = account
    }
}

public enum KeychainServiceError: LocalizedError {
    case encodingFailure
    case decodingFailure
    case operationFailed(status: OSStatus)

    public var errorDescription: String? {
        switch self {
        case .encodingFailure:
            return "Failed to encode value for Keychain storage."
        case .decodingFailure:
            return "Failed to decode value from Keychain."
        case .operationFailed(let status):
            return "Keychain operation failed with status \(status)."
        }
    }
}

public protocol KeychainServicing {
    func loadPassword(for credential: KeychainCredential) throws -> String?
    func savePassword(_ password: String, for credential: KeychainCredential) throws
    func deletePassword(for credential: KeychainCredential) throws
}

public struct KeychainService: KeychainServicing {
    public static let shared = KeychainService()

    private let logger = Logger.security
    private init() {}

    public func loadPassword(for credential: KeychainCredential) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: credential.service,
            kSecAttrAccount as String: credential.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            logger.debug("Keychain load success for account \(credential.account, privacy: .private).")
            guard
                let data = result as? Data,
                let password = String(data: data, encoding: .utf8)
            else {
                throw KeychainServiceError.decodingFailure
            }
            return password

        case errSecItemNotFound:
            logger.debug("Keychain entry not found for account \(credential.account, privacy: .private).")
            return nil

        default:
            logger.error("Keychain load failed for account \(credential.account, privacy: .private) status \(status).")
            throw KeychainServiceError.operationFailed(status: status)
        }
    }

    public func savePassword(_ password: String, for credential: KeychainCredential) throws {
        try deletePassword(for: credential)

        guard let data = password.data(using: .utf8) else {
            throw KeychainServiceError.encodingFailure
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: credential.service,
            kSecAttrAccount as String: credential.account,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("Keychain save failed for account \(credential.account, privacy: .private) status \(status).")
            throw KeychainServiceError.operationFailed(status: status)
        }

        logger.debug("Keychain save success for account \(credential.account, privacy: .private).")
    }

    public func deletePassword(for credential: KeychainCredential) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: credential.service,
            kSecAttrAccount as String: credential.account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Keychain delete failed for account \(credential.account, privacy: .private) status \(status).")
            throw KeychainServiceError.operationFailed(status: status)
        }

        logger.debug("Keychain delete success for account \(credential.account, privacy: .private).")
    }
}


