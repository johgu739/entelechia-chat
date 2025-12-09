// @EntelechiaHeaderStart
// Signifier: ContextPreferencesStore
// Substance: Project-scoped context preferences persistence
// Genus: Infrastructure preferences helper
// Differentia: Reads and writes `.entelechia/context_preferences.json`
// Form: Codable value + file-backed store
// Matter: Included/excluded file paths and inspector toggles
// Powers: Load, mutate, and persist context inclusion preferences
// FinalCause: Preserve user intent for conversation context selections
// Relations: Serves Workspace faculties and inspectors
// CausalityType: Instrumental
// @EntelechiaHeaderEnd

import Foundation
import os.log
import AppComposition

struct ContextPreferences: Codable, Equatable, Sendable {
    var includedPaths: Set<String>
    var excludedPaths: Set<String>
    var lastFocusedFilePath: String?

    static let empty = ContextPreferences(
        includedPaths: [],
        excludedPaths: [],
        lastFocusedFilePath: nil
    )
}

enum ContextPreferencesStoreError: LocalizedError {
    case encodingFailure
    case decodingFailure
    case writeFailure(Error)

    var errorDescription: String? {
        switch self {
        case .encodingFailure:
            return "Failed to encode context preferences."
        case .decodingFailure:
            return "Failed to decode stored context preferences."
        case .writeFailure(let error):
            return "Failed to persist context preferences: \(error.localizedDescription)"
        }
    }
}

protocol ContextPreferencesStoring {
    func load(for projectRoot: URL, strict: Bool) throws -> ContextPreferences
    func save(_ preferences: ContextPreferences, for projectRoot: URL) throws
}

struct ContextPreferencesStore: ContextPreferencesStoring {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let logger = Logger.preferences
    private let strict: Bool

    init(
        fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        strict: Bool = false
    ) {
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder
        self.strict = strict
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load(for projectRoot: URL, strict: Bool = false) throws -> ContextPreferences {
        let url = fileURL(for: projectRoot)
        guard fileManager.fileExists(atPath: url.path) else {
            logger.debug("Context preferences missing at \(url.path, privacy: .private); returning defaults.")
            return .empty
        }

        do {
            let data = try Data(contentsOf: url)
            let preferences = try decoder.decode(ContextPreferences.self, from: data)
            logger.info("Loaded context preferences from \(url.path, privacy: .private).")
            return preferences
        } catch {
            logger.error("Failed to decode context preferences at \(url.path, privacy: .private): \(error.localizedDescription, privacy: .public)")
            if strict { throw error }
            return .empty
        }
    }

    func save(_ preferences: ContextPreferences, for projectRoot: URL) throws {
        let url = fileURL(for: projectRoot)
        do {
            try ensureDirectoryExists(for: url)
            let data = try encoder.encode(preferences)
            try data.write(to: url, options: [.atomic])
            logger.info("Context preferences saved at \(url.path, privacy: .private).")
        } catch let error as ContextPreferencesStoreError {
            throw error
        } catch {
            logger.error("Failed to save context preferences at \(url.path, privacy: .private): \(error.localizedDescription, privacy: .public)")
            throw ContextPreferencesStoreError.writeFailure(error)
        }
    }

    // MARK: - Helpers

    private func fileURL(for projectRoot: URL) -> URL {
        projectRoot
            .appendingPathComponent(".entelechia", isDirectory: true)
            .appendingPathComponent("context_preferences.json", isDirectory: false)
    }

    private func ensureDirectoryExists(for fileURL: URL) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        guard !fileManager.fileExists(atPath: directoryURL.path) else { return }
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create preferences directory at \(directoryURL.path, privacy: .private): \(error.localizedDescription, privacy: .public)")
            throw ContextPreferencesStoreError.writeFailure(error)
        }
    }
}
