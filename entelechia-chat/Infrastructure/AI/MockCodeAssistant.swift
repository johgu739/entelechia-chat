// @EntelechiaHeaderStart
// Signifier: MockCodeAssistant
// Substance: Mock assistant
// Genus: Test double for AI client
// Differentia: Returns canned responses
// Form: Stubbed response logic
// Matter: Hardcoded messages
// Powers: Return predictable replies
// FinalCause: Enable testing without real model calls
// Relations: Substitutes for model client; serves conversation flows
// CausalityType: Instrumental
// @EntelechiaHeaderEnd

import Foundation

/// Protocol for code assistant services
protocol CodeAssistant {
    func send(messages: [Message], contextFiles: [LoadedFile]) async throws -> AsyncThrowingStream<StreamChunk, Error>
}

/// Core output types from the assistant
enum AssistantOutput {
    case text(String)
    case diff(file: String, patch: String)
    case fullFile(path: String, content: String)
}

/// Stream chunks from the assistant
enum StreamChunk {
    case token(String)
    case output(AssistantOutput)
    case done
}

/// Mock implementation of CodeAssistant for development
final class MockCodeAssistant: CodeAssistant {
    enum Mode {
        case textRandom
        case diffRandom
        case fullFileRandom
        case mixedRandom
    }
    
    var mode: Mode = .mixedRandom
    
    func send(messages: [Message], contextFiles: [LoadedFile]) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        // Copy mode value before entering detached task
        let currentMode = mode
        
        return AsyncThrowingStream { continuation in
            Task.detached {
                let tokens = ["Analyzing… ", "Computing… ", "Refactoring… "]
                
                for t in tokens.shuffled() {
                    try? await Task.sleep(for: .milliseconds(Int.random(in: 40...120)))
                    continuation.yield(.token(t))
                }
                
                let output: AssistantOutput
                
                switch currentMode {
                case .textRandom:
                    output = .text("Mock explanation from Codex.")
                    
                case .diffRandom:
                    output = .diff(
                        file: "Sources/App/File.swift",
                        patch: """
                        --- a/File.swift
                        +++ b/File.swift
                        @@ -1,5 +1,5 @@
                        func greet() {
                        -    print("Hello")
                        +    print("Hello, world!")
                        }
                        """
                    )
                    
                case .fullFileRandom:
                    output = .fullFile(
                        path: "Service/Mock.swift",
                        content: """
                        import Foundation
                        final class Mock {
                            func run() {}
                        }
                        """
                    )
                    
                case .mixedRandom:
                    output = [
                        AssistantOutput.text("Here is a synthesized mock answer."),
                        AssistantOutput.fullFile(
                            path: "Service/Mock.swift",
                            content: "final class Mock { func run() {} }"
                        ),
                        AssistantOutput.diff(
                            file: "Views/ChatView.swift",
                            patch: """
                            --- a/ChatView.swift
                            +++ b/ChatView.swift
                            @@ -12,7 +12,7 @@
                            VStack {
                            -    Text("Old")
                            +    Text("New")
                            }
                            """
                        )
                    ].randomElement()!
                }
                
                continuation.yield(.output(output))
                continuation.yield(.done)
                continuation.finish()
            }
        }
    }
}
