// @EntelechiaHeaderStart
// Signifier: PreferencesStore
// Substance: General-purpose preferences persistence
// Genus: Infrastructure preferences helper
// Differentia: Typed key-value storage under `.entelechia/preferences.json`
// Form: Codable dictionary + file-backed store
// Matter: Preference keys, typed payloads, JSON encoder
// Powers: Load, query, and mutate project/UI preferences
// FinalCause: Preserve user-facing configuration in a deterministic fashion
// Relations: Serves workspace faculties, inspectors, and teleology injection
// CausalityType: Instrumental
// @EntelechiaHeaderEnd

import Foundation
import os.log

enum PreferenceValue: Codable, Equatable, Sendable {
    case bool(Bool)
    case string(String)
    case integer(Int)
    case double(Double)

    private enum CodingKeys: String, CodingKey {
        case type, bool, string, integer, double
    }

    private enum ValueType: String, Codable {
        case bool, string, integer, double
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ValueType.self, forKey: .type)
        switch type {
        case .bool:
            let value = try container.decode(Bool.self, forKey: .bool)
            self = .bool(value)
        case .string:
            let value = try container.decode(String.self, forKey: .string)
            self = .string(value)
        case .integer:
            let value = try container.decode(Int.self, forKey: .integer)
            self = .integer(value)
        case .double:
            let value = try container.decode(Double.self, forKey: .double)
            self = .double(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .bool(let value):
            try container.encode(ValueType.bool, forKey: .type)
            try container.encode(value, forKey: .bool)
        case .string(let value):
            try container.encode(ValueType.string, forKey: .type)
            try container.encode(value, forKey: .string)
        case .integer(let value):
            try container.encode(ValueType.integer, forKey: .type)
            try container.encode(value, forKey: .integer)
        case .double(let value):
            try container.encode(ValueType.double, forKey: .type)
            try container.encode(value, forKey: .double)
        }
    }
}

struct Preferences: Codable, Equatable, Sendable {
    private(set) var values: [String: PreferenceValue]

    static let empty = Preferences(values: [:])

    init(values: [String: PreferenceValue] = [:]) {
        self.values = values
    }

    subscript(key: String) -> PreferenceValue? {
        get { values[key] }
        set { values[key] = newValue }
    }
}

enum PreferencesStoreError: LocalizedError {
    case encodingFailure
    case decodingFailure
    case writeFailure(Error)

    var errorDescription: String? {
        switch self {
        case .encodingFailure:
            return "Failed to encode preferences."
        case .decodingFailure:
            return "Failed to decode stored preferences."
        case .writeFailure(let error):
            return "Failed to write preferences: \(error.localizedDescription)"
        }
    }
}

protocol PreferencesStoring {
    func load(for projectRoot: URL, strict: Bool) throws -> Preferences
    func update(for projectRoot: URL, mutation: (inout Preferences) -> Void) throws -> Preferences
}

struct PreferencesStore: PreferencesStoring {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let logger = Logger(subsystem: "AppAdapters", category: "PreferencesStore")
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

    func load(for projectRoot: URL, strict: Bool = false) throws -> Preferences {
        let url = fileURL(for: projectRoot)
        guard fileManager.fileExists(atPath: url.path) else {
            logger.debug("Preferences missing at \(url.path); returning defaults.")
            return .empty
        }

        do {
            let data = try Data(contentsOf: url)
            let preferences = try decoder.decode(Preferences.self, from: data)
            logger.debug("Loaded preferences from \(url.path).")
            return preferences
        } catch {
            logger.error("Failed to decode preferences at \(url.path): \(error.localizedDescription)")
            if strict { throw error }
            return .empty
        }
    }

    @discardableResult
    func update(for projectRoot: URL, mutation: (inout Preferences) -> Void) throws -> Preferences {
        var preferences = try load(for: projectRoot)
        mutation(&preferences)
        try save(preferences, to: projectRoot)
        return preferences
    }

    // MARK: - Private

    private func save(_ preferences: Preferences, to projectRoot: URL) throws {
        let url = fileURL(for: projectRoot)
        do {
            try ensureDirectoryExists(for: url)
            let data = try encoder.encode(preferences)
            try data.write(to: url, options: [.atomic])
            logger.debug("Preferences saved at \(url.path).")
        } catch let error as PreferencesStoreError {
            throw error
        } catch {
            logger.error("Failed to save preferences at \(url.path): \(error.localizedDescription)")
            throw PreferencesStoreError.writeFailure(error)
        }
    }

    private func fileURL(for projectRoot: URL) -> URL {
        projectRoot
            .appendingPathComponent(".entelechia", isDirectory: true)
            .appendingPathComponent("preferences.json", isDirectory: false)
    }

    private func ensureDirectoryExists(for fileURL: URL) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        guard !fileManager.fileExists(atPath: directoryURL.path) else { return }
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create preferences directory at \(directoryURL.path, privacy: .private): \(error.localizedDescription, privacy: .public)")
            throw PreferencesStoreError.writeFailure(error)
        }
    }
}


