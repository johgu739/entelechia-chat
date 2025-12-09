import XCTest
@testable import ChatUI
import AppCoreEngine

private final class StubSecurityScope: SecurityScopeHandling, @unchecked Sendable {
    private(set) var startedURL: URL?
    private(set) var stoppedURL: URL?

    func createBookmark(for url: URL) throws -> Data { Data([0x01]) }
    func resolveBookmark(_ data: Data) throws -> URL { URL(fileURLWithPath: "/resolved") }
    func startAccessing(_ url: URL) -> Bool { startedURL = url; return true }
    func stopAccessing(_ url: URL) { stoppedURL = url }
}

private final class StubProjectEngine: ProjectEngine {
    func openProject(at url: URL) throws -> ProjectRepresentation {
        ProjectRepresentation(rootPath: url.path, name: url.lastPathComponent)
    }

    func validateProject(at url: URL) throws -> ProjectRepresentation {
        ProjectRepresentation(rootPath: url.path, name: url.lastPathComponent)
    }
    func save(_ project: ProjectRepresentation) throws {}
    func loadAll() throws -> [ProjectRepresentation] { [] }
}

private final class StubProjectSession: ProjectSessioning {
    private(set) var activeProjectURL: URL?
    private(set) var securityScopeActive = false
    func open(_ url: URL, name: String?, bookmarkData: Data?) {
        activeProjectURL = url
        securityScopeActive = bookmarkData != nil
    }
    func close() {
        activeProjectURL = nil
        securityScopeActive = false
    }
    func reloadSnapshot() async -> WorkspaceSnapshot { .empty }
}

private struct StubProjectMetadataHandler: ProjectMetadataHandling {
    func metadata(for bookmarkData: Data?, lastSelection: String?, isLastOpened: Bool) -> [String : String] { [:] }
    func bookmarkData(from metadata: [String : String]) -> Data? { nil }
    func withMetadata(_ metadata: [String : String], appliedTo representation: ProjectRepresentation) -> ProjectRepresentation {
        representation
    }
}

@MainActor
final class ProjectCoordinatorSessionTests: XCTestCase {

    func testBookmarkStartStopPairedOnOpenRecent() async {
        let sec = StubSecurityScope()
        let session = StubProjectSession()
        let coordinator = ProjectCoordinator(
            projectEngine: StubProjectEngine(),
            projectSession: session,
            alertCenter: AlertCenter(),
            securityScopeHandler: sec,
            projectMetadataHandler: StubProjectMetadataHandler()
        )

        coordinator.openRecent(RecentProject(
            representation: ProjectRepresentation(rootPath: "/tmp/project", name: "project"),
            bookmarkData: Data([0xAA])
        ))

        XCTAssertTrue(session.securityScopeActive)
        XCTAssertEqual(session.activeProjectURL?.path, "/tmp/project")

        coordinator.closeProject()
        XCTAssertFalse(session.securityScopeActive)
        XCTAssertNil(session.activeProjectURL)
    }
}

