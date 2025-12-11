import XCTest
import AppCoreEngine
import AppAdapters
@testable import UIConnections

final class CodexServiceTests: XCTestCase {

    func testAskAboutWorkspaceNodeSuccess() async throws {
        let (service, recorder) = makeService(streamPlan: [.success(tokens: ["Hello", " world"], output: nil)])
        let answer = try await service.askAboutWorkspaceNode(scope: .selection, question: "Hi")
        XCTAssertEqual(answer.text, "Hello world")
        XCTAssertEqual(recorder.recordedMessages.count, 1)
    }

    func testAskAboutWorkspaceNodeRetriesAfterFailure() async throws {
        let (service, recorder) = makeService(streamPlan: [.failure(StreamTransportError.invalidResponse("bad")), .success(tokens: ["Ok"], output: nil)], maxRetries: 1)
        let answer = try await service.askAboutWorkspaceNode(scope: .selection, question: "Retry?")
        XCTAssertEqual(answer.text, "Ok")
        XCTAssertEqual(recorder.recordedMessages.count, 2)
    }

    func testAskAboutWorkspaceNodeCancellationStopsStreaming() async {
        let (service, _) = makeService(streamPlan: [.delayedSuccess(tokens: ["long"], delayNanos: 2_000_000_000)])
        let task = Task {
            try await service.askAboutWorkspaceNode(scope: .selection, question: "Cancel?")
        }
        task.cancel()
        await XCTAssertThrowsErrorAsync {
            _ = try await task.value
        }
    }

    // MARK: - Helpers
    private func makeService(
        streamPlan: [FakeCodexClient.StreamPlan],
        maxRetries: Int = 0
    ) -> (CodexService, FakeCodexClient) {
        let snapshot = WorkspaceSnapshot(
            rootPath: "/root",
            selectedPath: "/root/a.txt",
            lastPersistedSelection: "/root/a.txt",
            selectedDescriptorID: FileID(),
            lastPersistedDescriptorID: nil,
            contextPreferences: .empty,
            descriptorPaths: [:],
            contextInclusions: [:],
            descriptors: []
        )
        let descriptorID = snapshot.selectedDescriptorID!
        let fileDescriptor = FileDescriptor(
            id: descriptorID,
            name: "a.txt",
            type: .file,
            children: [],
            canonicalPath: "/root/a.txt",
            language: "text/plain",
            size: 7,
            hash: "hash"
        )
        let enrichedSnapshot = WorkspaceSnapshot(
            rootPath: "/root",
            selectedPath: "/root/a.txt",
            lastPersistedSelection: "/root/a.txt",
            selectedDescriptorID: descriptorID,
            lastPersistedDescriptorID: descriptorID,
            contextPreferences: .empty,
            descriptorPaths: [descriptorID: "/root/a.txt"],
            contextInclusions: [descriptorID: .included],
            descriptors: [fileDescriptor]
        )

        let workspace = WorkspaceEngineProbe(snapshot: enrichedSnapshot)
        let codexClient = FakeCodexClient(plan: streamPlan)
        let fileLoader = StubFileLoader()
        let service = CodexService(
            conversationEngine: ConversationEngineStub(),
            workspaceEngine: workspace,
            codexClient: AnyCodexClient { messages, files in
                try await codexClient.stream(messages: messages, contextFiles: files)
            },
            fileLoader: fileLoader,
            contextSegmenter: WorkspaceContextSegmenter(),
            retryPolicy: RetryPolicy(maxRetries: maxRetries),
            mutationAuthority: DummyMutationAuthority()
        )
        return (service, codexClient)
    }
}

// MARK: - Fakes/Stubs

private final class WorkspaceEngineProbe: WorkspaceEngine, @unchecked Sendable {
    private let snap: WorkspaceSnapshot
    init(snapshot: WorkspaceSnapshot) {
        self.snap = snapshot
    }
    func openWorkspace(rootPath: String) async throws -> WorkspaceSnapshot { snap }
    func snapshot() async -> WorkspaceSnapshot { snap }
    func refresh() async throws -> WorkspaceSnapshot { snap }
    func select(path: String?) async throws -> WorkspaceSnapshot { snap }
    func contextPreferences() async throws -> WorkspaceSnapshot { snap }
    func setContextInclusion(path: String, included: Bool) async throws -> WorkspaceSnapshot { snap }
    func treeProjection() async -> WorkspaceTreeProjection? { nil }
    func updates() -> AsyncStream<WorkspaceUpdate> { AsyncStream { $0.finish() } }
}

