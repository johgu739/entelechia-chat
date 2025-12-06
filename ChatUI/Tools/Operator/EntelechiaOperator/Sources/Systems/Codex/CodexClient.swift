// @EntelechiaHeaderStart
// Signifier: CodexClient
// Substance: Codex client
// Genus: API client
// Differentia: Calls Codex backend
// Form: API call logic
// Matter: Requests/responses for code/chat operations
// Powers: Send requests; receive results
// FinalCause: Connect operator to Codex intelligence
// Relations: Serves operator app; depends on network/daemon
// CausalityType: Instrumental
// @EntelechiaHeaderEnd

import Foundation

protocol CodexClient {
    func send(message: String) async throws -> AsyncStream<String>
}

final class StubCodexClient: CodexClient {
    func send(message: String) async throws -> AsyncStream<String> {
        return AsyncStream { continuation in
            continuation.yield("Codex response placeholder for: \(message)")
            continuation.finish()
        }
    }
}