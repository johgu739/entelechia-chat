import XCTest
import AppCoreEngine
@testable import UIConnections

@MainActor
final class ChatViewModelTests: XCTestCase {
    
    func testInitializationDefaults() {
        let fakes = makeSubject()
        XCTAssertEqual(fakes.viewModel.text, "")
        XCTAssertFalse(fakes.viewModel.isSending)
        XCTAssertFalse(fakes.viewModel.isAsking)
        XCTAssertEqual(fakes.viewModel.model, .codex)
        XCTAssertEqual(fakes.viewModel.contextScope, .selection)
    }
    
    func testSetModelChoicePublishesAndInformsWorkspace() {
        let fakes = makeSubject()
        fakes.viewModel.setModelChoice(.stub)
        XCTAssertEqual(fakes.viewModel.model, .stub)
        XCTAssertEqual(fakes.workspace.modelChanges.last, .stub)
    }
    
    func testSetScopeChoicePublishesAndInformsWorkspace() {
        let fakes = makeSubject()
        fakes.viewModel.setScopeChoice(.workspace)
        XCTAssertEqual(fakes.viewModel.contextScope, .workspace)
        XCTAssertEqual(fakes.workspace.scopeChanges.last, .workspace)
    }
    
    func testClearTextResetsMessageField() {
        let fakes = makeSubject()
        fakes.viewModel.text = "hello"
        fakes.viewModel.clearText()
        XCTAssertEqual(fakes.viewModel.text, "")
    }
    
    func testSendCallsWorkspaceOnceAndTogglesSending() async {
        let fakes = makeSubject()
        fakes.viewModel.text = "   hello  "
        let completion = expectation(description: "send completion")
        
        fakes.viewModel.send(conversation: Conversation()) {
            completion.fulfill()
        }
        await Task.yield()
        
        XCTAssertEqual(fakes.workspace.sendCalls, ["hello"])
        XCTAssertTrue(fakes.viewModel.isSending)
        
        fakes.workspace.completeSend()
        await fulfillment(of: [completion], timeout: 1.0)
        XCTAssertFalse(fakes.viewModel.isSending)
        XCTAssertEqual(fakes.viewModel.text, "")
    }
    
    func testSendIgnoredForWhitespaceText() {
        let fakes = makeSubject()
        fakes.viewModel.text = "   "
        fakes.viewModel.send(conversation: Conversation()) { }
        XCTAssertTrue(fakes.workspace.sendCalls.isEmpty)
        XCTAssertFalse(fakes.viewModel.isSending)
    }
    
    func testAskCodexCallsWorkspaceAndTogglesState() async {
        let fakes = makeSubject()
        fakes.viewModel.text = "question"
        let updated = Conversation(messages: [Message(role: .assistant, text: "ok")])
        let completion = expectation(description: "ask completion")
        
        fakes.viewModel.askCodex(conversation: Conversation()) { convo in
            XCTAssertEqual(convo.messages.last?.text, "ok")
            completion.fulfill()
        }
        await Task.yield()
        
        XCTAssertEqual(fakes.workspace.askCalls, ["question"])
        XCTAssertTrue(fakes.viewModel.isAsking)
        
        fakes.workspace.completeAsk(with: updated)
        await fulfillment(of: [completion], timeout: 1.0)
        XCTAssertFalse(fakes.viewModel.isAsking)
        XCTAssertEqual(fakes.viewModel.text, "")
    }
    
    func testAskCodexNoSelectionDoesNothing() {
        let fakes = makeSubject()
        fakes.workspace.canAsk = false
        fakes.viewModel.text = "blocked"
        fakes.viewModel.askCodex(conversation: Conversation()) { _ in
            XCTFail("Should not ask when selection missing")
        }
        XCTAssertTrue(fakes.workspace.askCalls.isEmpty)
        XCTAssertFalse(fakes.viewModel.isAsking)
    }
    
    // MARK: - Helpers
    private func makeSubject() -> (viewModel: ChatViewModel, workspace: FakeWorkspaceViewModel, selection: ContextSelectionState) {
        let selection = ContextSelectionState()
        let workspace = FakeWorkspaceViewModel()
        let coordinator = ConversationCoordinator(workspace: workspace, contextSelection: selection)
        let viewModel = ChatViewModel(coordinator: coordinator, contextSelection: selection)
        return (viewModel, workspace, selection)
    }
}

@MainActor
private final class FakeWorkspaceViewModel: ConversationWorkspaceHandling {
    private(set) var sendCalls: [String] = []
    private(set) var askCalls: [String] = []
    private(set) var modelChanges: [ModelChoice] = []
    private(set) var scopeChanges: [ContextScopeChoice] = []
    var canAsk = true
    var lastContextSnapshot: ContextSnapshot?
    
    private var sendContinuation: CheckedContinuation<Void, Never>?
    private var askContinuation: CheckedContinuation<Conversation, Never>?
    
    func sendMessage(_ text: String, for conversation: Conversation) async {
        sendCalls.append(text)
        await withCheckedContinuation { continuation in
            sendContinuation = continuation
        }
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
        sendContinuation?.resume(returning: ())
        sendContinuation = nil
    }
    
    func completeAsk(with conversation: Conversation) {
        askContinuation?.resume(returning: conversation)
        askContinuation = nil
    }
}
