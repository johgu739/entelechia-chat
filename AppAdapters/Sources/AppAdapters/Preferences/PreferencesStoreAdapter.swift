import Foundation
import AppCoreEngine
import os
@preconcurrency import os.log

/// Adapter for PreferencesStore to conform to Engine's PreferencesDriver.
///
/// Concurrency: underlying store uses `OSAllocatedUnfairLock`; file IO is synchronous. Marked
/// `@unchecked Sendable` because the lock-backed store is not statically Sendable.
public final class PreferencesStoreAdapter<Preferences: Codable & Sendable>: PreferencesDriver, @unchecked Sendable {
    private let store: PreferencesStoreShim<Preferences>

    public init(strict: Bool = false) {
        self.store = PreferencesStoreShim(strict: strict)
    }

    public func loadPreferences(for project: URL) throws -> Preferences {
        try store.load(for: project, strict: false)
    }

    public func savePreferences(_ preferences: Preferences, for project: URL) throws {
        try store.save(preferences, for: project)
    }
}

/// Adapter for ContextPreferencesStore to conform to Engine's ContextPreferencesDriver.
///
/// Concurrency: underlying store uses `OSAllocatedUnfairLock`; file IO is synchronous. Marked
/// `@unchecked Sendable` because the lock-backed store is not statically Sendable.
public final class ContextPreferencesStoreAdapter<ContextPreferences: Codable & Sendable>: ContextPreferencesDriver, @unchecked Sendable {
    private let store: ContextPreferencesStoreShim<ContextPreferences>

    public init(strict: Bool = false) {
        self.store = ContextPreferencesStoreShim(strict: strict)
    }

    public func loadContextPreferences(for project: URL) throws -> ContextPreferences {
        try store.load(for: project, strict: false)
    }

    public func saveContextPreferences(_ preferences: ContextPreferences, for project: URL) throws {
        try store.save(preferences, for: project)
    }
}

// MARK: - Shims (thin copies of original stores to avoid package cycles)

public final class PreferencesStoreShim<T: Codable & Sendable>: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock()
    public static var empty: T {
        if T.self == WorkspacePreferences.self, let prefs = WorkspacePreferences.empty as? T {
            return prefs
        }
        if let data = "{}".data(using: .utf8), let value = try? JSONDecoder().decode(T.self, from: data) {
            return value
        }
        fatalError("Provide a concrete empty value for \(T.self)")
    }

    public init(strict: Bool = false) {}

    public func load(for project: URL, strict: Bool) throws -> T {
        try lock.withLock {
            let url = preferencesURL(for: project)
            let fm = FileManager.default
            guard fm.fileExists(atPath: url.path) else {
                return Self.empty
            }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        }
    }

    public func save(_ preferences: T, for project: URL) throws {
        try lock.withLock {
            let url = preferencesURL(for: project)
            let fm = FileManager.default
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(preferences)
            try data.write(to: url, options: .atomic)
        }
    }

    private func preferencesURL(for project: URL) -> URL {
        project.appendingPathComponent(".entelechia/preferences.json")
    }
}

public final class ContextPreferencesStoreShim<T: Codable & Sendable>: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock()
    public static var empty: T {
        if T.self == WorkspaceContextPreferencesState.self, let prefs = WorkspaceContextPreferencesState.empty as? T {
            return prefs
        }
        if let data = "{}".data(using: .utf8), let value = try? JSONDecoder().decode(T.self, from: data) {
            return value
        }
        fatalError("Provide a concrete empty value for \(T.self)")
    }

    public init(strict: Bool = false) {}

    public func load(for project: URL, strict: Bool) throws -> T {
        try lock.withLock {
            let url = preferencesURL(for: project)
            let fm = FileManager.default
            guard fm.fileExists(atPath: url.path) else {
                return Self.empty
            }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        }
    }

    public func save(_ preferences: T, for project: URL) throws {
        try lock.withLock {
            let url = preferencesURL(for: project)
            let fm = FileManager.default
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(preferences)
            try data.write(to: url, options: .atomic)
        }
    }

    private func preferencesURL(for project: URL) -> URL {
        project.appendingPathComponent(".entelechia/context-preferences.json")
    }
}

