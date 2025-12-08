import XCTest
@testable import AppAdapters
import CoreEngine

final class ProjectStoreRealAdapterTests: XCTestCase {

    func testRoundTripPersistsMetadata() throws {
        let temp = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }

        let adapter = ProjectStoreRealAdapter(baseURL: temp)
        let projectID = UUID()
        let rep = ProjectRepresentation(
            rootPath: temp.appendingPathComponent("root").path,
            name: "TestProject",
            metadata: [
                "bookmarkData": Data([0x01, 0x02]).base64EncodedString(),
                "lastSelection": "/file.swift",
                "lastSelectionDescriptorID": projectID.uuidString,
                "lastOpened": "true"
            ],
            linkedFiles: []
        )

        try adapter.saveProjects([rep])
        let loaded = try adapter.loadProjects()

        XCTAssertEqual(loaded.count, 1)
        let loadedRep = try XCTUnwrap(loaded.first)
        XCTAssertEqual(loadedRep.rootPath, rep.rootPath)
        XCTAssertEqual(loadedRep.metadata["lastSelection"], "/file.swift")
        XCTAssertEqual(loadedRep.metadata["lastSelectionDescriptorID"], projectID.uuidString)
        XCTAssertEqual(loadedRep.metadata["lastOpened"], "true")
        XCTAssertEqual(loadedRep.metadata["bookmarkData"], rep.metadata["bookmarkData"])
    }

    // MARK: - Helpers
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

