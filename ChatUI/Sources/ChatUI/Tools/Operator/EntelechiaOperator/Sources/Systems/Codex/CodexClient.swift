// @EntelechiaHeaderStart
// Signifier: OperatorCodexClient
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

protocol OperatorCodexClient {
    func send(message: String) async throws -> AsyncStream<String>
}

final class StubCodexClient: OperatorCodexClient {
    func send(message: String) async throws -> AsyncStream<String> {
        return AsyncStream { continuation in
            continuation.yield("Codex response placeholder for: \(message)")
            continuation.finish()
        }
    }
}