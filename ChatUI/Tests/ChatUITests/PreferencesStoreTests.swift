import XCTest
@testable import ChatUI

@MainActor
final class PreferencesStoreTests: XCTestCase {
    func testUpdatePersistsPreference() throws {
        let projectRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: projectRoot) }
        
        let store = PreferencesStore(strict: true)
        let key = "workspace.lastSelection.path"
        let selection = projectRoot.appendingPathComponent("File.swift").path
        
        let updated = try store.update(for: projectRoot) { preferences in
            preferences[key] = .string(selection)
        }
        
        XCTAssertEqual(updated[key], .string(selection))
        
        let reloaded = try store.load(for: projectRoot, strict: true)
        XCTAssertEqual(reloaded[key], .string(selection))
    }
    
    func testLoadDefaultsWhenMissing() throws {
        let projectRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: projectRoot) }
        
        let store = PreferencesStore(strict: true)
        let loaded = try store.load(for: projectRoot, strict: true)
        XCTAssertEqual(loaded, .empty)
    }
}

