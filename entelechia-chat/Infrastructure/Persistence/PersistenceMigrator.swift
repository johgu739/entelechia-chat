// @EntelechiaHeaderStart
// Signifier: PersistenceMigrator
// Substance: Persistence migration orchestrator
// Genus: Infrastructure migration utility
// Differentia: Moves legacy Codex data into canonical layout with backups
// Form: Sequenced migration steps with logging and idempotency
// Matter: Legacy project store, conversation index, project folders
// Powers: Detect, back up, relocate, and seed persistence artifacts
// FinalCause: Ensure material causes align with Codex readiness requirements
// Relations: Serves Teleology before stores are instantiated
// CausalityType: Efficient
// @EntelechiaHeaderEnd

import Foundation
import os.log

struct PersistenceMigrator {
    private let fileStore: FileStore
    private let fileManager: FileManager
    private let logger = Logger.persistence
    private let contextStore: ContextPreferencesStore
    private let preferencesStore: PreferencesStore

    init(
        fileStore: FileStore = .shared,
        fileManager: FileManager = .default,
        contextStore: ContextPreferencesStore = ContextPreferencesStore(),
        preferencesStore: PreferencesStore = PreferencesStore()
    ) {
        self.fileStore = fileStore
        self.fileManager = fileManager
        self.contextStore = contextStore
        self.preferencesStore = preferencesStore
    }

    func runMigrations(strict: Bool = false) throws {
        try moveConversationIndexIfNeeded(strict: strict)
        try migrateLegacyProjectStoreIfNeeded(strict: strict)
    }

