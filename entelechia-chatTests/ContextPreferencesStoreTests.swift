import XCTest
@testable import entelechia_chat

@MainActor
final class ContextPreferencesStoreTests: XCTestCase {
    func testLoadReturnsEmptyWhenFileMissing() throws {
        let store = ContextPreferencesStore(strict: true)
        let projectRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: projectRoot) }

        let loaded = try store.load(for: projectRoot, strict: true)
        XCTAssertEqual(loaded, .empty)

        let fileURL = projectRoot
            .appendingPathComponent(".entelechia", isDirectory: true)
            .appendingPathComponent("context_preferences.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testSavePersistsPreferences() throws {
        let store = ContextPreferencesStore(strict: true)
        let projectRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: projectRoot) }

        var preferences = ContextPreferences.empty
        preferences.includedPaths.insert("/tmp/include.swift")
        preferences.excludedPaths.insert("/tmp/exclude.swift")
        preferences.lastFocusedFilePath = "/tmp/focused.swift"

        try store.save(preferences, for: projectRoot)
        let reloaded = try store.load(for: projectRoot, strict: true)
        XCTAssertEqual(reloaded, preferences)

        let fileURL = projectRoot
            .appendingPathComponent(".entelechia", isDirectory: true)
            .appendingPathComponent("context_preferences.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
