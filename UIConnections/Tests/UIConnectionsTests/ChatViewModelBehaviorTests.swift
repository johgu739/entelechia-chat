import XCTest
@testable import UIConnections
import AppCoreEngine

@MainActor
final class ChatViewModelBehaviorTests: XCTestCase {
    func testTypingTrimsButDoesNotClearAccidentally() async {
        let fakes = makeSubject()
        fakes.viewModel.text = "  hello  "
        let exp = expectation(description: "send completes")
        fakes.viewModel.send(conversation: Conversation()) {
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(fakes.workspace.sendCalls, ["hello"])
        XCTAssertFalse(fakes.viewModel.isSending)
        XCTAssertEqual(fakes.viewModel.text, "", "Text should clear after successful send.")
    }

    func testEmptyTextPreventsSend() {
        let fakes = makeSubject()
        fakes.viewModel.text = "   "
        fakes.viewModel.send(conversation: Conversation()) { XCTFail("Should not send") }
        XCTAssertTrue(fakes.workspace.sendCalls.isEmpty)
        XCTAssertFalse(fakes.viewModel.isSending)
    }

    func testModelChoicePropagatesToCoordinator() {
        let fakes = makeSubject()
        fakes.viewModel.setModelChoice(.stub)
        XCTAssertEqual(fakes.workspace.modelChanges.last, .stub)
    }

    func testScopeChoicePropagatesToWorkspace() {
        let fakes = makeSubject()
        fakes.viewModel.setScopeChoice(.workspace)
        XCTAssertEqual(fakes.workspace.scopeChanges.last, .workspace)
    }

    func testSendTogglesIsSendingAndClearsText() async {
        let fakes = makeSubject()
        fakes.viewModel.text = " send "
        let exp = expectation(description: "send complete")
        fakes.viewModel.send(conversation: Conversation()) {
            exp.fulfill()
        }
        XCTAssertTrue(fakes.viewModel.isSending)
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertFalse(fakes.viewModel.isSending)
        XCTAssertEqual(fakes.viewModel.text, "")
    }

    func testAskTogglesIsAskingAndClearsText() async {
        let fakes = makeSubject()
        fakes.viewModel.text = "question"
        let updated = Conversation(messages: [Message(role: .assistant, text: "ok")])
        fakes.workspace.askReturn = updated
        let exp = expectation(description: "ask complete")

        fakes.viewModel.askCodex(conversation: Conversation()) { convo in
            XCTAssertEqual(convo.messages.last?.text, "ok")
            exp.fulfill()
        }
        await Task.yield()
        XCTAssertTrue(fakes.viewModel.isAsking)
        fakes.workspace.completeAsk()
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertFalse(fakes.viewModel.isAsking)
        XCTAssertEqual(fakes.viewModel.text, "")
    }

    func testAskDisabledWhenNoContext() {
        let fakes = makeSubject()
        fakes.workspace.canAsk = false
        fakes.viewModel.text = "q"
        fakes.viewModel.askCodex(conversation: Conversation()) { _ in
            XCTFail("Should not ask without context")
        }
        XCTAssertTrue(fakes.workspace.askCalls.isEmpty)
        XCTAssertFalse(fakes.viewModel.isAsking)
    }

    // MARK: - Helpers
    private struct Fixtures {
        let viewModel: ChatViewModel
        let workspace: FakeWorkspaceViewModel
        let selection: ContextSelectionState
    }

    private func makeSubject() -> Fixtures {
        let selection = ContextSelectionState()
        let workspace = FakeWorkspaceViewModel()
        let coordinator = ConversationCoordinator(workspace: workspace, contextSelection: selection)
        let viewModel = ChatViewModel(coordinator: coordinator, contextSelection: selection)
        return Fixtures(viewModel: viewModel, workspace: workspace, selection: selection)
    }
}

@MainActor
private final class FakeWorkspaceViewModel: ConversationWorkspaceHandling {
    private(set) var sendCalls: [String] = []
    private(set) var askCalls: [String] = []
    private(set) var modelChanges: [ModelChoice] = []
    private(set) var scopeChanges: [ContextScopeChoice] = []
    var canAsk = true
    var askReturn: Conversation = Conversation()

    private var sendContinuation: CheckedContinuation<Void, Never>?
    private var askContinuation: CheckedContinuation<Conversation, Never>?

    func sendMessage(_ text: String, for conversation: Conversation) async {
        sendCalls.append(text)
        try? await Task.sleep(nanoseconds: 10_000_000)
    }

    func askCodex(_ text: String, for conversation: Conversation) async -> Conversation {
        askCalls.append(text)
        return await withCheckedContinuation { continuation in
            askContinuation = continuation
        }
    }

    func setContextScope(_ scope: ContextScopeChoice) {
        scopeChanges.append(scope)
    }

    func setModelChoice(_ model: ModelChoice) {
        modelChanges.append(model)
    }

    func canAskCodex() -> Bool { canAsk }

    func completeSend() {
        // no-op with async sleep simulation
    }

    func completeAsk() {
        if let continuation = askContinuation {
            continuation.resume(returning: askReturn)
            askContinuation = nil
        }
    }
}
