import Foundation
import CoreEngine
import os

/// Minimal project persistence adapter (placeholder) that keeps data in memory.
/// Replace with a real disk-backed adapter using the app's ProjectStore when migrated.
public final class InMemoryProjectStoreAdapter: ProjectPersistenceDriver, Sendable {
    public struct ProjectRecord: Codable, Sendable, Equatable {
        public var name: String
        public var path: String
        public var bookmarkData: Data?
    }

    public struct ProjectData: Codable, Sendable {
        public var lastOpened: ProjectRecord?
        public var recent: [ProjectRecord]
        public var lastSelections: [String: String]

        public init(lastOpened: ProjectRecord? = nil, recent: [ProjectRecord] = [], lastSelections: [String: String] = [:]) {
            self.lastOpened = lastOpened
            self.recent = recent
            self.lastSelections = lastSelections
        }
    }

    public typealias StoredProject = ProjectData

    private let storage: OSAllocatedUnfairLock<ProjectData>

    public init(seed: ProjectData = ProjectData()) {
        self.storage = OSAllocatedUnfairLock(initialState: seed)
    }

    public func loadProjects() throws -> ProjectData {
        storage.withLock { $0 }
    }

    public func saveProjects(_ projects: ProjectData) throws {
        storage.withLock { $0 = projects }
    }
}

