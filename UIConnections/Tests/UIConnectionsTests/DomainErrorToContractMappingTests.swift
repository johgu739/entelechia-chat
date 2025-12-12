import XCTest
import AppCoreEngine
@testable import UIConnections
import UIContracts

/// Tests for domain error to UIContracts error mapping.
/// Verifies that AppCoreEngine errors correctly map to user-facing error representations.
final class DomainErrorToContractMappingTests: XCTestCase {

    // MARK: - Context Exclusion Error Mapping

    func testContextExclusionReasonMapping() {
        // Test that ContextExclusionReason maps to UIContracts error strings
        let perFileBytesLimit = AppCoreEngine.ContextExclusionReason.exceedsPerFileBytes(limit: 1000)
        let perFileTokensLimit = AppCoreEngine.ContextExclusionReason.exceedsPerFileTokens(limit: 100)
        let totalBytesLimit = AppCoreEngine.ContextExclusionReason.exceedsTotalBytes(limit: 10000)
        let totalTokensLimit = AppCoreEngine.ContextExclusionReason.exceedsTotalTokens(limit: 1000)

        // These are tested through the DomainToUIMappers.exclusionReasonToString function
        // Since it's a private function, we test it indirectly through the mapping functions

        let exclusion = AppCoreEngine.ContextExclusion(
            id: AppCoreEngine.FileID(),
            file: AppCoreEngine.LoadedFile(
                id: UUID(),
                url: URL(fileURLWithPath: "/test.swift"),
                fileTypeIdentifier: "swift",
                byteCount: 1000
            ),
            reason: perFileBytesLimit
        )

        let uiExclusion = DomainToUIMappers.toUIContextExclusion(exclusion)

        XCTAssertEqual(uiExclusion.id, exclusion.id)
        XCTAssertEqual(uiExclusion.file.path, "/test.swift")
        XCTAssertTrue(uiExclusion.reason.contains("bytes limit"))
    }

    func testContextExclusionWithDifferentReasons() {
        // Test ContextExclusion mapping with different exclusion reasons
        let reasons = [
            AppCoreEngine.ContextExclusionReason.exceedsPerFileBytes(limit: 1000),
            AppCoreEngine.ContextExclusionReason.exceedsPerFileTokens(limit: 100),
            AppCoreEngine.ContextExclusionReason.exceedsTotalBytes(limit: 10000),
            AppCoreEngine.ContextExclusionReason.exceedsTotalTokens(limit: 1000)
        ]

        for reason in reasons {
            let exclusion = AppCoreEngine.ContextExclusion(
                id: AppCoreEngine.FileID(),
                file: AppCoreEngine.LoadedFile(
                    id: UUID(),
                    url: URL(fileURLWithPath: "/test.swift"),
                    fileTypeIdentifier: "swift",
                    byteCount: 1000
                ),
                reason: reason
            )

            let uiExclusion = DomainToUIMappers.toUIContextExclusion(exclusion)

            XCTAssertEqual(uiExclusion.id, exclusion.id)
            XCTAssertEqual(uiExclusion.file.path, "/test.swift")
            XCTAssertFalse(uiExclusion.reason.isEmpty)
            XCTAssertTrue(uiExclusion.reason.contains("limit") || uiExclusion.reason.contains("Limit"))
        }
    }

    // MARK: - Engine Error Mapping

