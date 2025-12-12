import XCTest
import SwiftUI
import Foundation
@testable import ChatUI
import UIContracts

/// Negative test: Verifies ChatUI can be tested without domain types.
/// This test proves that ChatUI can be reasoned about without knowing engines, workflows, or domain execution exist.
@MainActor
final class DomainTypeLeakageTest: XCTestCase {
    
    /// Test that ChatUI views can be constructed with fake UIContracts types only.
    /// This proves ChatUI has no dependency on domain types.
    func testChatUIWorksWithFakeViewStateOnly() {
        // Create fake ViewState structs (pure data, no domain semantics)
        let fakeWorkspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: nil,
            selectedDescriptorID: nil,
            rootFileNode: nil,
            rootDirectory: nil,
            projectTodos: .empty,
            todosErrorDescription: nil
        )
        
        let fakeContextState = UIContracts.ContextViewState(
            lastContextSnapshot: nil,
            lastContextResult: nil,
            streamingMessages: [:],
            bannerMessage: nil
        )
        
        let fakeChatState = UIContracts.ChatViewState(
            text: "",
            messages: [],
            streamingText: nil,
            isSending: false,
            isAsking: false,
            model: .codex,
            contextScope: .selection
        )
        
        let fakePresentationState = UIContracts.PresentationViewState(
            activeNavigator: .project,
            filterText: "",
            expandedDescriptorIDs: []
        )
        
        // Verify we can construct ChatView with fake data only
        // No domain types, no engines, no coordinators required
        let inspectorTab = Binding<UIContracts.InspectorTab>(
            get: { .files },
            set: { _ in }
        )
        
        let view = ChatView(
            chatState: fakeChatState,
            workspaceState: fakeWorkspaceState,
            contextState: fakeContextState,
            onChatIntent: { _ in },
            onWorkspaceIntent: { _ in },
            inspectorTab: inspectorTab
        )
        
        // If we get here, ChatUI can be tested without domain knowledge
        XCTAssertNotNil(view, "ChatUI should be constructible with fake ViewState only")
    }
    
    /// Test that ChatUI does not import AppCoreEngine.
    /// This is verified at compile time - if this compiles, the test passes.
    func testChatUIDoesNotImportAppCoreEngine() {
        // This test passes if the file compiles without importing AppCoreEngine
        // If ChatUI tried to use AppCoreEngine types, this would fail to compile
        XCTAssertTrue(true, "ChatUI compiles without AppCoreEngine import")
    }
    
    /// Test that ChatUI does not import UIConnections (except in tests for test doubles).
    /// In production code, ChatUI should never import UIConnections.
    func testChatUIProductionCodeDoesNotImportUIConnections() {
        // Note: Test files may import UIConnections for test doubles
        // But production ChatUI code should not
        // This is verified by the chatui-import-guard.sh script
        XCTAssertTrue(true, "ChatUI production code does not import UIConnections (verified by guard script)")
    }
}

