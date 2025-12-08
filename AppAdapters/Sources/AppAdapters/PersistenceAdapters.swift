import Foundation
import CoreEngine
import os

/// In-memory conversation persistence adapter (placeholder until disk-backed version is wired).
///
/// Concurrency: guarded by `OSAllocatedUnfairLock`. Marked `@unchecked Sendable` because the lock wrapper
/// is not statically Sendable.
public final class InMemoryConversationPersistence: ConversationPersistenceDriver, @unchecked Sendable {
    public typealias ConversationType = Conversation

    private let storage = OSAllocatedUnfairLock<[UUID: Conversation]>(initialState: [:])

    public init() {}

    public func loadAllConversations() throws -> [Conversation] {
        storage.withLock { dict in Array(dict.values) }
    }

    public func saveConversation(_ conversation: Conversation) throws {
        let _: Void = storage.withLock { dict in dict[conversation.id] = conversation }
    }

    public func deleteConversation(_ conversation: Conversation) throws {
        let _: Void = storage.withLock { dict in dict.removeValue(forKey: conversation.id) }
    }
}

/// In-memory project persistence adapter (placeholder).
///
/// Concurrency: guarded by `OSAllocatedUnfairLock`; marked `@unchecked Sendable` because the lock wrapper
/// is not statically Sendable.
public final class InMemoryProjectPersistence<StoredProject: Sendable>: ProjectPersistenceDriver, @unchecked Sendable {
    private let storage: OSAllocatedUnfairLock<StoredProject>

    public init(initial: StoredProject) {
        self.storage = OSAllocatedUnfairLock(initialState: initial)
    }

    public func loadProjects() throws -> StoredProject {
        storage.withLock { $0 }
    }

    public func saveProjects(_ projects: StoredProject) throws {
        let _: Void = storage.withLock { $0 = projects }
    }
}

/// In-memory preferences adapter.
///
/// Concurrency: guarded by `OSAllocatedUnfairLock`; marked `@unchecked Sendable` because the lock wrapper
/// is not statically Sendable.
public final class InMemoryPreferencesDriver<Preferences: Sendable>: PreferencesDriver, @unchecked Sendable {
    private let storage = OSAllocatedUnfairLock<[String: Preferences]>(initialState: [:])
    private let defaultValue: Preferences

    public init(defaultValue: Preferences) {
        self.defaultValue = defaultValue
    }

    public func loadPreferences(for project: URL) throws -> Preferences {
        storage.withLock { map in map[project.path] ?? defaultValue }
    }

    public func savePreferences(_ preferences: Preferences, for project: URL) throws {
        let _: Void = storage.withLock { map in map[project.path] = preferences }
    }
}

/// In-memory context preferences adapter.
///
/// Concurrency: guarded by `OSAllocatedUnfairLock`; marked `@unchecked Sendable` because the lock wrapper
/// is not statically Sendable.
public final class InMemoryContextPreferencesDriver<ContextPreferences: Sendable>: ContextPreferencesDriver, @unchecked Sendable {
    private let storage = OSAllocatedUnfairLock<[String: ContextPreferences]>(initialState: [:])
    private let defaultValue: ContextPreferences

    public init(defaultValue: ContextPreferences) {
        self.defaultValue = defaultValue
    }

    public func loadContextPreferences(for project: URL) throws -> ContextPreferences {
        storage.withLock { map in map[project.path] ?? defaultValue }
    }

    public func saveContextPreferences(_ preferences: ContextPreferences, for project: URL) throws {
        let _: Void = storage.withLock { map in map[project.path] = preferences }
    }
}

