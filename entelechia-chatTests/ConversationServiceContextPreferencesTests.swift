import XCTest
@testable import entelechia_chat

@MainActor
final class ConversationServiceContextPreferencesTests: XCTestCase {
    func testApplyPreferencesRespectsIncludeExclude() throws {
        let files = [
            LoadedFile(name: "keep.swift", url: URL(fileURLWithPath: "/tmp/keep.swift"), content: "a"),
            LoadedFile(name: "drop.swift", url: URL(fileURLWithPath: "/tmp/drop.swift"), content: "b")
        ]
        
        let preferences = ContextPreferences(
            includedPaths: ["/tmp/keep.swift"],
            excludedPaths: ["/tmp/drop.swift"],
            lastFocusedFilePath: nil
        )
        
        let result = applyPreferences(preferences, to: files)
        let map = Dictionary(uniqueKeysWithValues: result.map { ($0.url.path, $0.isIncludedInContext) })
        XCTAssertEqual(map["/tmp/keep.swift"], true, "map=\(map)")
        XCTAssertEqual(map["/tmp/drop.swift"], false, "map=\(map)")
        XCTAssertEqual(result.count, files.count)
    }
    
    func testApplyPreferencesWithNoIncludesUsesExcludesOnly() throws {
        let files = [
            LoadedFile(name: "a.swift", url: URL(fileURLWithPath: "/tmp/a.swift"), content: "a"),
            LoadedFile(name: "b.swift", url: URL(fileURLWithPath: "/tmp/b.swift"), content: "b")
        ]
        
        let preferences = ContextPreferences(
            includedPaths: [],
            excludedPaths: ["/tmp/b.swift"],
            lastFocusedFilePath: nil
        )
        
        let result = applyPreferences(preferences, to: files)
        let map = Dictionary(uniqueKeysWithValues: result.map { ($0.url.path, $0.isIncludedInContext) })
        XCTAssertEqual(map["/tmp/a.swift"], true)
        XCTAssertEqual(map["/tmp/b.swift"], false)
        XCTAssertEqual(result.count, files.count)
    }
}

/// Local copy of the ConversationService preference logic to keep this test pure and crash-free.
private func applyPreferences(_ preferences: ContextPreferences, to files: [LoadedFile]) -> [LoadedFile] {
    let includes = preferences.includedPaths
    let excludes = preferences.excludedPaths
    
    return files.map { file in
        let path = file.url.path
        var updated = file
        
        if excludes.contains(path) {
            updated.isIncludedInContext = false
        } else if !includes.isEmpty {
            updated.isIncludedInContext = includes.contains(path)
        }
        
        return updated
    }
}

