// @EntelechiaHeaderStart
// Signifier: ProjectsDirectory
// Substance: Canonical project metadata directory representation
// Genus: Infrastructure persistence helper
// Differentia: Resolves Application Support paths for project files
// Form: Value object exposing URLs and helpers
// Matter: Application Support base, directory FileManager instrumentation
// Powers: Provide URLs, ensure directories exist, create backups
// FinalCause: Guarantee deterministic layout for project persistence
// Relations: Serves ProjectStore migrations and Codex readiness checks
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation
import os.log

struct ProjectsDirectory {
    enum File: String, CaseIterable {
        case recent = "recent.json"
        case lastOpened = "last_opened.json"
        case settings = "project_settings.json"
    }

    enum Error: Swift.Error {
        case applicationSupportUnavailable
        case directoryCreationFailed(Swift.Error)
    }

    let rootURL: URL
    private let fileManager: FileManager
    private let logger = Logger.persistence

    init(
        fileManager: FileManager = .default,
        rootURL: URL? = nil
    ) throws {
        self.fileManager = fileManager
        if let customRoot = rootURL {
            self.rootURL = customRoot
        } else if let overridePtr = getenv("ENTELECHIA_APP_SUPPORT") {
            let override = String(cString: overridePtr)
            self.rootURL = URL(fileURLWithPath: override, isDirectory: true)
                .appendingPathComponent("Entelechia", isDirectory: true)
                .appendingPathComponent("Projects", isDirectory: true)
        } else if let override = ProcessInfo.processInfo.environment["ENTELECHIA_APP_SUPPORT"] {
            self.rootURL = URL(fileURLWithPath: override, isDirectory: true)
                .appendingPathComponent("Entelechia", isDirectory: true)
                .appendingPathComponent("Projects", isDirectory: true)
        } else {
            guard let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw Error.applicationSupportUnavailable
            }
            self.rootURL = applicationSupport
                .appendingPathComponent("Entelechia", isDirectory: true)
                .appendingPathComponent("Projects", isDirectory: true)
        }
    }

    func url(for file: File) -> URL {
        rootURL.appendingPathComponent(file.rawValue, isDirectory: false)
    }

    func ensureExists() throws {
        guard !fileManager.fileExists(atPath: rootURL.path) else { return }
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            logger.debug("Created Projects directory at \(rootURL.path, privacy: .private).")
        } catch {
            logger.error("Failed to create Projects directory at \(rootURL.path, privacy: .private): \(error.localizedDescription, privacy: .public)")
            throw Error.directoryCreationFailed(error)
        }
    }

    func backupURL(for file: File, timestamp: Date = Date()) -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let suffix = formatter.string(from: timestamp)
        let backupFileName = "\(file.rawValue).backup-\(suffix)"
        return rootURL.appendingPathComponent(backupFileName, isDirectory: false)
    }
}
