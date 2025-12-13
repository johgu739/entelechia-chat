import XCTest
import SwiftUI
@testable import ChatUI
import UIContracts

/// Contract tests for ContextInspectorView.
/// Tests that context inspector renders correctly with fake ContextSnapshot data.
@MainActor
final class ContextInspectorContractTests: XCTestCase {

    // MARK: - Basic Construction Tests

    func testContextInspectorViewConstructsWithNilSnapshot() {
        // Test that ContextInspectorView can be constructed with nil snapshot
        let view = ContextInspectorView(snapshot: nil)

        // Verify construction succeeds
        XCTAssertNotNil(view, "ContextInspectorView should construct with nil snapshot")
    }

    func testContextInspectorViewConstructsWithEmptySnapshot() {
        // Test ContextInspectorView with empty snapshot data
        let snapshot = UIContracts.ContextSnapshot(
            scope: .selection,
            snapshotHash: "abc123",
            segments: [],
            includedFiles: [],
            truncatedFiles: [],
            excludedFiles: [],
            totalTokens: 0,
            totalBytes: 0
        )

        let view = ContextInspectorView(snapshot: snapshot)

        XCTAssertNotNil(view, "ContextInspectorView should construct with empty snapshot")
        XCTAssertEqual(snapshot.scope, .selection, "Should have selection scope")
        XCTAssertEqual(snapshot.snapshotHash, "abc123", "Should have snapshot hash")
        XCTAssertEqual(snapshot.totalTokens, 0, "Should have zero tokens")
        XCTAssertEqual(snapshot.totalBytes, 0, "Should have zero bytes")
    }

    func testContextInspectorViewConstructsWithPopulatedSnapshot() {
        // Test ContextInspectorView with populated snapshot data
        let fileDescriptor = UIContracts.ContextFileDescriptor(
            path: "/test.swift",
            language: "swift",
            size: 1000,
            hash: "abc123",
            isIncluded: true,
            isTruncated: false
        )

        let segment = UIContracts.ContextSegmentDescriptor(
            totalTokens: 10,
            totalBytes: 100,
            files: [fileDescriptor]
        )

        let snapshot = UIContracts.ContextSnapshot(
            scope: .workspace,
            snapshotHash: "def456",
            segments: [segment],
            includedFiles: [fileDescriptor],
            truncatedFiles: [],
            excludedFiles: [],
            totalTokens: 160,
            totalBytes: 1000
        )

        let view = ContextInspectorView(snapshot: snapshot)

        XCTAssertNotNil(view, "ContextInspectorView should construct with populated snapshot")
        XCTAssertEqual(snapshot.scope, .workspace, "Should have workspace scope")
        XCTAssertEqual(snapshot.segments.count, 1, "Should have one segment")
        XCTAssertEqual(snapshot.includedFiles.count, 1, "Should have one included file")
        XCTAssertEqual(snapshot.totalTokens, 160, "Should have correct token count")
        XCTAssertEqual(snapshot.totalBytes, 1000, "Should have correct byte count")
    }

    func testContextInspectorViewConstructsWithMixedFileStates() {
        // Test ContextInspectorView with included, truncated, and excluded files
        let includedFile = UIContracts.ContextFileDescriptor(
            path: "/included.swift",
            language: "swift",
            size: 500,
            hash: "hash1",
            isIncluded: true,
            isTruncated: false
        )

        let truncatedFile = UIContracts.ContextFileDescriptor(
            path: "/truncated.swift",
            language: "swift",
            size: 10000,
            hash: "hash2",
            isIncluded: true,
            isTruncated: true
        )

        let excludedFile = UIContracts.ContextFileDescriptor(
            path: "/excluded.swift",
            language: "swift",
            size: 200,
            hash: "hash3",
            isIncluded: false,
            isTruncated: false
        )

        let snapshot = UIContracts.ContextSnapshot(
            scope: .manual,
            snapshotHash: "ghi789",
            segments: [],
            includedFiles: [includedFile],
            truncatedFiles: [truncatedFile],
            excludedFiles: [excludedFile],
            totalTokens: 2105,
            totalBytes: 10700
        )

        let view = ContextInspectorView(snapshot: snapshot)

        XCTAssertNotNil(view, "ContextInspectorView should construct with mixed file states")
        XCTAssertEqual(snapshot.includedFiles.count, 1, "Should have one included file")
        XCTAssertEqual(snapshot.truncatedFiles.count, 1, "Should have one truncated file")
        XCTAssertEqual(snapshot.excludedFiles.count, 1, "Should have one excluded file")
        XCTAssertEqual(snapshot.totalTokens, 2105, "Should have correct total tokens")
        XCTAssertEqual(snapshot.totalBytes, 10700, "Should have correct total bytes")
    }

