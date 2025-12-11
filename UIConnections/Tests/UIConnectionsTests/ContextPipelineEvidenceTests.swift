import XCTest
import Foundation
import UIConnections
import AppCoreEngine
import AppAdapters

/// Evidence-only harness to dump context pipeline + interaction traces without modifying production code.
final class ContextPipelineEvidenceTests: XCTestCase {
    func test_context_pipeline_and_interaction_trace() async throws {
        // 1) Build a non-trivial workspace in a temp directory (mixed file types).
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("entelechia-context-evidence-\(UUID().uuidString)")
        try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        let sourcePaths = [
            "AppCoreEngine/Sources/CoreEngine/Conversations/ConversationService.swift",
            "AppAdapters/Sources/AppAdapters/AI/RetryPolicy.swift",
            "UIConnections/Sources/UIConnections/Workspaces/FileTypeClassifier.swift"
        ].map { "/Users/johangunnarsson/Developer/entelechia-chat/\($0)" }

        for path in sourcePaths {
            let url = URL(fileURLWithPath: path)
            let dest = tempRoot.appendingPathComponent(url.lastPathComponent)
            try fm.copyItem(at: url, to: dest)
        }
        let notePath = tempRoot.appendingPathComponent("notes.txt")
        try "Context evidence note.\nLine two.\n".write(to: notePath, atomically: true, encoding: .utf8)

        let targetPath = tempRoot.appendingPathComponent("ConversationService.swift").path

        // 2) Construct engine with real adapters + no-op watcher.
        let fileSystem = FileSystemAccessAdapter()
        let preferences = PreferencesStoreAdapter<WorkspacePreferences>(strict: false)
        let contextPrefs = ContextPreferencesStoreAdapter<WorkspaceContextPreferencesState>(strict: false)
        let watcher = NoopWatcher()
        let engine = WorkspaceEngineImpl(
            fileSystem: fileSystem,
            preferences: preferences,
            contextPreferences: contextPrefs,
            watcher: watcher
        )

        // 3) Capture snapshots twice to prove determinism.
        let snap1 = try await engine.openWorkspace(rootPath: tempRoot.path)
        let selectedSnap = try await engine.select(path: targetPath)
        let snap2 = try await engine.refresh()
        XCTAssertEqual(snap1.snapshotHash, snap2.snapshotHash, "Snapshot hash should be stable")

        // 4) Boundary filter trace.
        let boundary = DefaultWorkspaceBoundaryFilter()
        let rawEntries = try fm.contentsOfDirectory(atPath: tempRoot.path)
            .map { tempRoot.appendingPathComponent($0).path }
            .sorted()
        let excluded = rawEntries.filter { !boundary.allows(canonicalPath: $0) }

        print("=== CONTEXT EVIDENCE: SNAPSHOT ===")
        printSnapshot(selectedSnap)
        print("=== CONTEXT EVIDENCE: BOUNDARY ===")
        print("Excluded by boundary:", excluded)

        // 5) Context build + segmentation.
        let fileLoader = FileContentLoaderAdapter()
        let preparer = WorkspaceContextPreparer(fileLoader: fileLoader)
        let contextResult = try await preparer.prepare(snapshot: selectedSnap, preferredDescriptorIDs: nil, budget: .default)
        let encoder = WorkspaceContextEncoder()
        let encoded = encoder.encode(files: contextResult.attachments)
        let segmenter = WorkspaceContextSegmenter()
        let segments = segmenter.segment(files: encoded)

        print("=== CONTEXT EVIDENCE: SEGMENTS ===")
        for (idx, segment) in segments.enumerated() {
            print("Segment \(idx + 1): bytes=\(segment.totalBytes) tokens=\(segment.totalTokens)")
            for file in segment.files {
                print("  File:", file.path)
                print("    size:", file.size, "tokens:", file.tokenEstimate, "hash:", file.hash, "lang:", file.language ?? "nil")
                let preview = file.content.split(separator: "\n").prefix(5).joined(separator: "\n")
                print("    preview:\n\(preview)\n---")
            }
        }

        // 6) CodexService interaction path with stubbed client (read-only stream).
        let mutationAuthority = FileMutationAuthority()
        let streamRecorder = StreamRecorder()
        let conversationEngine = StubConversationEngine()
        let codexService = CodexService(
            conversationEngine: conversationEngine,
            workspaceEngine: engine,
            codexClient: AnyCodexClient { messages, contextFiles in
                await streamRecorder.add(messages: messages, contextFiles: contextFiles)
                let aggregate = messages.map { $0.text }.joined(separator: "\n---\n")
                return AsyncThrowingStream { continuation in
                    continuation.yield(.token("Echo: "))
                    continuation.yield(.output(ModelResponse(content: aggregate)))
                    continuation.yield(.done)
                    continuation.finish()
                }
            },
            fileLoader: fileLoader,
            retryPolicy: RetryPolicyImpl(),
            mutationAuthority: mutationAuthority
        )

        print("=== INTERACTION TRACE: INPUT ===")
        print("Question: What does ConversationService do?")
        print("Selected path:", targetPath)

        var streamLog: [String] = []
        let answer = try await codexService.askAboutWorkspaceNode(
            scope: WorkspaceScope.selection,
            question: "What does ConversationService do?"
        ) { aggregate in
            streamLog.append(aggregate)
            print("→ streamed chunk:", aggregate)
        }

        print("=== INTERACTION TRACE: FINAL OUTPUT ===")
        print(answer.text)
        print("=== INTERACTION TRACE: CONTEXT FILES SENT ===")
        for file in answer.context.attachments {
            print("File:", file.url.path, "bytes:", file.byteCount, "tokens:", file.tokenEstimate)
        }

        // 7) Mutation pipeline verification (read-only).
        let streamCallCount = await streamRecorder.count
        XCTAssertEqual(streamCallCount, 1, "Expected one stream call, no mutations")
    }

