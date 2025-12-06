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
import os.log

/// Service for conversation business logic
@MainActor
final class ConversationService {
    private let assistant: CodeAssistant
    private let conversationStore: ConversationStore
    private let fileContentService: FileContentService
    private let contextBuilder: ContextBuilder
    private let logger = Logger.persistence
    
    func applyPreferences(_ preferences: ContextPreferences, to files: [LoadedFile]) -> [LoadedFile] {
        // If no explicit includes, treat excluded paths as opt-out; otherwise opt-in list wins
        let includes = preferences.includedPaths
        let excludes = preferences.excludedPaths
        
        return files.map { file in
            let path = file.url.path
            var updated = file
            
            if excludes.contains(path) {
                updated.isIncludedInContext = false
            } else if !includes.isEmpty {
                updated.isIncludedInContext = includes.contains(path)
            }
            
            return updated
        }
    }
    
    init(
        assistant: CodeAssistant,
        conversationStore: ConversationStore,
        fileContentService: FileContentService,
        contextBuilder: ContextBuilder? = nil
    ) {
        self.assistant = assistant
        self.conversationStore = conversationStore
        self.fileContentService = fileContentService
        self.contextBuilder = contextBuilder ?? ContextBuilder()
    }
    
    /// Send a message in a conversation with context files
    /// Returns updated conversation (struct - value type)
    func sendMessage(
        _ text: String,
        in conversation: Conversation,
        contextNode: FileNode?,
        preferences: ContextPreferences? = nil,
        onStreamEvent: ((StreamChunk) -> Void)? = nil
    ) async throws -> (Conversation, ContextBuildResult) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConversationServiceError.emptyMessage
        }
        
        // Load context files if node is provided
        var contextFiles: [LoadedFile]
        if let node = contextNode {
            do {
                contextFiles = try await fileContentService.collectFiles(from: node)
            } catch {
                logger.error("Failed to load context files: \(error.localizedDescription, privacy: .public)")
                contextFiles = []
            }
        } else {
            contextFiles = []
        }
        
        // Apply persisted preferences if available
        if let preferences {
            contextFiles = applyPreferences(preferences, to: contextFiles)
        }
        
        // Create user message and update conversation (struct - create new instance)
        let userMessage = Message(role: .user, text: text)
        var updatedConversation = conversation
        updatedConversation.messages.append(userMessage)
        updatedConversation.updatedAt = Date()
        
        // Auto-update title if first user message
        if updatedConversation.messages.filter({ $0.role == .user }).count == 1 {
            updatedConversation.title = updatedConversation.summaryTitle
        }
        
        // Enforce budgeting before hitting Codex
        let contextResult = contextBuilder.build(from: contextFiles)
        
        // Send to assistant and stream response
        var streamingText = ""
        var finalMessage: Message?
        
        do {
            let stream = try await assistant.send(messages: updatedConversation.messages, contextFiles: contextResult.attachments)
            
            for try await chunk in stream {
                onStreamEvent?(chunk)
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
            
            // Append assistant message (struct - create new instance)
            if let message = finalMessage {
                updatedConversation.messages.append(message)
            } else if !streamingText.isEmpty {
                updatedConversation.messages.append(Message(role: .assistant, text: streamingText))
            }
            updatedConversation.updatedAt = Date()
        } catch {
            // Append error message (struct - create new instance)
            let errorMessage = Message(
                role: .assistant,
                text: "Sorry, I encountered an error: \(error.localizedDescription)"
            )
            updatedConversation.messages.append(errorMessage)
            updatedConversation.updatedAt = Date()
        }
        
        // Persist the conversation
        try conversationStore.save(updatedConversation)
        
        return (updatedConversation, contextResult)
    }
    
    /// Get conversation for a URL (pure accessor - never mutates)
    /// This is safe to call from view rendering contexts
    func conversation(for url: URL, urlToConversationId: [URL: UUID]) -> Conversation? {
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
            return existing
        }

        // Not found - return nil (caller must use ensureConversation to create)
        return nil
    }
    
    /// Ensure a conversation exists for a URL (side-effecting - must be called from async context)
    /// This creates and persists if needed, but never during view rendering
    /// Returns updated conversation and updated URL-to-ID mapping (avoids actor-isolated inout)
    @MainActor
    func ensureConversation(for url: URL, urlToConversationId: [URL: UUID]) async throws -> (Conversation, [URL: UUID]) {
        // First check if it already exists (pure read)
        if let existing = conversation(for: url, urlToConversationId: urlToConversationId) {
            var updatedMapping = urlToConversationId
            updatedMapping[url] = existing.id
            return (existing, updatedMapping)
        }
        
        // Create and persist a new conversation for this file
        let new = Conversation(contextFilePaths: [url.path])
        try conversationStore.save(new)
        var updatedMapping = urlToConversationId
        updatedMapping[url] = new.id
        return (new, updatedMapping)
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
