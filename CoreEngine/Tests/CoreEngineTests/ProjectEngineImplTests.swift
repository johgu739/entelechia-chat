import XCTest
@testable import CoreEngine

private final class InMemoryProjectPersistenceDriver: ProjectPersistenceDriver, @unchecked Sendable {
    typealias StoredProject = [ProjectRepresentation]
    private var storage: [ProjectRepresentation] = []

    func loadProjects() throws -> [ProjectRepresentation] { storage }
    func saveProjects(_ projects: [ProjectRepresentation]) throws { storage = projects }
}

final class ProjectEngineImplTests: XCTestCase {

    func testValidateRequiresNonEmptyName() {
        let driver = InMemoryProjectPersistenceDriver()
        let engine = ProjectEngineImpl(persistence: driver)

        XCTAssertThrowsError(try engine.validateProject(at: URL(fileURLWithPath: "/tmp/   ")))
    }

    func testSaveAndLoadRoundTrip() throws {
        let driver = InMemoryProjectPersistenceDriver()
        let engine = ProjectEngineImpl(persistence: driver)
        let url = URL(fileURLWithPath: "/tmp/project")

        let rep = try engine.validateProject(at: url)
        try engine.save(rep)
        let loaded = try engine.loadAll()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.rootPath, rep.rootPath)
        XCTAssertEqual(loaded.first?.name, rep.name)
    }
}

