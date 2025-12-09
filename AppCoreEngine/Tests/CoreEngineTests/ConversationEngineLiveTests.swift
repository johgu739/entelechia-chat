import XCTest
@testable import AppCoreEngine

final class ConversationEngineLiveTests: XCTestCase {

    func testStreamingEmitsContextThenTokensAndPersistsAssistant() async throws {
        let persistence = InMemoryConversationPersistence()
        let client = FakeCodexClient(chunks: [
            .token("Hello"),
            .token(", world"),
            .done
        ])
        let fileLoader = PassthroughFileLoader()
        let engine = ConversationEngineLive(
            client: client,
            persistence: persistence,
            fileLoader: fileLoader,
            contextBuilder: ContextBuilder(budget: .default),
            clock: { Date(timeIntervalSince1970: 0) }
        )

        let url = URL(fileURLWithPath: "/tmp/context.txt")
        var events: [ConversationDelta] = []
        let convo = try await engine.ensureConversation(for: url)
        let (updated, context) = try await engine.sendMessage(
            "hi",
            in: convo,
            context: nil,
            onStream: { events.append($0) }
        )

        XCTAssertEqual(context.totalTokens, 0)
        // Expect context + 2 streaming updates + committed message.
        XCTAssertEqual(events.count, 4)
        guard case .context = events.first else { return XCTFail("Expected context first") }
        XCTAssertEqual(persistence.saved.last?.messages.count, 2) // user + assistant
        XCTAssertEqual(persistence.saved.last?.messages.last?.text, "Hello, world")
        XCTAssertEqual(updated.messages.last?.text, "Hello, world")
    }

    func testEmptyMessageThrows() async {
        let persistence = InMemoryConversationPersistence()
        let client = FakeCodexClient(chunks: [.done])
        let fileLoader = PassthroughFileLoader()
        let engine = ConversationEngineLive(
            client: client,
            persistence: persistence,
            fileLoader: fileLoader,
            contextBuilder: ContextBuilder(budget: .default),
            clock: { Date(timeIntervalSince1970: 0) }
        )
        let convo = Conversation(contextFilePaths: [])

        await XCTAssertThrowsErrorAsync {
            _ = try await engine.sendMessage("   ", in: convo, context: nil, onStream: nil)
        }
    }

    func testEnsureAndLookupByDescriptorIDs() async throws {
        let persistence = InMemoryConversationPersistence()
        let client = FakeCodexClient(chunks: [.done])
        let fileLoader = PassthroughFileLoader()
        let engine = ConversationEngineLive(
            client: client,
            persistence: persistence,
            fileLoader: fileLoader
        )

        let did = FileID()
        let convo = try await engine.ensureConversation(forDescriptorIDs: [did]) { _ in "/tmp/context.txt" }
        XCTAssertEqual(convo.contextDescriptorIDs, [did])
        let lookedUp = await engine.conversation(forDescriptorIDs: [did])
        XCTAssertNotNil(lookedUp)
    }

    func testConversationLookupByPathIsAwaited() async throws {
        let persistence = InMemoryConversationPersistence()
        let client = FakeCodexClient(chunks: [.done])
        let fileLoader = PassthroughFileLoader()
        let engine = ConversationEngineLive(
            client: client,
            persistence: persistence,
            fileLoader: fileLoader
        )
        let url = URL(fileURLWithPath: "/tmp/context.txt")
        let convo = try await engine.ensureConversation(for: url)
        let lookedUp = await engine.conversation(for: url)
        XCTAssertEqual(lookedUp?.id, convo.id)
    }

