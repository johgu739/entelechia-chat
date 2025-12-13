import XCTest
@testable import AppAdapters
import AppCoreEngine

final class FileSystemBinaryGuardTests: XCTestCase {

    func testBinaryFilesAreExcludedFromDescriptors() throws {
        let temp = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }
        let root = temp.appendingPathComponent("root")
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        // Create a binary file (non-text UTI)
        let binURL = root.appendingPathComponent("image.bin")
        let bytes: [UInt8] = [0xFF, 0xD8, 0xFF, 0xD9]
        try Data(bytes).write(to: binURL)

        // Create a text file
        let txtURL = root.appendingPathComponent("readme.txt")
        try "hello".write(to: txtURL, atomically: true, encoding: .utf8)

        let adapter = FileSystemAccessAdapter()
        let rootID = try adapter.resolveRoot(at: root.path)
        let children = try adapter.listChildren(of: rootID)

        XCTAssertEqual(children.count, 1)
        XCTAssertEqual(children.first?.name, "readme.txt")
    }

    func testOversizeFilesAreExcludedFromDescriptors() throws {
        let temp = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }
        let root = temp.appendingPathComponent("root")
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let oversized = root.appendingPathComponent("big.txt")
        let bigContent = String(repeating: "a", count: 1_500_000) // 1.5 MB
        try bigContent.write(to: oversized, atomically: true, encoding: .utf8)

        let small = root.appendingPathComponent("small.txt")
        try "ok".write(to: small, atomically: true, encoding: .utf8)

        let adapter = FileSystemAccessAdapter(maxDescriptorBytes: 1_000_000)
        let rootID = try adapter.resolveRoot(at: root.path)
        let children = try adapter.listChildren(of: rootID)

        XCTAssertEqual(children.map(\.name), ["small.txt"])
    }

    // MARK: - Helpers
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}