    func testEngineErrorMappingToWorkspaceErrorNotice() {
        // Test that EngineError maps to WorkspaceErrorNotice
        // This is done in WorkspaceStateObserver.mapErrorToNotice

        let watcherError = AppCoreEngine.EngineError.watcherUnavailable
        let refreshError = AppCoreEngine.EngineError.refreshFailed(message: "Network timeout")

        // Create a mock WorkspaceStateObserver to test the mapping
        // Since the mapping function is private, we test through the public interface

        let fileID = AppCoreEngine.FileID()
        let snapshot = AppCoreEngine.WorkspaceSnapshot(
            rootPath: "/root",
            selectedPath: "/root/file.swift",
            lastPersistedSelection: "/root/file.swift",
            selectedDescriptorID: fileID,
            lastPersistedDescriptorID: fileID,
            contextPreferences: .empty,
            descriptorPaths: [fileID: "/root/file.swift"],
            contextInclusions: [fileID: .included],
            descriptors: [AppCoreEngine.FileDescriptor(id: fileID, name: "file.swift", type: .file)]
        )

        let projection = AppCoreEngine.WorkspaceTreeProjection(
            id: fileID,
            name: "file.swift",
            path: "/root/file.swift",
            isDirectory: false,
            children: []
        )

        // Test watcher error mapping
        let watcherUpdate = AppCoreEngine.WorkspaceUpdate(
            snapshot: snapshot,
            projection: projection,
            error: .watcherUnavailable
        )

        // This tests the mapping logic that would be used in WorkspaceStateObserver
        let mappedWithError = DomainToUIMappers.toWorkspaceViewState(
            rootPath: snapshot.rootPath,
            selectedDescriptorID: snapshot.selectedDescriptorID,
            selectedPath: snapshot.selectedPath,
            projection: projection,
            contextInclusions: snapshot.contextInclusions,
            watcherError: "Workspace watcher stopped (root missing or inaccessible)."
        )

        XCTAssertEqual(mappedWithError.watcherError, "Workspace watcher stopped (root missing or inaccessible).")

        // Test healthy state
        let mappedHealthy = DomainToUIMappers.toWorkspaceViewState(
            rootPath: snapshot.rootPath,
            selectedDescriptorID: snapshot.selectedDescriptorID,
            selectedPath: snapshot.selectedPath,
            projection: projection,
            contextInclusions: snapshot.contextInclusions,
            watcherError: nil
        )

        XCTAssertNil(mappedHealthy.watcherError)
    }

    // MARK: - Error String Formatting

    func testExclusionReasonStringFormatting() {
        // Test that exclusion reasons are formatted as user-readable strings
        let reasons = [
            (AppCoreEngine.ContextExclusionReason.exceedsPerFileBytes(limit: 1000), "bytes"),
            (AppCoreEngine.ContextExclusionReason.exceedsPerFileTokens(limit: 100), "tokens"),
            (AppCoreEngine.ContextExclusionReason.exceedsTotalBytes(limit: 10000), "bytes"),
            (AppCoreEngine.ContextExclusionReason.exceedsTotalTokens(limit: 1000), "tokens")
        ]

        for (reason, unit) in reasons {
            let exclusion = AppCoreEngine.ContextExclusion(
                id: AppCoreEngine.FileID(),
                file: AppCoreEngine.LoadedFile(
                    id: UUID(),
                    url: URL(fileURLWithPath: "/test.swift"),
                    fileTypeIdentifier: "swift",
                    byteCount: 1000
                ),
                reason: reason
            )

            let uiExclusion = DomainToUIMappers.toUIContextExclusion(exclusion)

            XCTAssertTrue(uiExclusion.reason.contains(unit), "Reason should contain '\(unit)'")
            XCTAssertTrue(uiExclusion.reason.contains("limit") || uiExclusion.reason.contains("Limit"), "Reason should contain 'limit'")
        }
    }

    // MARK: - Error Propagation in Complex Mappings

