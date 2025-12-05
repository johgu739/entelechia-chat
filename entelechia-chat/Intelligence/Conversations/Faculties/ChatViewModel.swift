// @EntelechiaHeaderStart
// Signifier: ChatViewModel
// Substance: Chat UI faculty
// Genus: Application faculty
// Differentia: Mediates conversation domain to UI
// Form: Observable chat state and actions
// Matter: Messages; loading flags; bindings
// Powers: Bind messages to UI; send via service
// FinalCause: Drive chat UI interactions
// Relations: Serves ChatView; depends on ConversationService/Store
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation
import SwiftUI
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var streamingText: String = ""
    
    private let assistant: CodeAssistant
    
    init(assistant: CodeAssistant) {
        self.assistant = assistant
    }
    
    func send(_ text: String, contextFiles: [LoadedFile] = []) {
        let userMessage = Message(role: .user, text: text)
        messages.append(userMessage)
        streamingText = ""
        
        Task {
            do {
                let stream = try await assistant.send(messages: messages, contextFiles: contextFiles)
                
                for await chunk in stream {
                    switch chunk {
                    case .token(let t):
                        streamingText += t
                        
                    case .output(let output):
                        switch output {
                        case .text(let s):
                            messages.append(Message(role: .assistant, text: s))
                            
                        case .diff(_, let patch):
                            messages.append(Message(role: .assistant, text: "DIFF:\n\(patch)"))
                            
                        case .fullFile(_, let content):
                            messages.append(Message(role: .assistant, text: "FULL FILE:\n\(content)"))
                        }
                        
                    case .done:
                        streamingText = ""
                    }
                }
            } catch {
                let errorMessage = Message(
                    role: .assistant,
                    text: "Sorry, I encountered an error: \(error.localizedDescription)"
                )
                messages.append(errorMessage)
                streamingText = ""
            }
        }
    }
}
