import Foundation

/// Conversation persistence abstraction.
public protocol ConversationPersistenceDriver: Sendable {
    associatedtype ConversationType: Sendable
    func loadAllConversations() throws -> [ConversationType]
    func saveConversation(_ conversation: ConversationType) throws
    func deleteConversation(_ conversation: ConversationType) throws
}

/// Project metadata persistence abstraction (recents, last opened, selections).
public protocol ProjectPersistenceDriver: Sendable {
    associatedtype StoredProject: Sendable
    func loadProjects() throws -> StoredProject
    func saveProjects(_ projects: StoredProject) throws
}

/// User preferences per project (non-context).
public protocol PreferencesDriver: Sendable {
    associatedtype Preferences: Sendable
    func loadPreferences(for project: URL) throws -> Preferences
    func savePreferences(_ preferences: Preferences, for project: URL) throws
}

/// Context preferences (included/excluded paths, last focused).
public protocol ContextPreferencesDriver: Sendable {
    associatedtype ContextPreferences: Sendable
    func loadContextPreferences(for project: URL) throws -> ContextPreferences
    func saveContextPreferences(_ preferences: ContextPreferences, for project: URL) throws
}

