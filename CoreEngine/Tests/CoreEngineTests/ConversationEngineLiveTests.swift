import XCTest
@testable import CoreEngine

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
        var events: [ConversationStreamEvent] = []
        let convo = try await engine.ensureConversation(for: url)
        let (updated, context) = try await engine.sendMessage(
            "hi",
            in: convo,
            contextURL: nil,
            onStream: { events.append($0) }
        )

        XCTAssertEqual(context.totalTokens, 0)
        XCTAssertEqual(events.count, 3) // context + two tokens + done
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
            _ = try await engine.sendMessage("   ", in: convo, contextURL: nil, onStream: nil)
        }
    }
}

// MARK: - Fakes

private final class FakeCodexClient: CodexClient {
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

private final class InMemoryConversationPersistence: ConversationPersistenceDriver {
    typealias ConversationType = Conversation
    var stored: [Conversation] = []
    var saved: [Conversation] = []

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

private func XCTAssertThrowsErrorAsync(_ block: @escaping () async throws -> Void) async {
    do {
        try await block()
        XCTFail("Expected error, got success")
    } catch {
        // expected
    }
}