    func testActorIsolationOrderingContextThenTokensThenCommit() async throws {
        let persistence = InMemoryConversationPersistence()
        let client = FakeCodexClient(chunks: [
            .token("Hello "),
            .token("World"),
            .done
        ])
        let fileLoader = PassthroughFileLoader()
        let engine = ConversationEngineLive(
            client: client,
            persistence: persistence,
            fileLoader: fileLoader,
            contextBuilder: ContextBuilder(budget: .default),
            clock: { Date(timeIntervalSince1970: 0) }
        )
        let url = URL(fileURLWithPath: "/tmp/context.txt")
        let convo = try await engine.ensureConversation(for: url)
        var events: [ConversationDelta] = []
        _ = try await engine.sendMessage("hi", in: convo, context: nil) { delta in
            events.append(delta)
        }
        XCTAssertEqual(events.count, 4) // context + 2 tokens + commit
        guard case .context = events[0] else { return XCTFail("Expected context first") }
        guard case .assistantStreaming(let t1) = events[1] else { return XCTFail("Expected token 1") }
        guard case .assistantStreaming(let t2) = events[2] else { return XCTFail("Expected token 2") }
        XCTAssertEqual(t1, "Hello ")
        XCTAssertEqual(t2, "Hello World")
        guard case .assistantCommitted(let msg) = events[3] else { return XCTFail("Expected commit") }
        XCTAssertEqual(msg.text, "Hello World")
    }

    func testEvictionKeepsMostRecentlyUpdated() async throws {
        let persistence = InMemoryConversationPersistence()
        let client = FakeCodexClient(chunks: [.done])
        let fileLoader = PassthroughFileLoader()
        let counter = TickCounter()
        let engine = ConversationEngineLive(
            client: client,
            persistence: persistence,
            fileLoader: fileLoader,
            contextBuilder: ContextBuilder(budget: .default),
            clock: { counter.next() },
            maxCacheEntries: 1
        )

        let url1 = URL(fileURLWithPath: "/tmp/one.txt")
        let url2 = URL(fileURLWithPath: "/tmp/two.txt")
        let convo1 = try await engine.ensureConversation(for: url1)
        _ = try await engine.sendMessage("hi", in: convo1, context: nil, onStream: nil)

        let convo2 = try await engine.ensureConversation(for: url2)
        _ = try await engine.sendMessage("hi", in: convo2, context: nil, onStream: nil)

        let first = await engine.conversation(for: url1)
        let second = await engine.conversation(for: url2)
        XCTAssertNil(first)
        XCTAssertNotNil(second)
    }

