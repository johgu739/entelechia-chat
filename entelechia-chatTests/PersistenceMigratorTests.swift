import XCTest
@testable import entelechia_chat

final class PersistenceMigratorTests: XCTestCase {
    private static var home: TemporaryHome?
    private var fileStore: FileStore!

    override func setUp() async throws {
        let home = try TemporaryHome()
        Self.home = home
        let root = home.url.appendingPathComponent("Library/Application Support/Entelechia", isDirectory: true)
        (fileStore, _) = makeTestPersistence(to: root)
    }

    override func tearDown() async throws {
        Self.home?.restore()
        Self.home = nil
    }
    
    func testMigratesLegacyConversationIndex() throws {
        let fileManager = FileManager.default
        let fileStore = try XCTUnwrap(self.fileStore)
        let legacyURL = fileStore.resolveLegacyIndexPath()
        try fileManager.createDirectory(at: legacyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let legacyData = "legacy-index".data(using: .utf8)!
        try legacyData.write(to: legacyURL)

        do {
            try fileStore.ensureDirectoryExists()
            try PersistenceMigrator.performConversationIndexMigration(
                fileManager: fileManager,
                legacyURL: legacyURL,
                canonicalURL: fileStore.resolveIndexPath(),
                createBackup: false
            )
        } catch {
            XCTFail("Migration failed: \(error)")
        }

        let canonicalURL = fileStore.resolveIndexPath()
        XCTAssertFalse(fileManager.fileExists(atPath: legacyURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: canonicalURL.path))
        XCTAssertEqual(try Data(contentsOf: canonicalURL), legacyData)

    }

    func testMigratesLegacyProjectStoreAndSeedsPreferences() throws {
        guard let home = Self.home else {
            XCTFail("TemporaryHome not initialized")
            return
        }
        let fileManager = FileManager.default
        let fileStore = try XCTUnwrap(self.fileStore)
        let contextStore = ContextPreferencesStore(strict: true)
        let preferencesStore = PreferencesStore(strict: true)

        // Prepare legacy project database.
        let appSupport = home.url
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
        try fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)

        let legacyDir = appSupport.appendingPathComponent("EntelechiaOperator", isDirectory: true)
        try fileManager.createDirectory(at: legacyDir, withIntermediateDirectories: true)
        let legacyURL = legacyDir.appendingPathComponent("projects.json")

        // Create a mock project root with a selectable file.
        let projectRoot = home.url.appendingPathComponent("Projects/ExampleApp", isDirectory: true)
        try fileManager.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        let selectionURL = projectRoot.appendingPathComponent("Sources/App.swift")
        try fileManager.createDirectory(at: selectionURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "print(\"hello\")".write(to: selectionURL, atomically: true, encoding: .utf8)
        
        // Ensure no existing .entelechia folder to contaminate expectations.
        let entelechiaDir = projectRoot.appendingPathComponent(".entelechia", isDirectory: true)
        if fileManager.fileExists(atPath: entelechiaDir.path) {
            try fileManager.removeItem(at: entelechiaDir)
        }

        let payload: [String: Any] = [
            "lastOpened": [
                "name": "ExampleApp",
                "path": projectRoot.path,
                "bookmarkData": NSNull()
            ],
            "recent": [
                [
                    "name": "ExampleApp",
                    "path": projectRoot.path,
                    "bookmarkData": NSNull()
                ]
            ],
            "lastSelections": [
                projectRoot.path: selectionURL.path
            ]
        ]
        let legacyData = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        try legacyData.write(to: legacyURL)

        let projectsDirectory = try ProjectsDirectory(rootURL: home.url.appendingPathComponent("Library/Application Support/Entelechia/Projects", isDirectory: true))
        try projectsDirectory.ensureExists()
        // Ensure no pre-existing split files so migration runs.
        for file in ProjectsDirectory.File.allCases {
            let url = projectsDirectory.url(for: file)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
        
        do {
            try PersistenceMigrator(
                fileStore: fileStore,
                fileManager: fileManager,
                contextStore: contextStore,
                preferencesStore: preferencesStore
            ).runMigrations(strict: true)
        } catch {
            XCTFail("runMigrations failed: \(error)")
            return
        }
        
        let decoder = JSONDecoder()
        
        struct TestStoredProject: Codable, Equatable {
            let name: String
            let path: String
            let bookmarkData: Data?
        }
        
        struct TestSettingsPayload: Codable, Equatable {
            let lastSelections: [String: String]
        }
        
        let recentData = try Data(contentsOf: projectsDirectory.url(for: .recent))
        let recents = try decoder.decode([TestStoredProject].self, from: recentData)
        XCTAssertFalse(recents.isEmpty, "recents=\(recents)")
        XCTAssertFalse(recents.first?.path.isEmpty ?? true, "recentsPath=\(recents.first?.path ?? "nil")")
        
        let lastOpenedData = try Data(contentsOf: projectsDirectory.url(for: .lastOpened))
        let lastOpened = try decoder.decode(TestStoredProject?.self, from: lastOpenedData)
        XCTAssertNotNil(lastOpened, "lastOpened nil")
        XCTAssertFalse(lastOpened?.path.isEmpty ?? true, "lastOpenedPath=\(lastOpened?.path ?? "nil")")
        
        let settingsData = try Data(contentsOf: projectsDirectory.url(for: .settings))
        let settings = try decoder.decode(TestSettingsPayload.self, from: settingsData)
        XCTAssertFalse(settings.lastSelections.isEmpty, "settings=\(settings)")
        
        let preferences = try preferencesStore.load(for: projectRoot, strict: true)
        if case let .string(path)? = preferences["workspace.lastSelection.path"] {
            XCTAssertFalse(path.isEmpty, "prefPath=\(path)")
        } else {
            XCTFail("Expected workspace.lastSelection.path to be set, preferences=\(preferences)")
        }
    }
}
