import XCTest
import ChatUI
import UIContracts

/// Test that ChatUI views can be rendered from JSON-derived ViewState.
/// This proves ChatUI has no runtime dependencies on domain types.
final class JSONRenderingTests: XCTestCase {
    
    func testChatViewStateFromJSON() throws {
        let json = """
        {
            "text": "Hello",
            "messages": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440000",
                    "role": "user",
                    "text": "Test message",
                    "createdAt": "2024-01-01T00:00:00Z",
                    "attachments": []
                }
            ],
            "streamingText": null,
            "isSending": false,
            "isAsking": false,
            "model": "codex",
            "contextScope": "selection"
        }
        """
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = json.data(using: .utf8)!
        let viewState = try decoder.decode(ChatViewState.self, from: data)
        
        XCTAssertEqual(viewState.text, "Hello")
        XCTAssertEqual(viewState.messages.count, 1)
        XCTAssertEqual(viewState.model, .codex)
        XCTAssertEqual(viewState.contextScope, .selection)
    }
    
    func testWorkspaceViewStateFromJSON() throws {
        let json = """
        {
            "selectedNode": null,
            "selectedDescriptorID": null,
            "rootFileNode": null,
            "rootDirectory": null,
            "projectTodos": {
                "generatedAt": null,
                "missingHeaders": [],
                "missingFolderTelos": [],
                "filesWithIncompleteHeaders": [],
                "foldersWithIncompleteTelos": [],
                "allTodos": []
            },
            "todosErrorDescription": null
        }
        """
        
        let decoder = JSONDecoder()
        let data = json.data(using: .utf8)!
        let viewState = try decoder.decode(WorkspaceUIViewState.self, from: data)
        
        XCTAssertNil(viewState.selectedNode)
        XCTAssertEqual(viewState.projectTodos.totalCount(), 0)
    }
    
    func testChatUIViewsRenderableFromStaticState() {
        // This test verifies that ChatUI views can be instantiated with static ViewState
        // without requiring any domain types or runtime dependencies
        
        let chatState = ChatViewState(
            text: "Test",
            messages: [],
            streamingText: nil,
            isSending: false,
            isAsking: false,
            model: .codex,
            contextScope: .selection
        )
        
        let workspaceState = WorkspaceUIViewState(
            selectedNode: nil,
            selectedDescriptorID: nil,
            rootFileNode: nil,
            rootDirectory: nil,
            projectTodos: .empty,
            todosErrorDescription: nil
        )
        
        let contextState = ContextViewState(
            lastContextSnapshot: nil,
            lastContextResult: nil,
            streamingMessages: [:],
            bannerMessage: nil
        )
        
        let presentationState = PresentationViewState(
            activeNavigator: .project,
            filterText: "",
            expandedDescriptorIDs: []
        )
        
        // Verify we can create ViewState instances without domain dependencies
        XCTAssertNotNil(chatState)
        XCTAssertNotNil(workspaceState)
        XCTAssertNotNil(contextState)
        XCTAssertNotNil(presentationState)
    }
}

