import XCTest
@testable import entelechia_chat

@MainActor
final class ProjectStoreSplitLayoutTests: XCTestCase {
    private static var home: TemporaryHome?

    override func setUp() async throws {
        let home = try TemporaryHome()
        Self.home = home
        let root = home.url.appendingPathComponent("Library/Application Support/Entelechia", isDirectory: true)
        _ = makeTestPersistence(to: root)
    }

    override func tearDown() async throws {
        Self.home?.restore()
        Self.home = nil
    }

    func testPersistsRecentsAndSelectionToSplitFiles() throws {
        guard let home = Self.home else {
            XCTFail("TemporaryHome not initialized")
            return
        }
        
        let projectRoot = home.url.appendingPathComponent("Projects/DemoApp", isDirectory: true)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        let selectionURL = projectRoot.appendingPathComponent("Main.swift")
        try "print(\"hello\")".write(to: selectionURL, atomically: true, encoding: .utf8)
        
        let projectsDirectory = try ProjectsDirectory(rootURL: home.url.appendingPathComponent("Library/Application Support/Entelechia/Projects", isDirectory: true))
        try projectsDirectory.ensureExists()
        print("TRACE layout root:", projectsDirectory.rootURL.path)
        let store = try ProjectStore.loadFromDisk(projectsDirectory: projectsDirectory, strict: true)
        try store.addRecent(url: projectRoot, name: "DemoApp")
        try store.setLastOpened(url: projectRoot, name: "DemoApp")
        try store.setLastSelection(selectionURL, for: projectRoot)
        try store.saveAll()
        let recentPath = projectsDirectory.url(for: .recent)
        let lastOpenedPath = projectsDirectory.url(for: .lastOpened)
        XCTAssertTrue(FileManager.default.fileExists(atPath: recentPath.path), "Recent file should exist after saveAll")
        XCTAssertTrue(FileManager.default.fileExists(atPath: lastOpenedPath.path), "Last opened file should exist after saveAll")
        // Assert in-memory mutation before touching disk
        XCTAssertFalse(store.storedRecents.isEmpty, "In-memory recents should not be empty after addRecent")
        XCTAssertEqual(store.storedRecents.first?.path, projectRoot.path)
        
        // Re-open to verify persisted state
        let reopened = try ProjectStore.loadFromDisk(projectsDirectory: projectsDirectory, strict: true)
        if reopened.recentProjects.isEmpty {
            let exists = FileManager.default.fileExists(atPath: recentPath.path)
            let contents = (try? String(contentsOf: recentPath, encoding: .utf8)) ?? "<unreadable>"
            XCTFail("Recents empty after strict reload. Path: \(recentPath.path), exists: \(exists), contents: \(contents)")
            return
        }
        XCTAssertEqual(reopened.recentProjects.first?.path, projectRoot.path)

        // Trace recent.json contents for debugging
        print("TRACE recent path:", recentPath.path, "exists:", FileManager.default.fileExists(atPath: recentPath.path))
        if let recentString = try? String(contentsOf: recentPath, encoding: .utf8) {
            print("TRACE recent.json contents:\n", recentString)
        }
        
        let decoder = JSONDecoder()
        
        let recentData = try Data(contentsOf: projectsDirectory.url(for: .recent))
        let recents = try decoder.decode([ProjectStore.StoredProject].self, from: recentData)
        if recents.isEmpty {
            let contents = String(data: recentData, encoding: .utf8) ?? "<unreadable>"
            XCTFail("Decoded recents is empty. Path: \(recentPath.path), contents: \(contents)")
            return
        }
        XCTAssertEqual(recents.first?.path, projectRoot.path)
        
        let lastOpenedData = try Data(contentsOf: projectsDirectory.url(for: .lastOpened))
        let lastOpened = try decoder.decode(ProjectStore.StoredProject.self, from: lastOpenedData)
        XCTAssertEqual(lastOpened.path, projectRoot.path)
        
        struct ProjectSettingsPayload: Codable {
            let lastSelections: [String: String]
        }
        let settingsData = try Data(contentsOf: projectsDirectory.url(for: .settings))
        let settings = try decoder.decode(ProjectSettingsPayload.self, from: settingsData)
        XCTAssertEqual(settings.lastSelections[projectRoot.path], selectionURL.path)
        
        // Ensure legacy path is not used during split writes.
        let appSupportRoot = URL(fileURLWithPath: ProcessInfo.processInfo.environment["ENTELECHIA_APP_SUPPORT"] ?? home.url.appendingPathComponent("Library/Application Support", isDirectory: true).path, isDirectory: true)
        let legacyURL = appSupportRoot
            .appendingPathComponent("EntelechiaOperator", isDirectory: true)
            .appendingPathComponent("projects.json", isDirectory: false)
        if fileManager.fileExists(atPath: legacyURL.path) {
            let contents = (try? String(contentsOf: legacyURL, encoding: .utf8)) ?? "<unreadable>"
            XCTFail("Legacy projects.json should not exist in sandbox. Path: \(legacyURL.path), contents: \(contents)")
            return
        }
    }
}
