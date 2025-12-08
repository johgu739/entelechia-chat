import XCTest
@testable import ChatUI
import CoreEngine

private final class StubSecurityScope: SecurityScopeHandling {
    private(set) var started: URL?
    private(set) var stopped: URL?

    func createBookmark(for url: URL) throws -> Data { Data([0x01]) }
    func resolveBookmark(_ data: Data) throws -> URL { URL(fileURLWithPath: "/resolved") }
    func startAccessing(_ url: URL) -> Bool { started = url; return true }
    func stopAccessing(_ url: URL) { stopped = url }
}

private final class StubProjectEngine: ProjectEngine {
    func validateProject(at url: URL) throws -> ProjectRepresentation {
        ProjectRepresentation(rootPath: url.path, name: url.lastPathComponent)
    }
    func save(_ project: ProjectRepresentation) throws {}
    func loadAll() throws -> [ProjectRepresentation] { [] }
}

private final class StubProjectSession: ProjectSessioning {
    private(set) var activeProjectURL: URL?
    private(set) var securityScopeActive = false
    func openProject(at url: URL) {
        activeProjectURL = url
    }
    func startSecurityScope(for url: URL) {
        securityScopeActive = true
        activeProjectURL = url
    }
    func stopSecurityScope() { securityScopeActive = false }
}

final class ProjectCoordinatorSessionTests: XCTestCase {

    func testBookmarkStartStopPairedOnOpenRecent() {
        let sec = StubSecurityScope()
        let session = StubProjectSession()
        let coordinator = ProjectCoordinator(
            projectEngine: StubProjectEngine(),
            projectSession: session,
            alertCenter: AlertCenter(),
            securityScopeHandler: sec,
            metadataHandler: ProjectMetadataHandler()
        )

        coordinator.openRecentProject(at: URL(fileURLWithPath: "/tmp/project"), bookmarkData: Data([0xAA]))

        XCTAssertTrue(session.securityScopeActive)
        XCTAssertEqual(sec.started, URL(fileURLWithPath: "/resolved"))

        coordinator.closeProject()
        XCTAssertFalse(session.securityScopeActive)
        XCTAssertEqual(sec.stopped, URL(fileURLWithPath: "/resolved"))
    }
}