    private func printSnapshot(_ snapshot: WorkspaceSnapshot) {
        print("rootPath:", snapshot.rootPath ?? "nil")
        print("selectedPath:", snapshot.selectedPath ?? "nil")
        print("lastPersistedSelection:", snapshot.lastPersistedSelection ?? "nil")
        print("snapshotHash:", snapshot.snapshotHash)
        print("descriptors (\(snapshot.descriptors.count)):")
        for descriptor in snapshot.descriptors {
            print("  id:\(descriptor.id.rawValue) name:\(descriptor.name) type:\(descriptor.type)")
            print("    canonicalPath:", descriptor.canonicalPath)
            print("    language:", descriptor.language ?? "nil", "size:", descriptor.size, "hash:", descriptor.hash)
            print("    children:", descriptor.children)
        }
        print("descriptorPaths (\(snapshot.descriptorPaths.count)):")
        for (id, path) in snapshot.descriptorPaths.sorted(by: { $0.value < $1.value }) {
            print("  \(id.rawValue) -> \(path)")
        }
        print("contextInclusions:", snapshot.contextInclusions)
    }
}

// MARK: - Test doubles

private final class NoopWatcher: FileSystemWatching {
    func watch(rootPath: String) -> AsyncStream<Void> {
        AsyncStream { continuation in
            continuation.onTermination = { _ in }
        }
    }
}

private final class StubConversationEngine: ConversationStreaming {
    func conversation(for url: URL) async -> Conversation? { nil }
    func conversation(forDescriptorIDs ids: [FileID]) async -> Conversation? { nil }
    func ensureConversation(for url: URL) async throws -> Conversation {
        Conversation(contextFilePaths: [url.path])
    }
    func ensureConversation(forDescriptorIDs ids: [FileID], pathResolver: (FileID) -> String?) async throws -> Conversation {
        Conversation(contextFilePaths: ids.compactMap(pathResolver), contextDescriptorIDs: ids)
    }
    func updateContextDescriptors(for conversationID: UUID, descriptorIDs: [FileID]?) async throws {}
    func sendMessage(
        _ text: String,
        in conversation: Conversation,
        context: ConversationContextRequest?,
        onStream: ((ConversationDelta) -> Void)?
    ) async throws -> (Conversation, ContextBuildResult) {
        onStream?(.assistantStreaming(text))
        onStream?(.assistantCommitted(Message(role: .assistant, text: text)))
        return (conversation, ContextBuildResult(attachments: [], truncatedFiles: [], excludedFiles: [], totalBytes: 0, totalTokens: 0, budget: .default))
    }
}

private actor StreamRecorder {
    private(set) var calls: [(messages: [Message], contextFiles: [LoadedFile])] = []

    func add(messages: [Message], contextFiles: [LoadedFile]) {
        calls.append((messages, contextFiles))
    }

    var count: Int { calls.count }
}