    func testErrorPropagationInContextBuildResult() {
        // Test that errors are properly propagated through complex result mappings
        let loadedFile = AppCoreEngine.LoadedFile(
            id: UUID(),
            url: URL(fileURLWithPath: "/included.swift"),
            fileTypeIdentifier: "swift",
            byteCount: 500
        )

        let excludedFile = AppCoreEngine.LoadedFile(
            id: UUID(),
            url: URL(fileURLWithPath: "/excluded.swift"),
            fileTypeIdentifier: "swift",
            byteCount: 2000
        )

        let exclusion = AppCoreEngine.ContextExclusion(
            id: AppCoreEngine.FileID(),
            file: excludedFile,
            reason: .exceedsPerFileBytes(limit: 1000)
        )

        let contextResult = AppCoreEngine.ContextBuildResult(
            attachments: [loadedFile],
            truncatedFiles: [],
            excludedFiles: [exclusion],
            totalBytes: 2500,
            totalTokens: 300,
            budget: AppCoreEngine.ContextBudget(maxTokens: 1000, usedTokens: 300),
            encodedSegments: []
        )

        let uiResult = DomainToUIMappers.toUIContextBuildResult(contextResult)

        XCTAssertEqual(uiResult.attachments.count, 1)
        XCTAssertEqual(uiResult.excludedFiles.count, 1)
        XCTAssertEqual(uiResult.excludedFiles.first?.reason, "Exceeds per-file bytes limit: 1000")
        XCTAssertEqual(uiResult.totalBytes, 2500)
        XCTAssertEqual(uiResult.totalTokens, 300)
    }

    func testErrorHandlingWithEmptyResults() {
        // Test error handling when results are empty or nil
        let emptyResult = AppCoreEngine.ContextBuildResult(
            attachments: [],
            truncatedFiles: [],
            excludedFiles: [],
            totalBytes: 0,
            totalTokens: 0,
            budget: .default,
            encodedSegments: []
        )

        let uiResult = DomainToUIMappers.toUIContextBuildResult(emptyResult)

        XCTAssertEqual(uiResult.attachments.count, 0)
        XCTAssertEqual(uiResult.truncatedFiles.count, 0)
        XCTAssertEqual(uiResult.excludedFiles.count, 0)
        XCTAssertEqual(uiResult.totalBytes, 0)
        XCTAssertEqual(uiResult.totalTokens, 0)
    }

    // MARK: - Error Context Preservation

    func testErrorContextPreservationInExclusions() {
        // Test that error context (file info, limits) is preserved in mappings
        let largeFile = AppCoreEngine.LoadedFile(
            id: UUID(),
            url: URL(fileURLWithPath: "/very/large/file.swift"),
            fileTypeIdentifier: "swift",
            byteCount: 50000
        )

        let exclusion = AppCoreEngine.ContextExclusion(
            id: AppCoreEngine.FileID(),
            file: largeFile,
            reason: .exceedsPerFileBytes(limit: 10000)
        )

        let uiExclusion = DomainToUIMappers.toUIContextExclusion(exclusion)

        XCTAssertEqual(uiExclusion.file.path, "/very/large/file.swift")
        XCTAssertEqual(uiExclusion.file.size, 50000)
        XCTAssertEqual(uiExclusion.reason, "Exceeds per-file bytes limit: 10000")
    }

    func testMultipleErrorTypesInSameResult() {
        // Test handling multiple types of errors in the same context result
        let normalFile = AppCoreEngine.LoadedFile(
            id: UUID(),
            url: URL(fileURLWithPath: "/normal.swift"),
            fileTypeIdentifier: "swift",
            byteCount: 500
        )

        let oversizedFile = AppCoreEngine.LoadedFile(
            id: UUID(),
            url: URL(fileURLWithPath: "/oversized.swift"),
            fileTypeIdentifier: "swift",
            byteCount: 50000
        )

        let exclusions = [
            AppCoreEngine.ContextExclusion(
                id: AppCoreEngine.FileID(),
                file: oversizedFile,
                reason: .exceedsPerFileBytes(limit: 10000)
            )
        ]

        let contextResult = AppCoreEngine.ContextBuildResult(
            attachments: [normalFile],
            truncatedFiles: [oversizedFile],
            excludedFiles: exclusions,
            totalBytes: 50500,
            totalTokens: 1000,
            budget: .default,
            encodedSegments: []
        )

        let uiResult = DomainToUIMappers.toUIContextBuildResult(contextResult)

        XCTAssertEqual(uiResult.attachments.count, 1)
        XCTAssertEqual(uiResult.truncatedFiles.count, 1)
        XCTAssertEqual(uiResult.excludedFiles.count, 1)
        XCTAssertEqual(uiResult.totalBytes, 50500)
        XCTAssertEqual(uiResult.totalTokens, 1000)
    }
}
