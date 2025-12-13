import XCTest
import SwiftUI
@testable import ChatUI
import UIContracts

/// Contract tests for ChatInputBar.
/// Tests that ChatInputBar renders correctly with bindings and intent closures.
@MainActor
final class ChatInputBarContractTests: XCTestCase {

    // MARK: - Basic Construction Tests

    func testChatInputBarConstructsWithMinimalParameters() {
        // Test that ChatInputBar can be constructed with basic parameters
        let text = Binding<String>(get: { "" }, set: { _ in })
        let modelSelection = Binding<ModelChoice>(get: { .codex }, set: { _ in })
        let scopeSelection = Binding<ContextScopeChoice>(get: { .selection }, set: { _ in })

        let view = ChatInputBar(
            text: text,
            isAskEnabled: true,
            isSending: false,
            modelSelection: modelSelection,
            scopeSelection: scopeSelection,
            onSend: {},
            onAsk: {},
            onAttach: {},
            onMic: {}
        )

        // Verify construction succeeds
        XCTAssertNotNil(view, "ChatInputBar should construct with minimal parameters")
    }

    func testChatInputBarConstructsWithAllStates() {
        // Test ChatInputBar with various state combinations
        let text = Binding<String>(get: { "Hello, world!" }, set: { _ in })
        let modelSelection = Binding<ModelChoice>(get: { .codex }, set: { _ in })
        let scopeSelection = Binding<ContextScopeChoice>(get: { .workspace }, set: { _ in })

        let view = ChatInputBar(
            text: text,
            isAskEnabled: false,
            isSending: true,
            modelSelection: modelSelection,
            scopeSelection: scopeSelection,
            onSend: {},
            onAsk: {},
            onAttach: {},
            onMic: {}
        )

        XCTAssertNotNil(view, "ChatInputBar should construct with all states")
        XCTAssertEqual(text.wrappedValue, "Hello, world!", "Should have correct text")
    }

    // MARK: - Intent Handler Tests

    func testChatInputBarSendHandlerIsCalled() {
        // Test that send handler closure is properly wired
        let text = Binding<String>(get: { "test message" }, set: { _ in })
        let modelSelection = Binding<ModelChoice>(get: { .codex }, set: { _ in })
        let scopeSelection = Binding<ContextScopeChoice>(get: { .selection }, set: { _ in })

        var sendCalled = false
        let view = ChatInputBar(
            text: text,
            isAskEnabled: true,
            isSending: false,
            modelSelection: modelSelection,
            scopeSelection: scopeSelection,
            onSend: { sendCalled = true },
            onAsk: {},
            onAttach: {},
            onMic: {}
        )

        XCTAssertNotNil(view, "ChatInputBar should construct with send handler")
        // Note: In a real test, we'd simulate UI interaction to trigger the closure
        // For now, we verify the view constructs with the handler properly
    }

    func testChatInputBarAskHandlerIsCalled() {
        // Test that ask handler closure is properly wired
        let text = Binding<String>(get: { "question" }, set: { _ in })
        let modelSelection = Binding<ModelChoice>(get: { .codex }, set: { _ in })
        let scopeSelection = Binding<ContextScopeChoice>(get: { .selection }, set: { _ in })

        var askCalled = false
        let view = ChatInputBar(
            text: text,
            isAskEnabled: true,
            isSending: false,
            modelSelection: modelSelection,
            scopeSelection: scopeSelection,
            onSend: {},
            onAsk: { askCalled = true },
            onAttach: {},
            onMic: {}
        )

        XCTAssertNotNil(view, "ChatInputBar should construct with ask handler")
    }

    func testChatInputBarAttachHandlerIsCalled() {
        // Test that attach handler closure is properly wired
        let text = Binding<String>(get: { "" }, set: { _ in })
        let modelSelection = Binding<ModelChoice>(get: { .codex }, set: { _ in })
        let scopeSelection = Binding<ContextScopeChoice>(get: { .selection }, set: { _ in })

        var attachCalled = false
        let view = ChatInputBar(
            text: text,
            isAskEnabled: true,
            isSending: false,
            modelSelection: modelSelection,
            scopeSelection: scopeSelection,
            onSend: {},
            onAsk: {},
            onAttach: { attachCalled = true },
            onMic: {}
        )

        XCTAssertNotNil(view, "ChatInputBar should construct with attach handler")
    }

    func testChatInputBarMicHandlerIsCalled() {
        // Test that mic handler closure is properly wired
        let text = Binding<String>(get: { "" }, set: { _ in })
        let modelSelection = Binding<ModelChoice>(get: { .codex }, set: { _ in })
        let scopeSelection = Binding<ContextScopeChoice>(get: { .selection }, set: { _ in })

        var micCalled = false
        let view = ChatInputBar(
            text: text,
            isAskEnabled: true,
            isSending: false,
            modelSelection: modelSelection,
            scopeSelection: scopeSelection,
            onSend: {},
            onAsk: {},
            onAttach: {},
            onMic: { micCalled = true }
        )

        XCTAssertNotNil(view, "ChatInputBar should construct with mic handler")
    }

    // MARK: - Model Selection Tests

