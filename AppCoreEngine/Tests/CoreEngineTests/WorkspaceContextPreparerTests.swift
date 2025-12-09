import XCTest
@testable import AppCoreEngine

private struct ThrowingFileLoader: FileContentLoading {
    func load(url: URL) async throws -> String { throw EngineError.contextLoadFailed("fail") }
}

/// Local async throw helper (avoids depending on other test utilities).
@discardableResult
private func XCTAssertThrowsError(async expression: @escaping () async throws -> Void, file: StaticString = #file, line: UInt = #line) async -> Error? {
    do {
        try await expression()
        XCTFail("Expected error", file: file, line: line)
        return nil
    } catch {
        return error
    }
}

final class WorkspaceContextPreparerTests: XCTestCase {

    func testMissingDescriptorPathThrows() async {
        let loader = ThrowingFileLoader()
        let preparer = WorkspaceContextPreparer(fileLoader: loader)
        let descriptorID = FileID()
        let snapshot = WorkspaceSnapshot(
            rootPath: "/root",
            selectedPath: nil,
            lastPersistedSelection: nil,
            selectedDescriptorID: descriptorID,
            lastPersistedDescriptorID: descriptorID,
            contextPreferences: .empty,
            descriptorPaths: [:], // missing descriptorID mapping
            contextInclusions: [:],
            descriptors: [FileDescriptor(id: descriptorID, name: "a.swift", type: .file)]
        )

        await XCTAssertThrowsError(async: {
            _ = try await preparer.prepare(snapshot: snapshot, preferredDescriptorIDs: [descriptorID], budget: .default)
        })
    }
}

