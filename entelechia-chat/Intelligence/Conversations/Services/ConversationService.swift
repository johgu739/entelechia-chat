// @EntelechiaHeaderStart
// Signifier: ConversationService
// Substance: Conversation faculty
// Genus: Domain faculty
// Differentia: Orchestrates messaging and streaming
// Form: Rules for sending, streaming, persisting messages
// Matter: Conversation aggregates; messages; context files
// Powers: Validate input; stream model output; append/persist messages
// FinalCause: Conduct meaningful dialogues tied to files
// Relations: Governs persistence and model calls; serves UI VMs
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation

/// Service for conversation business logic
@MainActor
final class ConversationService {
    private let assistant: CodeAssistant
    private let conversationStore: ConversationStore
    private let fileContentService: FileContentService
    
    init(
        assistant: CodeAssistant,
        conversationStore: ConversationStore,
        fileContentService: FileContentService
    ) {
        self.assistant = assistant
        self.conversationStore = conversationStore
        self.fileContentService = fileContentService
    }
    
    /// Send a message in a conversation with context files
    func sendMessage(
        _ text: String,
        in conversation: Conversation,
        contextNode: FileNode?
    ) async throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConversationServiceError.emptyMessage
        }
        
        // Load context files if node is provided
        let contextFiles: [LoadedFile]
        if let node = contextNode {
            do {
                contextFiles = try await fileContentService.collectFiles(from: node)
            } catch {
                // Log error but continue without context files
                print("Warning: Failed to load context files: \(error.localizedDescription)")
                contextFiles = []
            }
        } else {
            contextFiles = []
        }
        
        // Create user message
        let userMessage = Message(role: .user, text: text)
        conversation.messages.append(userMessage)
        conversation.updatedAt = Date()
        
        // Auto-update title if first user message
        if conversation.messages.filter({ $0.role == .user }).count == 1 {
            conversation.title = conversation.summaryTitle
        }
        
        // Get included files
        let includedFiles = contextFiles.filter { $0.isIncludedInContext }
        
        // Send to assistant and stream response
        var streamingText = ""
        var finalMessage: Message?
        
        do {
            let stream = try await assistant.send(messages: conversation.messages, contextFiles: includedFiles)
            
            for await chunk in stream {
                switch chunk {
                case .token(let t):
                    streamingText += t
                    
                case .output(let output):
                    switch output {
                    case .text(let s):
                        finalMessage = Message(role: .assistant, text: s)
                        
                    case .diff(_, let patch):
                        finalMessage = Message(role: .assistant, text: "DIFF:\n\(patch)")
                        
                    case .fullFile(_, let content):
                        finalMessage = Message(role: .assistant, text: "FULL FILE:\n\(content)")
                    }
                    
                case .done:
                    break
                }
            }
            
            if let message = finalMessage {
                conversation.messages.append(message)
            } else if !streamingText.isEmpty {
                conversation.messages.append(Message(role: .assistant, text: streamingText))
            }
        } catch {
            let errorMessage = Message(
                role: .assistant,
                text: "Sorry, I encountered an error: \(error.localizedDescription)"
            )
            conversation.messages.append(errorMessage)
        }
        
        conversation.updatedAt = Date()
        
        // Persist the conversation - if this fails, crash with clear error
        do {
            try conversationStore.save(conversation)
        } catch {
            fatalError("❌ Failed to save conversation \(conversation.id): \(error.localizedDescription). This is a fatal error - database must be valid.")
        }
    }
    
    /// Get or create a conversation for a URL
    func conversation(for url: URL, urlToConversationId: inout [URL: UUID]) -> Conversation {
        // Check map first
        if let conversationId = urlToConversationId[url],
           let existing = conversationStore.conversations.first(where: { $0.id == conversationId }) {
            return existing
        }

        // Try to find an existing conversation that references this file path
        if let existing = conversationStore.conversations
            .filter({ $0.contextFilePaths.contains(url.path) })
            .sorted(by: { $0.updatedAt > $1.updatedAt })
            .first {
            urlToConversationId[url] = existing.id
            return existing
        }

        // Create and persist a new conversation for this file
        let new = Conversation(contextFilePaths: [url.path])
        do {
            try conversationStore.save(new)
        } catch {
            fatalError("❌ Failed to save new conversation: \(error.localizedDescription). This is a fatal error - conversation store must be writable.")
        }
        urlToConversationId[url] = new.id
        return new
    }
}

enum ConversationServiceError: LocalizedError {
    case emptyMessage
    case conversationNotFound
    
    var errorDescription: String? {
        switch self {
        case .emptyMessage:
            return "Message cannot be empty"
        case .conversationNotFound:
            return "Conversation not found"
        }
    }
}