    // Pure helper for tests to migrate the conversation index without touching other app state.
    static func performConversationIndexMigration(
        fileManager: FileManager,
        legacyURL: URL,
        canonicalURL: URL,
        createBackup: Bool = true
    ) throws {
        guard fileManager.fileExists(atPath: legacyURL.path) else { return }
        guard !fileManager.fileExists(atPath: canonicalURL.path) else { return }

        if createBackup {
            let backupURL = legacyURL.appendingPathExtension("backup-\(timestamp())")
            if !fileManager.fileExists(atPath: backupURL.path) {
                try? fileManager.copyItem(at: legacyURL, to: backupURL)
            }
        }

        try fileManager.createDirectory(at: canonicalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.copyItem(at: legacyURL, to: canonicalURL)
        try fileManager.removeItem(at: legacyURL)
    }

#if DEBUG
    /// Test-only helper to migrate the conversation index without touching other stores.
    static func testMoveConversationIndex(
        fileStore: FileStore,
        fileManager: FileManager
    ) throws {
        let legacyURL = fileStore.resolveLegacyIndexPath()
        let canonicalURL = fileStore.resolveIndexPath()
        try performConversationIndexMigration(
            fileManager: fileManager,
            legacyURL: legacyURL,
            canonicalURL: canonicalURL,
            createBackup: false
        )
    }
#endif

    // MARK: - Conversation index migration

    private func moveConversationIndexIfNeeded(strict: Bool) throws {
        let legacyURL = fileStore.resolveLegacyIndexPath()
        let canonicalURL = fileStore.resolveIndexPath()

        guard fileManager.fileExists(atPath: legacyURL.path) else { return }
        guard !fileManager.fileExists(atPath: canonicalURL.path) else { return }

        do {
            try fileStore.ensureDirectoryExists()
            // Backup is best-effort; avoid aborting migrations if backup fails in test sandboxes.
            try? backupFile(at: legacyURL)
            try fileManager.copyItem(at: legacyURL, to: canonicalURL)
            try fileManager.removeItem(at: legacyURL)
            logger.info("Migrated conversation index to \(canonicalURL.path, privacy: .private).")
        } catch {
            if strict { throw error }
            logger.error("Conversation index migration failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }

    // MARK: - Project store migration

    private func migrateLegacyProjectStoreIfNeeded(strict: Bool) throws {
        guard let legacyURL = legacyProjectStoreURL(),
              fileManager.fileExists(atPath: legacyURL.path)
        else { return }

        let projectsRoot = fileStore
            .resolveDatabasePath()
            .appendingPathComponent("Projects", isDirectory: true)

        do {
            let projectsDirectory = try ProjectsDirectory(fileManager: fileManager, rootURL: projectsRoot)
            try migrateLegacyProjectStore(using: projectsDirectory, legacyURL: legacyURL, strict: strict)
        } catch {
            if strict { throw error }
            logger.error("Unable to initialize or prepare ProjectsDirectory; skipping project migration. \(error.localizedDescription, privacy: .public)")
            return
        }
    }

    private func migrateLegacyProjectStore(using projectsDirectory: ProjectsDirectory, legacyURL: URL, strict: Bool) throws {

        do {
            try projectsDirectory.ensureExists()
            let recentURL = projectsDirectory.url(for: .recent)
            let lastOpenedURL = projectsDirectory.url(for: .lastOpened)
            let settingsURL = projectsDirectory.url(for: .settings)

            // Idempotent: if all new files exist, assume migration already ran.
            if fileManager.fileExists(atPath: recentURL.path) &&
                fileManager.fileExists(atPath: lastOpenedURL.path) &&
                fileManager.fileExists(atPath: settingsURL.path) {
                logger.debug("Project files already migrated; skipping.")
                return
            }

            let legacyData = try Data(contentsOf: legacyURL)
            let payload = try JSONDecoder().decode(LegacyProjectPayload.self, from: legacyData)

            try backupFile(at: legacyURL)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            if !fileManager.fileExists(atPath: recentURL.path) {
                let data = try encoder.encode(payload.recent)
                try data.write(to: recentURL, options: [.atomic])
                logger.info("Created recent projects file at \(recentURL.path, privacy: .private).")
            }

            if !fileManager.fileExists(atPath: lastOpenedURL.path) {
                let data = try encoder.encode(payload.lastOpened)
                try data.write(to: lastOpenedURL, options: [.atomic])
                logger.info("Created last opened project file at \(lastOpenedURL.path, privacy: .private).")
            }

            if !fileManager.fileExists(atPath: settingsURL.path) {
                let settings = ProjectSettingsPayload(lastSelections: payload.lastSelections)
                let data = try encoder.encode(settings)
                try data.write(to: settingsURL, options: [.atomic])
                logger.info("Created project settings file at \(settingsURL.path, privacy: .private).")
            }

            seedProjectPreferences(from: payload)
        } catch {
            if strict { throw error }
            logger.error("Project store migration failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func legacyProjectStoreURL() -> URL? {
        let base = fileStore.resolveDatabasePath().deletingLastPathComponent()
        return base
            .appendingPathComponent("EntelechiaOperator", isDirectory: true)
            .appendingPathComponent("projects.json", isDirectory: false)
    }

    private func seedProjectPreferences(from payload: LegacyProjectPayload) {
        let selectionMap = payload.lastSelections
        let projectPaths = payload.allProjectPaths
        for path in projectPaths {
            let rootURL = URL(fileURLWithPath: path)
            guard fileManager.fileExists(atPath: rootURL.path) else { continue }

            do {
                try ensureContextPreferences(for: rootURL)
                try ensurePreferences(for: rootURL, selectionPath: selectionMap[path])
            } catch {
                logger.error("Failed seeding .entelechia folder for \(rootURL.path, privacy: .private): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func ensureContextPreferences(for projectRoot: URL) throws {
        let fileURL = projectRoot
            .appendingPathComponent(".entelechia", isDirectory: true)
            .appendingPathComponent("context_preferences.json", isDirectory: false)
        guard !fileManager.fileExists(atPath: fileURL.path) else { return }
        try contextStore.save(.empty, for: projectRoot)
    }

    private func ensurePreferences(for projectRoot: URL, selectionPath: String?) throws {
        var shouldSetSelection = false
        if let selectionPath {
            let selectionURL = URL(fileURLWithPath: selectionPath)
            shouldSetSelection = fileManager.fileExists(atPath: selectionURL.path)
        }

        try preferencesStore.update(for: projectRoot) { preferences in
            if shouldSetSelection, let selectionPath {
                let key = PreferenceKeys.workspaceLastSelectionPath
                if preferences[key] == nil {
                    preferences[key] = .string(selectionPath)
                }
            }
        }
    }

    private func backupFile(at url: URL) throws {
        let backupURL = url.appendingPathExtension("backup-\(timestamp())")
        guard !fileManager.fileExists(atPath: backupURL.path) else { return }
        try fileManager.copyItem(at: url, to: backupURL)
        logger.info("Created backup for \(url.lastPathComponent, privacy: .private) at \(backupURL.path, privacy: .private).")
    }

    private func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }
}

// MARK: - Legacy payloads

private struct LegacyProjectPayload: Codable {
    struct StoredProject: Codable, Equatable {
        var name: String
        var path: String
        var bookmarkData: Data?
    }

    var lastOpened: StoredProject?
    var recent: [StoredProject]
    var lastSelections: [String: String]

    var allProjectPaths: Set<String> {
        var paths = Set<String>()
        if let last = lastOpened?.path {
            paths.insert(last)
        }
        paths.formUnion(recent.map(\.path))
        paths.formUnion(lastSelections.keys)
        return paths
    }
}

private struct ProjectSettingsPayload: Codable {
    var lastSelections: [String: String]
}

private enum PreferenceKeys {
    static let workspaceLastSelectionPath = "workspace.lastSelection.path"
}
