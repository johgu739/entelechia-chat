import Foundation
import CoreEngine

/// In-memory conversation persistence adapter (placeholder until disk-backed version is wired).
public final class InMemoryConversationPersistence: ConversationPersistenceDriver, @unchecked Sendable {
    public typealias ConversationType = Conversation

    private var storage: [UUID: Conversation] = [:]

    public init() {}

    public func loadAllConversations() throws -> [Conversation] {
        Array(storage.values)
    }

    public func saveConversation(_ conversation: Conversation) throws {
        storage[conversation.id] = conversation
    }

    public func deleteConversation(_ conversation: Conversation) throws {
        storage.removeValue(forKey: conversation.id)
    }
}

/// In-memory project persistence adapter (placeholder).
public final class InMemoryProjectPersistence<StoredProject: Sendable>: ProjectPersistenceDriver, @unchecked Sendable {
    private var value: StoredProject

    public init(initial: StoredProject) {
        self.value = initial
    }

    public func loadProjects() throws -> StoredProject {
        value
    }

    public func saveProjects(_ projects: StoredProject) throws {
        value = projects
    }
}

/// In-memory preferences adapter.
public final class InMemoryPreferencesDriver<Preferences: Sendable>: PreferencesDriver, @unchecked Sendable {
    private var map: [String: Preferences] = [:]

    public init() {}

    public func loadPreferences(for project: URL) throws -> Preferences {
        map[project.path] ?? {
            fatalError("Preferences not set for \(project.path)")
        }()
    }

    public func savePreferences(_ preferences: Preferences, for project: URL) throws {
        map[project.path] = preferences
    }
}

/// In-memory context preferences adapter.
public final class InMemoryContextPreferencesDriver<ContextPreferences: Sendable>: ContextPreferencesDriver, @unchecked Sendable {
    private var map: [String: ContextPreferences] = [:]

    public init() {}

    public func loadContextPreferences(for project: URL) throws -> ContextPreferences {
        map[project.path] ?? {
            fatalError("Context preferences not set for \(project.path)")
        }()
    }

    public func saveContextPreferences(_ preferences: ContextPreferences, for project: URL) throws {
        map[project.path] = preferences
    }
}

