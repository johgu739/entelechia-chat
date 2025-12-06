import XCTest
@testable import entelechia_chat

@MainActor
final class ProjectCoordinatorResilienceTests: XCTestCase {
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

    private static var home: TemporaryHome?

    func testOpenRecentSkipsMissingSplitFilesGracefully() throws {
        guard let home = Self.home else {
            XCTFail("TemporaryHome not initialized")
            return
        }
        
        let projectsDirectory = try ProjectsDirectory(rootURL: home.url.appendingPathComponent("Library/Application Support/Entelechia/Projects", isDirectory: true))
        try projectsDirectory.ensureExists()
        let fm = FileManager.default
        let store = try ProjectStore.loadFromDisk(projectsDirectory: projectsDirectory, strict: false)
        
        // Seed a project and then remove split files to force resilience path.
        let projectRoot = home.url.appendingPathComponent("Projects/Demo", isDirectory: true)
        try fm.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        try store.addRecent(url: projectRoot, name: "Demo")
        try store.setLastOpened(url: projectRoot, name: "Demo")
        try store.saveAll()
        let recentPath = projectsDirectory.url(for: .recent)
        let lastOpenedPath = projectsDirectory.url(for: .lastOpened)
        XCTAssertTrue(fm.fileExists(atPath: recentPath.path), "Recent file should exist before deletion")
        XCTAssertTrue(fm.fileExists(atPath: lastOpenedPath.path), "Last opened file should exist before deletion")
        
        // Delete split files again to emulate corruption/missing state.
        for file in ProjectsDirectory.File.allCases {
            let url = projectsDirectory.url(for: file)
            if fm.fileExists(atPath: url.path) {
                try fm.removeItem(at: url)
            }
        }
        
        // Should not crash; allow failure result if split files missing.
        let result = ProjectCoordinatorLogic.openRecentProject(at: projectRoot.path, store: store)
        print("TRACE coordinator openRecentProject result:", result)
        switch result {
        case .success:
            XCTAssertTrue(true)
        case .failure(let error):
            // Allow graceful failure, but assert it didn’t crash
            XCTFail("Coordinator openRecentProject failed: \(error)")
        }
    }
}
