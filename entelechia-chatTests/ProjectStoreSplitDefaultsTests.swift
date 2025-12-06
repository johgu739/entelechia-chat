import XCTest
@testable import entelechia_chat

@MainActor
final class ProjectStoreSplitDefaultsTests: XCTestCase {
    override func setUp() async throws {
        let home = try TemporaryHome()
        // Keep the temp home alive across setUp/tearDown via an associated object.
        Self.home = home
        let root = home.url.appendingPathComponent("Library/Application Support/Entelechia", isDirectory: true)
        _ = makeTestPersistence(to: root)
    }

    override func tearDown() async throws {
        Self.home?.restore()
        Self.home = nil
    }

    private static var home: TemporaryHome?

    func testLoadFromDiskWithMissingSplitFilesStartsEmpty() throws {
        guard let home = Self.home else {
            XCTFail("TemporaryHome not initialized")
            return
        }
        
        let projectsDirectory = try ProjectsDirectory(rootURL: home.url.appendingPathComponent("Library/Application Support/Entelechia/Projects", isDirectory: true))
        try projectsDirectory.ensureExists()
        let store: ProjectStore
        do {
            store = try ProjectStore.loadFromDisk(projectsDirectory: projectsDirectory, strict: false)
        } catch {
            XCTFail("Unexpected error loading ProjectStore in non-strict mode: \(error)")
            return
        }
        XCTAssertTrue(store.recentProjects.isEmpty)
        XCTAssertNil(store.lastOpenedProjectURL)
    }
}
