// @EntelechiaHeaderStart
// Signifier: ConversationStore
// Substance: Conversation persistence instrument
// Genus: Domain store
// Differentia: Maintains index and per-conversation files
// Form: Index management and file read/write logic
// Matter: Conversations; index JSON
// Powers: Load all; import orphans; save; delete
// FinalCause: Durably persist conversations
// Relations: Serves ConversationService and UI
// CausalityType: Instrumental
// @EntelechiaHeaderEnd

import Foundation
import SwiftUI
import Combine

/// High-level conversation persistence API
@MainActor
final class ConversationStore: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var selectedConversation: Conversation?
    
    private let fileStore = FileStore.shared
    private var loadedConversationIds: Set<UUID> = []
    
    init() {
        // Ensure directory exists - if this fails, app should crash
        do {
            try fileStore.ensureDirectoryExists()
        } catch {
            fatalError("❌ Failed to create conversation storage directory: \(error.localizedDescription)")
        }
    }
    
    /// Load all conversations from disk
    /// Throws if index file exists but is corrupted
    func loadAll() throws {
        // Load index first
        let index: ConversationIndex?
        do {
            index = try fileStore.load(ConversationIndex.self, from: fileStore.resolveIndexPath())
        } catch {
            // Index file exists but is corrupted - FAIL LOUDLY
            fatalError("❌ Conversation index file exists but is corrupted at \(fileStore.resolveIndexPath().path). Error: \(error.localizedDescription). Delete the file manually if you want to start fresh.")
        }
        
        guard let index = index else {
            // No index exists - try to import orphan files
            _ = try importOrphanConversations()
            return
        }
        
        var loaded: [Conversation] = []
        var validEntries: [ConversationIndexEntry] = []
        
        // Load each conversation file referenced in index
        for entry in index.conversations {
            let conversationURL = fileStore.resolveConversationsDirectory()
                .appendingPathComponent("\(entry.id.uuidString).json")
            
            do {
                if let conversation = try fileStore.load(Conversation.self, from: conversationURL) {
                    loaded.append(conversation)
                    validEntries.append(entry)
                    loadedConversationIds.insert(conversation.id)
                } else {
                    // File doesn't exist - index is stale, skip this entry
                    print("⚠️ Index references missing conversation file: \(entry.id)")
                }
            } catch {
                // File exists but is corrupted - FAIL LOUDLY
                fatalError("❌ Conversation file exists but is corrupted at \(conversationURL.path). Error: \(error.localizedDescription). Delete the file manually if you want to start fresh.")
            }
        }
        
        // Import any orphan files not in index
        let orphanConversations = try importOrphanConversations()
        for orphan in orphanConversations {
            if !loadedConversationIds.contains(orphan.id) {
                loaded.append(orphan)
                validEntries.append(ConversationIndexEntry(
                    id: orphan.id,
                    title: orphan.title,
                    updatedAt: orphan.updatedAt,
                    path: "\(orphan.id.uuidString).json"
                ))
            }
        }
        
        // Sort by updatedAt descending
        conversations = loaded.sorted { $0.updatedAt > $1.updatedAt }
        
        // Update index with valid entries
        let updatedIndex = ConversationIndex(conversations: validEntries)
        // If save fails, throw - no silent errors
        try fileStore.save(updatedIndex, to: fileStore.resolveIndexPath())
    }
    
    /// Import orphan conversation files not in index
    /// Throws if any orphan file is corrupted
    private func importOrphanConversations() throws -> [Conversation] {
        let conversationFiles = try fileStore.listConversationFiles()
        var imported: [Conversation] = []
        
        for fileURL in conversationFiles {
            // Extract UUID from filename
            let filename = fileURL.deletingPathExtension().lastPathComponent
            guard UUID(uuidString: filename) != nil else { continue }
            
            // Skip if already loaded
            if let uuid = UUID(uuidString: filename),
               loadedConversationIds.contains(uuid) {
                continue
            }
            
            // If file exists but decode fails, it's corrupted - throw
            if let conversation = try fileStore.load(Conversation.self, from: fileURL) {
                imported.append(conversation)
                loadedConversationIds.insert(conversation.id)
            }
            // If nil, file doesn't exist - skip (this is OK)
        }
        
        return imported
    }
    
    /// Save a conversation to disk
    /// Throws if save fails - no silent errors
    /// CRITICAL: Mutations to @Published properties must happen asynchronously
    /// This function is synchronous for file I/O but defers @Published mutations
    func save(_ conversation: Conversation) throws {
        let conversationURL = fileStore.resolveConversationsDirectory()
            .appendingPathComponent("\(conversation.id.uuidString).json")
        
        try fileStore.save(conversation, to: conversationURL)
        
        // Update in-memory array asynchronously to avoid publishing during view updates
        // Use Task to ensure this happens outside the current run loop
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if let index = self.conversations.firstIndex(where: { $0.id == conversation.id }) {
                self.conversations[index] = conversation
            } else {
                self.conversations.append(conversation)
                self.conversations.sort { $0.updatedAt > $1.updatedAt }
            }
            
            // Sync index asynchronously
            try? self.syncIndex()
        }
    }
    
    /// Create a new conversation
    /// Throws if save fails
    func createConversation() throws -> Conversation {
        let conversation = Conversation()
        try save(conversation)
        return conversation
    }
    
    /// Delete a conversation
    /// Throws if delete fails - no silent errors
    /// CRITICAL: Mutations to @Published properties must happen asynchronously
    func delete(_ conversation: Conversation) throws {
        let conversationURL = fileStore.resolveConversationsDirectory()
            .appendingPathComponent("\(conversation.id.uuidString).json")
        
        try fileStore.delete(at: conversationURL)
        
        // Update in-memory array asynchronously to avoid publishing during view updates
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.conversations.removeAll { $0.id == conversation.id }
            
            if self.selectedConversation?.id == conversation.id {
                self.selectedConversation = nil
            }
            
            // Sync index asynchronously
            try? self.syncIndex()
        }
    }
    
    /// Rename a conversation
    /// Throws if save fails
    func rename(_ conversation: Conversation, to newTitle: String) throws {
        var updated = conversation
        updated.title = newTitle
        updated.updatedAt = Date()
        try save(updated)
    }
    
    /// Append a message to a conversation
    /// Throws if save fails
    /// CRITICAL: Mutations to @Published properties must happen asynchronously
    func appendMessage(_ message: Message, to conversation: Conversation) throws {
        var updated = conversation
        updated.messages.append(message)
        updated.updatedAt = Date()
        
        // Auto-update title if first user message
        if message.role == .user && updated.messages.filter({ $0.role == .user }).count == 1 {
            updated.title = updated.summaryTitle
        }
        
        try save(updated)
        
        // Update selected conversation asynchronously if it's the same
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if self.selectedConversation?.id == conversation.id {
                self.selectedConversation = updated
            }
        }
    }
    
    /// Load conversation messages if not already loaded
    /// Throws if file exists but is corrupted
    func loadConversationIfNeeded(_ conversation: Conversation) throws -> Conversation {
        // Check if already fully loaded (has messages)
        if let existing = conversations.first(where: { $0.id == conversation.id }),
           !existing.messages.isEmpty {
            return existing
        }
        
        // Load from disk
        let conversationURL = fileStore.resolveConversationsDirectory()
            .appendingPathComponent("\(conversation.id.uuidString).json")
        
        // If file exists but decode fails, throw - no silent errors
        if let loaded = try fileStore.load(Conversation.self, from: conversationURL) {
            // Update in-memory array
            if let index = conversations.firstIndex(where: { $0.id == loaded.id }) {
                conversations[index] = loaded
            }
            return loaded
        }
        
        return conversation
    }
    
    /// Sync index file with current conversations
    /// Throws if save fails - no silent errors
    private func syncIndex() throws {
        let entries = conversations.map { conversation in
            ConversationIndexEntry(
                id: conversation.id,
                title: conversation.title,
                updatedAt: conversation.updatedAt,
                path: "\(conversation.id.uuidString).json"
            )
        }
        
        let index = ConversationIndex(conversations: entries)
        
        // If save fails, throw - no silent errors
        try fileStore.save(index, to: fileStore.resolveIndexPath())
    }
}