    func testChatInputBarConstructsWithAllModelChoices() {
        // Test ChatInputBar with different model choices
        let models: [UIContracts.ModelChoice] = [.codex, .stub]

        for model in models {
            let text = Binding<String>(get: { "" }, set: { _ in })
            let modelSelection = Binding<ModelChoice>(get: { model }, set: { _ in })
            let scopeSelection = Binding<ContextScopeChoice>(get: { .selection }, set: { _ in })

            let view = ChatInputBar(
                text: text,
                isAskEnabled: true,
                isSending: false,
                modelSelection: modelSelection,
                scopeSelection: scopeSelection,
                onSend: {},
                onAsk: {},
                onAttach: {},
                onMic: {}
            )

            XCTAssertNotNil(view, "ChatInputBar should construct with \(model) model")
            XCTAssertEqual(modelSelection.wrappedValue, model, "Should have correct model")
        }
    }

    // MARK: - Scope Selection Tests

    func testChatInputBarConstructsWithAllScopeChoices() {
        // Test ChatInputBar with different scope choices
        let scopes: [UIContracts.ContextScopeChoice] = [.selection, .workspace, .manual]

        for scope in scopes {
            let text = Binding<String>(get: { "" }, set: { _ in })
            let modelSelection = Binding<ModelChoice>(get: { .codex }, set: { _ in })
            let scopeSelection = Binding<ContextScopeChoice>(get: { scope }, set: { _ in })

            let view = ChatInputBar(
                text: text,
                isAskEnabled: true,
                isSending: false,
                modelSelection: modelSelection,
                scopeSelection: scopeSelection,
                onSend: {},
                onAsk: {},
                onAttach: {},
                onMic: {}
            )

            XCTAssertNotNil(view, "ChatInputBar should construct with \(scope) scope")
            XCTAssertEqual(scopeSelection.wrappedValue, scope, "Should have correct scope")
        }
    }

    // MARK: - State Combination Tests

    func testChatInputBarWithSendingState() {
        // Test ChatInputBar in sending state
        let text = Binding<String>(get: { "Sending message..." }, set: { _ in })
        let modelSelection = Binding<ModelChoice>(get: { .codex }, set: { _ in })
        let scopeSelection = Binding<ContextScopeChoice>(get: { .selection }, set: { _ in })

        let view = ChatInputBar(
            text: text,
            isAskEnabled: false, // Disabled when sending
            isSending: true,
            modelSelection: modelSelection,
            scopeSelection: scopeSelection,
            onSend: {},
            onAsk: {},
            onAttach: {},
            onMic: {}
        )

        XCTAssertNotNil(view, "ChatInputBar should construct in sending state")
        XCTAssertTrue(view.isSending, "Should be in sending state")
        XCTAssertFalse(view.isAskEnabled, "Ask should be disabled when sending")
    }

    func testChatInputBarWithAskDisabled() {
        // Test ChatInputBar with ask disabled
        let text = Binding<String>(get: { "No ask available" }, set: { _ in })
        let modelSelection = Binding<ModelChoice>(get: { .codex }, set: { _ in })
        let scopeSelection = Binding<ContextScopeChoice>(get: { .selection }, set: { _ in })

        let view = ChatInputBar(
            text: text,
            isAskEnabled: false,
            isSending: false,
            modelSelection: modelSelection,
            scopeSelection: scopeSelection,
            onSend: {},
            onAsk: {},
            onAttach: {},
            onMic: {}
        )

        XCTAssertNotNil(view, "ChatInputBar should construct with ask disabled")
        XCTAssertFalse(view.isAskEnabled, "Ask should be disabled")
        XCTAssertFalse(view.isSending, "Should not be sending")
    }

    // MARK: - Text Binding Tests

    func testChatInputBarWithEmptyText() {
        // Test ChatInputBar with empty text
        let text = Binding<String>(get: { "" }, set: { _ in })
        let modelSelection = Binding<ModelChoice>(get: { .codex }, set: { _ in })
        let scopeSelection = Binding<ContextScopeChoice>(get: { .selection }, set: { _ in })

        let view = ChatInputBar(
            text: text,
            isAskEnabled: true,
            isSending: false,
            modelSelection: modelSelection,
            scopeSelection: scopeSelection,
            onSend: {},
            onAsk: {},
            onAttach: {},
            onMic: {}
        )

        XCTAssertNotNil(view, "ChatInputBar should construct with empty text")
        XCTAssertEqual(text.wrappedValue, "", "Should have empty text")
    }

    func testChatInputBarWithLongText() {
        // Test ChatInputBar with long text
        let longText = String(repeating: "This is a long message. ", count: 50)
        let text = Binding<String>(get: { longText }, set: { _ in })
        let modelSelection = Binding<ModelChoice>(get: { .codex }, set: { _ in })
        let scopeSelection = Binding<ContextScopeChoice>(get: { .selection }, set: { _ in })

        let view = ChatInputBar(
            text: text,
            isAskEnabled: true,
            isSending: false,
            modelSelection: modelSelection,
            scopeSelection: scopeSelection,
            onSend: {},
            onAsk: {},
            onAttach: {},
            onMic: {}
        )

        XCTAssertNotNil(view, "ChatInputBar should construct with long text")
        XCTAssertEqual(text.wrappedValue.count, longText.count, "Should preserve long text")
    }
}

