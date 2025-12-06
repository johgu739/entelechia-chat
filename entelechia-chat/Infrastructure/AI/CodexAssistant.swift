// @EntelechiaHeaderStart
// Signifier: CodexAssistant
// Substance: Codex-backed assistant
// Genus: AI assistant implementation
// Differentia: Streams Codex API events into UI-friendly chunks
// Form: Adapter over CodexAPIClient yielding StreamChunk values
// Matter: CodexConfig; CodexAPIClient; StreamChunk conversion logic
// Powers: Send chat prompts; stream tokens/diffs/files; report completion
// FinalCause: Provide real Codex responses to conversation faculties
// Relations: Implements CodeAssistant; depends on CodexAPIClient/Config
// CausalityType: Instrumental
// @EntelechiaHeaderEnd

import Foundation

final class CodexAssistant: CodeAssistant {
    private let client: CodexAPIClient

    init(config: CodexConfig, session: URLSession = .shared, model: String = "gpt-4o-mini") {
        self.client = CodexAPIClient(config: config, session: session, model: model)
    }

    func send(messages: [Message], contextFiles: [LoadedFile]) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        let codexStream = client.streamChatCompletions(messages: messages, attachments: contextFiles)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await event in codexStream {
                        switch event {
                        case .text(let text):
                            continuation.yield(StreamChunk.token(text))
                        case .diff(let file, let patch):
                            continuation.yield(StreamChunk.output(.diff(file: file, patch: patch)))
                        case .file(let path, let content):
                            continuation.yield(StreamChunk.output(.fullFile(path: path, content: content)))
                        }
                    }
                    continuation.yield(StreamChunk.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