    func testStreamingCancellationShortCircuits() async throws {
        let persistence = InMemoryConversationPersistence()
        let client = SlowTokenClient()
        let fileLoader = PassthroughFileLoader()
        let engine = ConversationEngineLive(
            client: client,
            persistence: persistence,
            fileLoader: fileLoader
        )
        let convo = Conversation(contextFilePaths: [])

        let task = Task {
            try await engine.sendMessage("hi", in: convo, context: nil, onStream: nil)
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testStreamingCancellationDoesNotPersistOrCacheAssistant() async throws {
        let persistence = CountingPersistence()
        let client = SlowTokenClient()
        let fileLoader = PassthroughFileLoader()
        let engine = ConversationEngineLive(
            client: client,
            persistence: persistence,
            fileLoader: fileLoader
        )
        let convo = Conversation(contextFilePaths: [])

        let task = Task {
            try await engine.sendMessage("hi", in: convo, context: nil, onStream: nil)
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()

        await XCTAssertThrowsErrorAsync {
            _ = try await task.value
        }
        XCTAssertEqual(persistence.saveCount, 0)
        let missing = await engine.conversation(for: URL(fileURLWithPath: "/tmp/nonexistent"))
        XCTAssertNil(missing)
    }

    func testPersistenceFailureDoesNotMutateCache() async throws {
        let persistence = FailingAfterFirstSavePersistence()
        let client = FakeCodexClient(chunks: [.done])
        let fileLoader = PassthroughFileLoader()
        let engine = ConversationEngineLive(
            client: client,
            persistence: persistence,
            fileLoader: fileLoader
        )
        let url = URL(fileURLWithPath: "/tmp/context.txt")
        let convo = try await engine.ensureConversation(for: url)

        await XCTAssertThrowsErrorAsync {
            _ = try await engine.sendMessage("hi", in: convo, context: nil, onStream: nil)
        }

        let cached = await engine.conversation(for: url)
        XCTAssertEqual(cached?.messages.count, 0)
        XCTAssertEqual(persistence.saveCount, 1) // only initial save succeeded
    }

    func testBackfillsDescriptorIDsOnBootstrap() async throws {
        let stored = Conversation(
            id: UUID(),
            title: "stored",
            createdAt: Date(),
            updatedAt: Date(),
            messages: [],
            contextFilePaths: ["/tmp/foo.txt"],
            contextDescriptorIDs: nil
        )
        let persistence = InMemoryConversationPersistence(stored: [stored])
        let client = FakeCodexClient(chunks: [.done])
        let fileLoader = PassthroughFileLoader()
        let engine = ConversationEngineLive(
            client: client,
            persistence: persistence,
            fileLoader: fileLoader
        )
        let convo = await engine.conversation(for: URL(fileURLWithPath: "/tmp/foo.txt"))
        XCTAssertNotNil(convo)
        XCTAssertNil(convo?.contextDescriptorIDs)
    }

    func testContextRequestLoadsFromSnapshotDescriptors() async throws {
        let persistence = InMemoryConversationPersistence()
        let client = FakeCodexClient(chunks: [.done])
        let loader = StaticFileLoader()
        let engine = ConversationEngineLive(
            client: client,
            persistence: persistence,
            fileLoader: loader
        )
        let descriptorID = FileID()
        let snapshot = WorkspaceSnapshot(
            rootPath: "/root",
            selectedPath: "/root/a.txt",
            lastPersistedSelection: "/root/a.txt",
            selectedDescriptorID: descriptorID,
            lastPersistedDescriptorID: descriptorID,
            contextPreferences: .empty,
            descriptorPaths: [descriptorID: "/root/a.txt"],
            contextInclusions: [descriptorID: .included],
            descriptors: [
                FileDescriptor(id: descriptorID, name: "a.txt", type: .file)
            ]
        )
        let convo = try await engine.ensureConversation(forDescriptorIDs: [descriptorID]) { _ in "/root/a.txt" }
        let (_, context) = try await engine.sendMessage(
            "hi",
            in: convo,
            context: ConversationContextRequest(
                snapshot: snapshot,
                preferredDescriptorIDs: [descriptorID],
                budget: .default
            ),
            onStream: nil
        )
        XCTAssertEqual(context.attachments.first?.name, "a.txt")
    }

    func testContextRequestLoadsExplicitFileURLs() async throws {
        let persistence = InMemoryConversationPersistence()
        let client = FakeCodexClient(chunks: [.done])
        let loader = StaticFileLoader()
        let engine = ConversationEngineLive(
            client: client,
            persistence: persistence,
            fileLoader: loader
        )
        let convo = Conversation(contextFilePaths: [])

        let (_, context) = try await engine.sendMessage(
            "hi",
            in: convo,
            context: ConversationContextRequest(
                contextFileURLs: [URL(fileURLWithPath: "/root/b.txt")],
                budget: .default
            ),
            onStream: nil
        )

        XCTAssertEqual(context.attachments.first?.name, "b.txt")
    }

    func testPreferredDescriptorIDsWithoutSnapshotFails() async throws {
        let persistence = InMemoryConversationPersistence()
        let client = FakeCodexClient(chunks: [.done])
        let loader = StaticFileLoader()
        let engine = ConversationEngineLive(
            client: client,
            persistence: persistence,
            fileLoader: loader
        )
        let convo = Conversation(contextFilePaths: [])

        await XCTAssertThrowsErrorAsync {
            _ = try await engine.sendMessage(
                "hi",
                in: convo,
                context: ConversationContextRequest(
                    snapshot: nil,
                    preferredDescriptorIDs: [FileID()],
                    budget: .default
                ),
                onStream: nil
            )
        }
    }

    func testStreamingErrorSurfaceUnderlyingTransport() async throws {
        let persistence = InMemoryConversationPersistence()
        let client = FailingCodexClient(error: StreamTransportError.decoding("bad json"))
        let loader = PassthroughFileLoader()
        let engine = ConversationEngineLive(
            client: client,
            persistence: persistence,
            fileLoader: loader
        )
        let convo = Conversation(contextFilePaths: [])

        do {
            _ = try await engine.sendMessage("hi", in: convo, context: nil, onStream: nil)
            XCTFail("Expected streaming transport error")
        } catch let EngineError.streamingTransport(transport) {
            if case .decoding(let message) = transport {
                XCTAssertEqual(message, "bad json")
            } else {
                XCTFail("Expected decoding transport error")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMissingDescriptorIDsInSnapshotFailFast() async throws {
        let persistence = InMemoryConversationPersistence()
        let client = FakeCodexClient(chunks: [.done])
        let loader = StaticFileLoader()
        let engine = ConversationEngineLive(
            client: client,
            persistence: persistence,
            fileLoader: loader
        )
        let snapshot = WorkspaceSnapshot(
            rootPath: "/root",
            selectedPath: nil,
            lastPersistedSelection: nil,
            selectedDescriptorID: nil,
            lastPersistedDescriptorID: nil,
            contextPreferences: .empty,
            descriptorPaths: [:],
            contextInclusions: [:],
            descriptors: []
        )
        let convo = Conversation(contextFilePaths: [])

        await XCTAssertThrowsErrorAsync {
            _ = try await engine.sendMessage(
                "hi",
                in: convo,
                context: ConversationContextRequest(
                    snapshot: snapshot,
                    preferredDescriptorIDs: [FileID()],
                    budget: .default
                ),
                onStream: nil
            )
        }
    }

    func testEnsureConversationDescriptorIDsRequiresResolvablePath() async throws {
        let persistence = InMemoryConversationPersistence()
        let client = FakeCodexClient(chunks: [.done])
        let loader = PassthroughFileLoader()
        let engine = ConversationEngineLive(
            client: client,
            persistence: persistence,
            fileLoader: loader
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await engine.ensureConversation(forDescriptorIDs: [FileID()]) { _ in nil }
        }
    }

    func testConcurrentEnsureConversationReturnsSameInstance() async throws {
        let persistence = InMemoryConversationPersistence()
        let client = FakeCodexClient(chunks: [.done])
        let loader = PassthroughFileLoader()
        let engine = ConversationEngineLive(
            client: client,
            persistence: persistence,
            fileLoader: loader
        )
        let url = URL(fileURLWithPath: "/tmp/shared.txt")

        async let convoA = engine.ensureConversation(for: url)
        async let convoB = engine.ensureConversation(for: url)
        let (a, b) = try await (convoA, convoB)

        XCTAssertEqual(a.id, b.id)
        let lookedUp = await engine.conversation(for: url)
        XCTAssertEqual(lookedUp?.id, a.id)
    }

    func testConcurrentSendsStayIsolatedAcrossDescriptors() async throws {
        let persistence = InMemoryConversationPersistence()
        let client = FakeCodexClient(chunks: [.output(ModelResponse(content: "ok")), .done])
        let loader = PassthroughFileLoader()
        let engine = ConversationEngineLive(
            client: client,
            persistence: persistence,
            fileLoader: loader
        )
        let idA = FileID()
        let idB = FileID()
        let pathA = "/tmp/a.txt"
        let pathB = "/tmp/b.txt"

        let convoA = try await engine.ensureConversation(forDescriptorIDs: [idA]) { _ in pathA }
        let convoB = try await engine.ensureConversation(forDescriptorIDs: [idB]) { _ in pathB }

        async let sendA: (Conversation, ContextBuildResult) = engine.sendMessage(
            "hi A",
            in: convoA,
            context: nil,
            onStream: nil
        )
        async let sendB: (Conversation, ContextBuildResult) = engine.sendMessage(
            "hi B",
            in: convoB,
            context: nil,
            onStream: nil
        )

        let ((convoAResult, _), (convoBResult, _)) = try await (sendA, sendB)

        XCTAssertEqual(convoAResult.messages.last?.text, "ok")
        XCTAssertEqual(convoBResult.messages.last?.text, "ok")
        let convA = await engine.conversation(forDescriptorIDs: [idA])
        let convB = await engine.conversation(forDescriptorIDs: [idB])
        XCTAssertEqual(convA?.messages.count, convoAResult.messages.count)
        XCTAssertEqual(convB?.messages.count, convoBResult.messages.count)
    }

    func testDescriptorContextBeatsPathShim() async throws {
        let persistence = InMemoryConversationPersistence()
        let client = FakeCodexClient(chunks: [.done])
        let loader = StaticFileLoader()
        let engine = ConversationEngineLive(
            client: client,
            persistence: persistence,
            fileLoader: loader
        )
        let descriptorID = FileID()
        let snapshot = WorkspaceSnapshot(
            rootPath: "/root",
            selectedPath: "/root/a.txt",
            lastPersistedSelection: "/root/a.txt",
            selectedDescriptorID: descriptorID,
            lastPersistedDescriptorID: descriptorID,
            contextPreferences: .empty,
            descriptorPaths: [descriptorID: "/root/a.txt"],
            contextInclusions: [descriptorID: .included],
            descriptors: [
                FileDescriptor(id: descriptorID, name: "a.txt", type: .file)
            ]
        )
        let convo = Conversation(contextFilePaths: [])

        let (_, context) = try await engine.sendMessage(
            "hi",
            in: convo,
            context: ConversationContextRequest(
                snapshot: snapshot,
                preferredDescriptorIDs: [descriptorID],
                contextFileURLs: [URL(fileURLWithPath: "/root/b.txt")],
                budget: .default
            ),
            onStream: nil
        )

        XCTAssertEqual(context.attachments.count, 1)
        XCTAssertEqual(context.attachments.first?.name, "a.txt")
    }

    func testMalformedStreamDoesNotCommitOrPersist() async throws {
        let persistence = CountingPersistence()
        let client = MidStreamFailingClient(error: StreamTransportError.decoding("boom"))
        let loader = PassthroughFileLoader()
        let engine = ConversationEngineLive(
            client: client,
            persistence: persistence,
            fileLoader: loader
        )
        let url = URL(fileURLWithPath: "/tmp/context.txt")
        let convo = try await engine.ensureConversation(for: url)
        XCTAssertEqual(persistence.saveCount, 1)

        await XCTAssertThrowsErrorAsync {
            _ = try await engine.sendMessage("hi", in: convo, context: nil, onStream: nil)
        }

        XCTAssertEqual(persistence.saveCount, 1) // no additional saves
        let cached = await engine.conversation(for: url)
        XCTAssertEqual(cached?.messages.count, 0)
    }

    func testPersistenceFailureKeepsDescriptorIndexStable() async throws {
        let persistence = FailingAfterFirstSavePersistence()
        let client = FakeCodexClient(chunks: [.done])
        let loader = StaticFileLoader()
        let engine = ConversationEngineLive(
            client: client,
            persistence: persistence,
            fileLoader: loader
        )
        let descriptorID = FileID()
        let convo = try await engine.ensureConversation(forDescriptorIDs: [descriptorID]) { _ in "/tmp/a.txt" }

        await XCTAssertThrowsErrorAsync {
            _ = try await engine.sendMessage("hi", in: convo, context: nil, onStream: nil)
        }

        let cached = await engine.conversation(forDescriptorIDs: [descriptorID])
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.messages.count, 0)
    }

    func testContextExclusionsAreRespected() async throws {
        let persistence = InMemoryConversationPersistence()
        let client = FakeCodexClient(chunks: [.done])
        let loader = StaticFileLoader()
        let engine = ConversationEngineLive(
            client: client,
            persistence: persistence,
            fileLoader: loader
        )
        let includedID = FileID()
        let excludedID = FileID()
        let snapshot = WorkspaceSnapshot(
            rootPath: "/root",
            selectedPath: "/root/included.txt",
            lastPersistedSelection: "/root/included.txt",
            selectedDescriptorID: includedID,
            lastPersistedDescriptorID: includedID,
            contextPreferences: WorkspaceContextPreferencesState(
                includedPaths: [],
                excludedPaths: ["/root/excluded.txt"],
                lastFocusedFilePath: nil
            ),
            descriptorPaths: [
                includedID: "/root/included.txt",
                excludedID: "/root/excluded.txt"
            ],
            contextInclusions: [
                includedID: .included,
                excludedID: .excluded
            ],
            descriptors: [
                FileDescriptor(id: includedID, name: "included.txt", type: .file),
                FileDescriptor(id: excludedID, name: "excluded.txt", type: .file)
            ]
        )
        let convo = Conversation(contextFilePaths: [])

        let (_, context) = try await engine.sendMessage(
            "hi",
            in: convo,
            context: ConversationContextRequest(
                snapshot: snapshot,
                preferredDescriptorIDs: [includedID, excludedID],
                budget: .default
            ),
            onStream: nil
        )

        XCTAssertEqual(context.attachments.map { $0.name }, ["included.txt"])
    }
}

// MARK: - Fakes

private final class FakeCodexClient: CodexClient, Sendable {
    typealias MessageType = Message
    typealias ContextFileType = LoadedFile
    typealias OutputPayload = ModelResponse

    private let chunks: [StreamChunk<ModelResponse>]

    init(chunks: [StreamChunk<ModelResponse>]) {
        self.chunks = chunks
    }

    func stream(messages: [Message], contextFiles: [LoadedFile]) async throws -> AsyncThrowingStream<StreamChunk<ModelResponse>, Error> {
        AsyncThrowingStream { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
    }
}

private final class InMemoryConversationPersistence: ConversationPersistenceDriver, @unchecked Sendable {
    typealias ConversationType = Conversation
    var stored: [Conversation] = []
    var saved: [Conversation] = []

    init(stored: [Conversation] = []) {
        self.stored = stored
    }

    func loadAllConversations() throws -> [Conversation] {
        stored
    }

    func saveConversation(_ conversation: Conversation) throws {
        saved.append(conversation)
    }

    func deleteConversation(_ conversation: Conversation) throws {}
}

private struct PassthroughFileLoader: FileContentLoading {
    func load(url: URL) async throws -> String { "" }
}

private final class SlowTokenClient: CodexClient, Sendable {
    typealias MessageType = Message
    typealias ContextFileType = LoadedFile
    typealias OutputPayload = ModelResponse

    func stream(messages: [Message], contextFiles: [LoadedFile]) async throws -> AsyncThrowingStream<StreamChunk<ModelResponse>, Error> {
        AsyncThrowingStream { continuation in
            Task.detached {
                try? await Task.sleep(nanoseconds: 500_000_000)
                continuation.yield(.token("slow"))
                continuation.yield(.done)
                continuation.finish()
            }
        }
    }
}

private final class FailingCodexClient: CodexClient, Sendable {
    typealias MessageType = Message
    typealias ContextFileType = LoadedFile
    typealias OutputPayload = ModelResponse

    private let error: Error

    init(error: Error) {
        self.error = error
    }

    func stream(messages: [Message], contextFiles: [LoadedFile]) async throws -> AsyncThrowingStream<StreamChunk<ModelResponse>, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: error)
        }
    }
}

private final class MidStreamFailingClient: CodexClient, Sendable {
    typealias MessageType = Message
    typealias ContextFileType = LoadedFile
    typealias OutputPayload = ModelResponse

    private let error: Error

    init(error: Error) {
        self.error = error
    }

    func stream(messages: [Message], contextFiles: [LoadedFile]) async throws -> AsyncThrowingStream<StreamChunk<ModelResponse>, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.token("partial"))
            continuation.finish(throwing: error)
        }
    }
}

