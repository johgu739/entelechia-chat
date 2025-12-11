import XCTest
@testable import UIConnections
import AppCoreEngine

@MainActor
final class ConversationCoordinatorTests: XCTestCase {
    func testSendMessageRoutesToWorkspace() async {
        let workspace = TrackingWorkspace()
        let selection = ContextSelectionState()
        let coordinator = ConversationCoordinator(workspace: workspace, contextSelection: selection)
        let convo = Conversation()

        await coordinator.sendMessage("hello", in: convo)

        XCTAssertEqual(workspace.sentMessages, ["hello"])
        XCTAssertEqual(workspace.sentConversations.count, 1)
        XCTAssertEqual(workspace.sentConversations.first?.id, convo.id)
    }

    func testAskCodexRoutesAndReturnsUpdatedConversation() async {
        let workspace = TrackingWorkspace()
        let selection = ContextSelectionState()
        let coordinator = ConversationCoordinator(workspace: workspace, contextSelection: selection)
        let original = Conversation(messages: [Message(role: .user, text: "q")])
        let updated = Conversation(messages: [Message(role: .assistant, text: "a")])
        workspace.askResponse = updated

        let result = await coordinator.askCodex("question", in: original)

        XCTAssertEqual(workspace.askMessages, ["question"])
        XCTAssertEqual(result.messages.last?.text, "a")
    }

    func testCoordinatorDoesNotMutateFileSystemDuringAsk() async {
        let workspace = TrackingWorkspace()
        let selection = ContextSelectionState()
        let coordinator = ConversationCoordinator(workspace: workspace, contextSelection: selection)

        _ = await coordinator.askCodex("question", in: Conversation())

        XCTAssertEqual(workspace.mutationAttempts, 0, "Coordinator must not mutate filesystem during ask.")
    }
}

// MARK: - Test doubles
@MainActor
private final class TrackingWorkspace: ConversationWorkspaceHandling {
    private(set) var sentMessages: [String] = []
    private(set) var sentConversations: [Conversation] = []
    private(set) var askMessages: [String] = []
    var askResponse: Conversation = Conversation()
    var mutationAttempts = 0

    func sendMessage(_ text: String, for conversation: Conversation) async {
        sentMessages.append(text)
        sentConversations.append(conversation)
    }

    func askCodex(_ text: String, for conversation: Conversation) async -> Conversation {
        askMessages.append(text)
        return askResponse
    }

    func setContextScope(_ scope: ContextScopeChoice) {}
    func setModelChoice(_ model: ModelChoice) {}
    func canAskCodex() -> Bool { true }
}
