import XCTest
@testable import ChatUI
import Security
import os.log

final class CodexConfigLoaderTests: XCTestCase {

    override func tearDown() {
        // Clean env overrides
        unsetenv("CODEX_API_KEY")
        unsetenv("CODEX_BASE_URL")
        unsetenv("CODEX_ORG")
        super.tearDown()
    }

    func testEnvOverridesKeychainAndPlist() throws {
        let loader = CodexConfigLoader(keychain: InMemoryKeychain())
        setenv("CODEX_API_KEY", "env-key", 1)
        setenv("CODEX_BASE_URL", "https://env.example", 1)
        setenv("CODEX_ORG", "env-org", 1)

        let result = loader.loadConfig()
        switch result {
        case .success(let cfg):
            XCTAssertEqual(cfg.apiKey, "env-key")
            XCTAssertEqual(cfg.baseURL.absoluteString, "https://env.example")
            XCTAssertEqual(cfg.organization, "env-org")
        case .failure(let err):
            XCTFail("Expected success, got \(err)")
        }
    }

    func testKeychainUsedWhenEnvMissing() throws {
        let keychain = InMemoryKeychain()
        try keychain.savePassword("kc-key", for: .codexAPIKey)
        let loader = CodexConfigLoader(keychain: keychain)

        let result = loader.loadConfig()
        switch result {
        case .success(let cfg):
            XCTAssertEqual(cfg.apiKey, "kc-key")
        case .failure(let err):
            XCTFail("Expected success, got \(err)")
        }
    }

    func testFailureWhenNoSources() {
        let loader = CodexConfigLoader(keychain: InMemoryKeychain())
        let result = loader.loadConfig()
        guard case .failure(let err) = result else {
            return XCTFail("Expected failure with missing credentials")
        }
        switch err {
        case .missingCredentials: break
        default: XCTFail("Unexpected error \(err)")
        }
    }
}

// MARK: - In-memory keychain stub

private final class InMemoryKeychain: KeychainServicing {
    private var store: [String: Data] = [:]

    func loadPassword(for credential: KeychainCredential) throws -> String? {
        guard let data = store[key(credential)] else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func savePassword(_ password: String, for credential: KeychainCredential) throws {
        store[key(credential)] = password.data(using: .utf8)
    }

    func deletePassword(for credential: KeychainCredential) throws {
        store.removeValue(forKey: key(credential))
    }

    private func key(_ credential: KeychainCredential) -> String {
        "\(credential.service)|\(credential.account)"
    }
}

