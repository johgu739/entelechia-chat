import XCTest
@testable import entelechia_chat

@MainActor
final class ContextPreferencesLoggingTests: XCTestCase {
    func testLoadAndSaveProduceLogEntries() throws {
        let projectRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: projectRoot) }
        
        let store = ContextPreferencesStore(strict: true)
        _ = try store.load(for: projectRoot, strict: true) // should log debug
        
        var preferences = ContextPreferences.empty
        preferences.includedPaths.insert(projectRoot.appendingPathComponent("File.swift").path)
        try store.save(preferences, for: projectRoot) // should log debug
        
        let reloaded = try store.load(for: projectRoot, strict: true)
        XCTAssertEqual(reloaded, preferences)
    }
}

