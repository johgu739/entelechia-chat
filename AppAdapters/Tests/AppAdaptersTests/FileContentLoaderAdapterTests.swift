import XCTest
@testable import AppAdapters
import UniformTypeIdentifiers

final class FileContentLoaderAdapterTests: XCTestCase {

    func testRejectsTooLargeFile() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let data = Data(repeating: 0x61, count: 2_000_000) // 2MB
        try data.write(to: tmp)

        let loader = FileContentLoaderAdapter(maxBytes: 1_000_000)

        await XCTAssertThrowsErrorAsync {
            _ = try await loader.load(url: tmp)
        }
    }

    func testRejectsUnsupportedType() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: tmp)

        let loader = FileContentLoaderAdapter()

        await XCTAssertThrowsErrorAsync {
            _ = try await loader.load(url: tmp)
        }
    }
}

// MARK: - Helpers

private func XCTAssertThrowsErrorAsync(_ block: @escaping () async throws -> Void) async {
    do {
        try await block()
        XCTFail("Expected error, got success")
    } catch {
        // expected
    }
}




