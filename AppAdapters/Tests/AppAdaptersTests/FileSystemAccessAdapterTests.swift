import XCTest
@testable import AppAdapters
import CoreEngine

final class FileSystemAccessAdapterTests: XCTestCase {

    func testPathToIDMappingIsStableAcrossListings() throws {
        let temp = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }
        let root = temp.appendingPathComponent("root")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("a.txt")
        try "hello".write(to: file, atomically: true, encoding: .utf8)

        let adapter = FileSystemAccessAdapter()
        let rootID = try adapter.resolveRoot(at: root.path)

        let first = try adapter.listChildren(of: rootID)
        let second = try adapter.listChildren(of: rootID)

        guard let firstID = first.first(where: { $0.name == "a.txt" })?.id else {
            XCTFail("Missing a.txt in first listing"); return
        }
        guard let secondID = second.first(where: { $0.name == "a.txt" })?.id else {
            XCTFail("Missing a.txt in second listing"); return
        }

        XCTAssertEqual(firstID, secondID, "IDs must remain stable for identical paths across listings")

        // Validate reverse lookup
        let metadata = try adapter.metadata(for: firstID)
        XCTAssertEqual(URL(fileURLWithPath: metadata.path).standardizedFileURL.path, file.standardizedFileURL.path)
    }

    // MARK: - Helpers
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

