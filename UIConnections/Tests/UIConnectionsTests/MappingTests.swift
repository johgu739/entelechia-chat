import XCTest
@testable import UIConnections
@testable import AppCoreEngine

final class MappingTests: XCTestCase {

    func testConversationViewStateAppliesContextThenStreamingThenCommit() {
        let initial = ConversationViewState(
            id: UUID(),
            messages: [],
            streamingText: "",
            lastContext: nil
        )

        let context = ContextBuildResult(
            attachments: [],
            truncatedFiles: [],
            excludedFiles: [],
            totalBytes: 0,
            totalTokens: 0,
            budget: .default
        )

        let afterContext = ConversationDeltaMapper.apply(to: initial, delta: .context(context))
        XCTAssertEqual(afterContext.lastContext, context)
        XCTAssertEqual(afterContext.streamingText, "")
        XCTAssertTrue(afterContext.messages.isEmpty)

        let afterStreaming = ConversationDeltaMapper.apply(to: afterContext, delta: .assistantStreaming("partial"))
        XCTAssertEqual(afterStreaming.streamingText, "partial")
        XCTAssertEqual(afterStreaming.lastContext, context)

        let committedMessage = Message(role: .assistant, text: "final")
        let afterCommit = ConversationDeltaMapper.apply(to: afterStreaming, delta: .assistantCommitted(committedMessage))
        XCTAssertEqual(afterCommit.streamingText, "")
        XCTAssertEqual(afterCommit.messages.last, committedMessage)
        XCTAssertEqual(afterCommit.lastContext, context)
    }

    func testWorkspaceViewStateMapperPropagatesErrorNoticeAndSnapshotFields() {
        let descriptorID = FileID()
        let snapshot = WorkspaceSnapshot(
            rootPath: "/root",
            selectedPath: "/root/file.swift",
            lastPersistedSelection: "/root/file.swift",
            selectedDescriptorID: descriptorID,
            lastPersistedDescriptorID: descriptorID,
            contextPreferences: .empty,
            descriptorPaths: [descriptorID: "/root/file.swift"],
            contextInclusions: [descriptorID: .included],
            descriptors: [FileDescriptor(id: descriptorID, name: "file.swift", type: .file)]
        )

        let projection = WorkspaceTreeProjection(
            id: descriptorID,
            name: "file.swift",
            path: "/root/file.swift",
            isDirectory: false,
            children: []
        )

        let update = WorkspaceUpdate(snapshot: snapshot, projection: projection, error: .watcherUnavailable)

        let mappedWithError = WorkspaceViewStateMapper.map(update: update, watcherError: .watcherUnavailable)
        XCTAssertEqual(mappedWithError.rootPath, "/root")
        XCTAssertEqual(mappedWithError.selectedDescriptorID, descriptorID)
        XCTAssertEqual(mappedWithError.selectedPath, "/root/file.swift")
        XCTAssertEqual(mappedWithError.projection?.path, "/root/file.swift")
        XCTAssertEqual(mappedWithError.contextInclusions[descriptorID], .included)
        XCTAssertEqual(mappedWithError.watcherError, "Workspace watcher stopped (root missing or inaccessible).")

        let mappedHealthy = WorkspaceViewStateMapper.map(update: update, watcherError: nil)
        XCTAssertNil(mappedHealthy.watcherError)
    }
}



