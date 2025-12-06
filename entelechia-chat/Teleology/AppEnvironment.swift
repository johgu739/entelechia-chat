// @EntelechiaHeaderStart
// Signifier: AppEnvironment
// Substance: Application environment object
// Genus: Teleological support faculty
// Differentia: Holds assistant mode and Codex configuration
// Form: ObservableObject tracking configuration status
// Matter: Assistant mode; configuration loader; status metadata
// Powers: Validate Codex configuration; expose fallback state
// FinalCause: Guard teleology by ensuring the proper assistant is composed
// Relations: Serves EntelechiaChatApp and future dependency injection
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Combine
import Foundation
import os.log

@MainActor
final class AppEnvironment: ObservableObject {
    enum AssistantMode: Equatable {
        case mock
        case codex(CodexConfig)
    }

    enum ConfigurationStatus: Equatable {
        case ready
        case mockFallback(reason: String)
    }

    @Published private(set) var assistantMode: AssistantMode
    @Published private(set) var configurationStatus: ConfigurationStatus
    let assistant: CodeAssistant

    private let loader: CodexConfigLoading
    private let container: DependencyContainer?
    private let logger = Logger(subsystem: "chat.entelechia", category: "AppEnvironment")

    init(loader: CodexConfigLoading? = nil) {
        let loader = loader ?? CodexConfigLoader()
        self.loader = loader
        self.container = nil

        switch loader.loadConfig() {
        case .success(let config):
            assistantMode = .codex(config)
            configurationStatus = .ready
            assistant = CodexAssistant(config: config)
            logger.info("Codex configuration loaded from \(config.source.rawValue).")

        case .failure(let error):
            assistantMode = .mock
            configurationStatus = .mockFallback(reason: error.localizedDescription)
            assistant = MockCodeAssistant()
            logger.warning("Codex unavailable, falling back to MockCodeAssistant. Reason: \(error.localizedDescription)")
        }
    }

    /// Dependency-injected initializer pulling all components from the container.
    /// No creation logic; uses container-provided services.
    init(container: DependencyContainer) {
        self.container = container
        self.loader = container.codexConfigLoader

        switch loader.loadConfig() {
        case .success(let config):
            assistantMode = .codex(config)
            configurationStatus = .ready
            assistant = container.codexAssistant
            logger.info("Codex configuration loaded from \(config.source.rawValue).")

        case .failure(let error):
            assistantMode = .mock
            configurationStatus = .mockFallback(reason: error.localizedDescription)
            assistant = container.codexAssistant
            logger.warning("Codex unavailable, falling back to container assistant. Reason: \(error.localizedDescription)")
        }
    }

    /// Testing convenience to bypass any Keychain/ProcessInfo access and avoid UI isolation.
    /// This initializer is intentionally pure: no loader calls, no Keychain, no URLSession.
    init(configurationStatus: ConfigurationStatus, assistant: CodeAssistant? = nil, loader: CodexConfigLoading? = nil) {
        self.loader = loader ?? MockFailingConfigLoader()
        self.configurationStatus = configurationStatus
        self.assistantMode = .mock
        self.assistant = assistant ?? NoopCodeAssistant()
        self.container = nil
        if case .mockFallback(let reason) = configurationStatus {
            logger.warning("AppEnvironment forced mock fallback for testing. Reason: \(reason, privacy: .public)")
        }
    }

    var usesCodex: Bool {
        if case .codex = assistantMode {
            return true
        }
        return false
    }
}

// Minimal failing loader for pure test initialization.
struct MockFailingConfigLoader: CodexConfigLoading {
    func loadConfig() -> Result<CodexConfig, CodexConfigError> {
        .failure(.missingCredentials)
    }
}

struct NoopCodeAssistant: CodeAssistant {
    func send(messages: [Message], contextFiles: [LoadedFile]) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.done)
            continuation.finish()
        }
    }
}
