import Foundation
import os.log
import Security

private extension Bundle {
    static var appAdaptersModule: Bundle = {
        let bundleName = "AppAdapters_AppAdapters"
        let candidates = [
            Bundle.main.resourceURL,
            Bundle(for: _AppAdaptersBundleToken.self).resourceURL,
            Bundle.main.bundleURL,
            Bundle.main.bundleURL.deletingLastPathComponent(),
            Bundle(for: _AppAdaptersBundleToken.self).bundleURL,
            Bundle(for: _AppAdaptersBundleToken.self).bundleURL.deletingLastPathComponent()
        ]
        for candidate in candidates {
            if let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle"),
               let bundle = Bundle(url: bundlePath) {
                return bundle
            }
        }
        return Bundle(for: _AppAdaptersBundleToken.self)
    }()
}

public struct CodexConfig: Equatable {
    public enum Source: String {
        case environment
        case keychain
        case secretsFile
    }

    public static let defaultBaseURL = URL(string: "https://api.openai.com/v1")!

    public let apiKey: String
    public let baseURL: URL
    public let organization: String?
    public let source: Source
}

public enum CodexConfigError: LocalizedError {
    case missingCredentials
    case missingAPIKey
    case invalidBaseURL
    case secretsFileMissing
    case secretsDecodingFailed
    case keychainFailure(OSStatus)
    case keychainService(KeychainServiceError)

    public var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "No Codex credentials were found in environment variables, the Keychain, or CodexSecrets.plist."
        case .missingAPIKey:
            return "Codex API key is missing."
        case .invalidBaseURL:
            return "Codex base URL is invalid."
        case .secretsFileMissing:
            return "CodexSecrets.plist was not found in the application bundle."
        case .secretsDecodingFailed:
            return "CodexSecrets.plist could not be decoded."
        case .keychainFailure(let status):
            return "Keychain error (status \(status))."
        case .keychainService(let serviceError):
            return serviceError.errorDescription
        }
    }
}

public protocol CodexConfigLoading {
    func loadConfig() -> Result<CodexConfig, CodexConfigError>
}

private final class _AppAdaptersBundleToken {}

public struct CodexConfigLoader: CodexConfigLoading {
    public static var secretsBundle: Bundle = .appAdaptersModule

    private let keychain: KeychainServicing
    private let logger = Logger(subsystem: "chat.entelechia", category: "Security")

    public init(keychain: KeychainServicing = KeychainService.shared) {
        self.keychain = keychain
    }

    /// Credential precedence:
    /// 1) Environment variables (CODEX_API_KEY / CODEX_BASE_URL / CODEX_ORG)
    /// 2) Keychain entry (service: chat.entelechia.codex, account: CODEX_API_KEY) with env overrides for baseURL/org
    /// 3) Bundle CodexSecrets.plist
    public func loadConfig() -> Result<CodexConfig, CodexConfigError> {
        if let envConfig = loadFromEnvironment() {
            return .success(envConfig)
        }

        if let keychainResult = loadFromKeychain() {
            return keychainResult
        }

        if let secretsResult = loadFromSecretsFile() {
            return secretsResult
        }

        return .failure(.missingCredentials)
    }

    private func loadFromEnvironment() -> CodexConfig? {
        let environment = ProcessInfo.processInfo.environment
        guard let apiKey = environment["CODEX_API_KEY"], !apiKey.isEmpty else {
            return nil
        }

        let baseURL = environment["CODEX_BASE_URL"].flatMap(URL.init(string:))
        let organization = environment["CODEX_ORG"]
        return CodexConfig(
            apiKey: apiKey,
            baseURL: baseURL ?? CodexConfig.defaultBaseURL,
            organization: organization?.isEmpty == true ? nil : organization,
            source: .environment
        )
    }

    private func loadFromKeychain() -> Result<CodexConfig, CodexConfigError>? {
        do {
            guard let apiKey = try keychain.loadPassword(for: .codexAPIKey), !apiKey.isEmpty else {
                return nil
            }

            let environment = ProcessInfo.processInfo.environment
            let baseURL = environment["CODEX_BASE_URL"].flatMap(URL.init(string:)) ?? CodexConfig.defaultBaseURL
            let organization = environment["CODEX_ORG"]

            logger.debug("Loaded Codex credentials from Keychain.")
            let config = CodexConfig(
                apiKey: apiKey,
                baseURL: baseURL,
                organization: organization?.isEmpty == true ? nil : organization,
                source: .keychain
            )
            return .success(config)
        } catch let error as KeychainServiceError {
            return .failure(.keychainService(error))
        } catch {
            return .failure(.keychainService(.operationFailed(status: errSecInternalError)))
        }
    }

    private func loadFromSecretsFile() -> Result<CodexConfig, CodexConfigError>? {
        let debugDir = Bundle.main.bundleURL.deletingLastPathComponent()
        let directCandidates: [URL] = [
            debugDir.appendingPathComponent("AppComposition_AppComposition.bundle/CodexSecrets.plist"),
            debugDir.appendingPathComponent("ChatUI_ChatUI.bundle/CodexSecrets.plist"),
            debugDir.appendingPathComponent("AppAdapters_AppAdapters.bundle/CodexSecrets.plist")
        ]
        if let url = directCandidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return loadSecrets(from: url)
        }

        let bundles: [Bundle] = [
            CodexConfigLoader.secretsBundle,
            Bundle(url: debugDir.appendingPathComponent("AppComposition_AppComposition.bundle")),
            Bundle(url: debugDir.appendingPathComponent("ChatUI_ChatUI.bundle")),
            Bundle(url: debugDir.appendingPathComponent("AppAdapters_AppAdapters.bundle")),
            Bundle.main
        ].compactMap { $0 }

        if let url = bundles.compactMap({ $0.url(forResource: "CodexSecrets", withExtension: "plist") }).first {
            return loadSecrets(from: url)
        }

        return .failure(.secretsFileMissing)
    }

    private func loadSecrets(from url: URL) -> Result<CodexConfig, CodexConfigError> {
        do {
            let data = try Data(contentsOf: url)
            let payload = try PropertyListDecoder().decode(CodexSecretsPayload.self, from: data)
            guard !payload.apiKey.isEmpty else {
                return .failure(.missingAPIKey)
            }

            guard let baseURL = URL(string: payload.baseURL), !payload.baseURL.isEmpty else {
                return .failure(.invalidBaseURL)
            }

            let config = CodexConfig(
                apiKey: payload.apiKey,
                baseURL: baseURL,
                organization: payload.organization.isEmpty ? nil : payload.organization,
                source: .secretsFile
            )
            return .success(config)
        } catch {
            return .failure(.secretsDecodingFailed)
        }
    }
}

private struct CodexSecretsPayload: Decodable {
    let apiKey: String
    let baseURL: String
    let organization: String

    enum CodingKeys: String, CodingKey {
        case apiKey = "CODEX_API_KEY"
        case baseURL = "CODEX_BASE_URL"
        case organization = "CODEX_ORG"
    }
}