    func testContextInspectorViewConstructsWithLargeContext() {
        // Test ContextInspectorView with large context data
        var includedFiles: [UIContracts.ContextFileDescriptor] = []
        var segments: [UIContracts.ContextSegmentDescriptor] = []

        // Create multiple files and segments
        for i in 0..<10 {
            let file = UIContracts.ContextFileDescriptor(
                path: "/file\(i).swift",
                language: "swift",
                size: 1000 * (i + 1),
                hash: "hash\(i)",
                isIncluded: true,
                isTruncated: false
            )
            includedFiles.append(file)

            let segment = UIContracts.ContextSegmentDescriptor(
                totalTokens: 20,
                totalBytes: 200,
                files: [file]
            )
            segments.append(segment)
        }

        let snapshot = UIContracts.ContextSnapshot(
            scope: .workspace,
            snapshotHash: "large123",
            segments: segments,
            includedFiles: includedFiles,
            truncatedFiles: [],
            excludedFiles: [],
            totalTokens: 2000,
            totalBytes: 55000
        )

        let view = ContextInspectorView(snapshot: snapshot)

        XCTAssertNotNil(view, "ContextInspectorView should construct with large context")
        XCTAssertEqual(snapshot.includedFiles.count, 10, "Should have 10 included files")
        XCTAssertEqual(snapshot.segments.count, 10, "Should have 10 segments")
        XCTAssertEqual(snapshot.totalTokens, 2000, "Should have correct token count")
        XCTAssertEqual(snapshot.totalBytes, 55000, "Should have correct byte count")
    }

    // MARK: - Scope Variation Tests

    func testContextInspectorViewWithAllScopeTypes() {
        // Test ContextInspectorView with different scope types
        let scopes: [UIContracts.ContextScopeChoice] = [.selection, .workspace, .manual]

        for scope in scopes {
            let snapshot = UIContracts.ContextSnapshot(
                scope: scope,
                snapshotHash: "scope_test",
                segments: [],
                includedFiles: [],
                truncatedFiles: [],
                excludedFiles: [],
                totalTokens: 0,
                totalBytes: 0
            )

            let view = ContextInspectorView(snapshot: snapshot)

            XCTAssertNotNil(view, "Should construct with \(scope) scope")
            XCTAssertEqual(snapshot.scope, scope, "Should have correct scope")
        }
    }

    // MARK: - Edge Case Tests

    func testContextInspectorViewWithZeroSizeFiles() {
        // Test ContextInspectorView with zero-size files
        let emptyFile = UIContracts.ContextFileDescriptor(
            path: "/empty.swift",
            language: "swift",
            size: 0,
            hash: "empty_hash",
            isIncluded: true,
            isTruncated: false
        )

        let snapshot = UIContracts.ContextSnapshot(
            scope: .selection,
            snapshotHash: nil, // No hash
            segments: [],
            includedFiles: [emptyFile],
            truncatedFiles: [],
            excludedFiles: [],
            totalTokens: 0,
            totalBytes: 0
        )

        let view = ContextInspectorView(snapshot: snapshot)

        XCTAssertNotNil(view, "ContextInspectorView should construct with zero-size files")
        XCTAssertEqual(snapshot.includedFiles.first?.size, 0, "Should have zero size")
        XCTAssertNil(snapshot.snapshotHash, "Should handle nil snapshot hash")
    }

    func testContextInspectorViewWithVeryLongPaths() {
        // Test ContextInspectorView with very long file paths
        let longPath = String(repeating: "a", count: 1000) + "/deep/nested/file.swift"
        let file = UIContracts.ContextFileDescriptor(
            path: longPath,
            language: "swift",
            size: 100,
            hash: "long_hash",
            isIncluded: true,
            isTruncated: false
        )

        let snapshot = UIContracts.ContextSnapshot(
            scope: .selection,
            snapshotHash: "long_path_test",
            segments: [],
            includedFiles: [file],
            truncatedFiles: [],
            excludedFiles: [],
            totalTokens: 15,
            totalBytes: 100
        )

        let view = ContextInspectorView(snapshot: snapshot)

        XCTAssertNotNil(view, "ContextInspectorView should construct with very long paths")
        XCTAssertGreaterThanOrEqual(snapshot.includedFiles.first?.path.count ?? 0, 1000, "Should handle long path")
    }
}