private final class StubFileLoader: FileContentLoading {
    func load(url: URL) async throws -> String { "content" }
}

private final class DummyMutationAuthority: FileMutationAuthorizing {
    func apply(diffs: [FileDiff], rootPath: String) throws -> [AppliedPatchResult] { [] }
}

private final class FakeCodexClient: CodexClient, @unchecked Sendable {
    typealias MessageType = Message
    typealias ContextFileType = LoadedFile
    typealias OutputPayload = ModelResponse
    struct StreamPlan {
        enum Kind {
            case success(tokens: [String], output: String?)
            case delayedSuccess(tokens: [String], delayNanos: UInt64)
            case failure(Error)
        }
        let kind: Kind

        static func success(tokens: [String], output: String? = nil) -> StreamPlan {
            StreamPlan(kind: .success(tokens: tokens, output: output))
        }

        static func delayedSuccess(tokens: [String], delayNanos: UInt64) -> StreamPlan {
            StreamPlan(kind: .delayedSuccess(tokens: tokens, delayNanos: delayNanos))
        }

        static func failure(_ error: Error) -> StreamPlan {
            StreamPlan(kind: .failure(error))
        }
    }

    private var plans: [StreamPlan]
    var recordedMessages: [[Message]] = []

    init(plan: [StreamPlan]) {
        self.plans = plan
    }

    func stream(messages: [Message], contextFiles: [LoadedFile]) async throws -> AsyncThrowingStream<StreamChunk<ModelResponse>, Error> {
        recordedMessages.append(messages)
        guard !plans.isEmpty else { throw StreamTransportError.invalidResponse("no plan") }
        let plan = plans.removeFirst()
        switch plan.kind {
        case .failure(let error):
            throw error
        case .success(let tokens, let output):
            return AsyncThrowingStream { continuation in
                for token in tokens { continuation.yield(.token(token)) }
                if let output { continuation.yield(.output(ModelResponse(content: output))) }
                continuation.yield(.done)
                continuation.finish()
            }
        case .delayedSuccess(let tokens, let delay):
            return AsyncThrowingStream { continuation in
                Task {
                    try await Task.sleep(nanoseconds: delay)
                    for token in tokens { continuation.yield(.token(token)) }
                    continuation.yield(.done)
                    continuation.finish()
                }
            }
        }
    }
}

@discardableResult
private func XCTAssertThrowsErrorAsync(
    _ expression: @escaping () async throws -> Void,
    file: StaticString = #file,
    line: UInt = #line
) async -> Error? {
    do {
        try await expression()
        XCTFail("Expected error", file: file, line: line)
        return nil
    } catch {
        return error
    }
}

private final class ConversationEngineStub: ConversationStreaming {
    func conversation(for url: URL) async -> Conversation? { nil }
    func conversation(forDescriptorIDs ids: [FileID]) async -> Conversation? { nil }
    func ensureConversation(for url: URL) async throws -> Conversation { Conversation(contextFilePaths: [url.path]) }
    func ensureConversation(forDescriptorIDs ids: [FileID], pathResolver: (FileID) -> String?) async throws -> Conversation { Conversation(contextFilePaths: []) }
    func updateContextDescriptors(for conversationID: UUID, descriptorIDs: [FileID]?) async throws {}
    func sendMessage(_ text: String, in conversation: Conversation, context: ConversationContextRequest?, onStream: ((ConversationDelta) -> Void)?) async throws -> (Conversation, ContextBuildResult) {
        (conversation, ContextBuildResult(attachments: [], truncatedFiles: [], excludedFiles: [], totalBytes: 0, totalTokens: 0, budget: .default, encodedSegments: []))
    }
}


