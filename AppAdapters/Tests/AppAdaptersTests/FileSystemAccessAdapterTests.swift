import XCTest
@testable import AppAdapters
import AppCoreEngine

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

    func testBoundaryFilterDeniesRestrictedComponents() {
        let filter = DefaultWorkspaceBoundaryFilter()
        XCTAssertFalse(filter.allows(canonicalPath: "/tmp/project/.git/config"))
        XCTAssertFalse(filter.allows(canonicalPath: "/tmp/project/DerivedData/Logs"))
        XCTAssertFalse(filter.allows(canonicalPath: "/tmp/project/.build/debug"))
        XCTAssertFalse(filter.allows(canonicalPath: "/tmp/project/.swiftpm/x"))
        XCTAssertFalse(filter.allows(canonicalPath: "/tmp/project/Pods/XYZ"))
        XCTAssertFalse(filter.allows(canonicalPath: "/tmp/project/node_modules/foo"))
        XCTAssertFalse(filter.allows(canonicalPath: "/tmp/project/OntologyCore/file"))
        XCTAssertFalse(filter.allows(canonicalPath: "/tmp/project/.DS_Store"))
        XCTAssertTrue(filter.allows(canonicalPath: "/tmp/project/Sources"))
    }

    func testAdapterSkipsRestrictedChildren() throws {
        let temp = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }
        let root = temp.appendingPathComponent("root")
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("DerivedData"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent(".build"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent(".swiftpm"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("Pods"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("OntologyCore"), withIntermediateDirectories: true)
        let sources = root.appendingPathComponent("Sources")
        try fm.createDirectory(at: sources, withIntermediateDirectories: true)
        let file = sources.appendingPathComponent("main.swift")
        try "print(\"hi\")".write(to: file, atomically: true, encoding: .utf8)

        let adapter = FileSystemAccessAdapter()
        let rootID = try adapter.resolveRoot(at: root.path)
        let children = try adapter.listChildren(of: rootID)
        XCTAssertEqual(children.map(\.name), ["Sources"])

        guard let sourcesID = children.first?.id else {
            XCTFail("Missing Sources directory"); return
        }
        let sourceChildren = try adapter.listChildren(of: sourcesID)
        XCTAssertEqual(sourceChildren.map(\.name), ["main.swift"])
    }

    func testResolveRootCanonicalizesSymlink() throws {
        let temp = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }
        let realRoot = temp.appendingPathComponent("realroot")
        let fm = FileManager.default
        try fm.createDirectory(at: realRoot, withIntermediateDirectories: true)
        let file = realRoot.appendingPathComponent("a.txt")
        try "hello".write(to: file, atomically: true, encoding: .utf8)

        let symlink = temp.appendingPathComponent("linkroot")
        try fm.createSymbolicLink(at: symlink, withDestinationURL: realRoot)

        let adapter = FileSystemAccessAdapter()
        let rootID = try adapter.resolveRoot(at: symlink.path)
        let metadata = try adapter.metadata(for: rootID)
        XCTAssertEqual(metadata.path, realRoot.standardizedFileURL.path)

        let children = try adapter.listChildren(of: rootID)
        XCTAssertEqual(children.map(\.canonicalPath), [file.standardizedFileURL.path])
    }

    // MARK: - Helpers
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