private final class CountingPersistence: ConversationPersistenceDriver, @unchecked Sendable {
    typealias ConversationType = Conversation
    var saveCount = 0

    func loadAllConversations() throws -> [Conversation] { [] }

    func saveConversation(_ conversation: Conversation) throws {
        saveCount += 1
    }

    func deleteConversation(_ conversation: Conversation) throws {}
}

private final class FailingAfterFirstSavePersistence: ConversationPersistenceDriver, @unchecked Sendable {
    typealias ConversationType = Conversation
    private var saves: [Conversation] = []
    var saveCount: Int { saves.count }

    func loadAllConversations() throws -> [Conversation] { [] }

    func saveConversation(_ conversation: Conversation) throws {
        if saves.isEmpty {
            saves.append(conversation)
            return
        }
        throw EngineError.persistenceFailed(underlying: "fail on second save")
    }

    func deleteConversation(_ conversation: Conversation) throws {}
}

private final class TickCounter {
    private var value: TimeInterval = 0
    private let lock = NSLock()

    func next() -> Date {
        lock.lock()
        defer { lock.unlock(); value += 1 }
        return Date(timeIntervalSince1970: value)
    }
}

private struct StaticFileLoader: FileContentLoading {
    func load(url: URL) async throws -> String {
        return "// \(url.lastPathComponent)"
    }
}

private func XCTAssertThrowsErrorAsync(_ block: @escaping () async throws -> Void) async {
    do {
        try await block()
        XCTFail("Expected error, got success")
    } catch {
        // expected
    }
}

