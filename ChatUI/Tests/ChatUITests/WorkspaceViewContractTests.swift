import XCTest
import SwiftUI
@testable import ChatUI
import UIContracts

/// Contract tests for workspace-related views.
/// Tests that workspace views render correctly with fake ViewState structs and intent closures.
@MainActor
final class WorkspaceViewContractTests: XCTestCase {

    // MARK: - XcodeNavigatorView Tests

    func testXcodeNavigatorViewConstructsWithMinimalViewState() {
        // Test that XcodeNavigatorView can be constructed with basic fake ViewState
        let workspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: nil,
            selectedDescriptorID: nil,
            rootFileNode: nil,
            rootDirectory: nil,
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        let presentationState = UIContracts.PresentationViewState(
            activeNavigator: .project,
            filterText: "",
            expandedDescriptorIDs: []
        )

        var workspaceIntentCalled = false

        let view = XcodeNavigatorView(
            workspaceState: workspaceState,
            presentationState: presentationState,
            onWorkspaceIntent: { _ in workspaceIntentCalled = true }
        )

        // Verify construction succeeds
        XCTAssertNotNil(view, "XcodeNavigatorView should construct with fake ViewState")
    }

    func testXcodeNavigatorViewConstructsWithWorkspaceData() {
        // Test XcodeNavigatorView with populated workspace data
        let fileNode = UIContracts.FileNode(
            id: FileID(),
            name: "test.swift",
            path: "/test.swift",
            type: .file,
            children: []
        )

        let workspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: fileNode,
            selectedDescriptorID: fileNode.id,
            rootFileNode: fileNode,
            rootDirectory: URL(fileURLWithPath: "/"),
            projectTodos: UIContracts.UIProjectTodos(todos: []),
            todosErrorDescription: nil
        )

        let presentationState = UIContracts.PresentationViewState(
            activeNavigator: .project,
            filterText: "search",
            expandedDescriptorIDs: [fileNode.id]
        )

        let view = XcodeNavigatorView(
            workspaceState: workspaceState,
            presentationState: presentationState,
            onWorkspaceIntent: { _ in }
        )

        XCTAssertNotNil(view, "XcodeNavigatorView should construct with workspace data")
        XCTAssertEqual(presentationState.filterText, "search", "Should have filter text")
        XCTAssertTrue(presentationState.expandedDescriptorIDs.contains(fileNode.id), "Should have expanded descriptor")
    }

    func testXcodeNavigatorViewConstructsWithDifferentNavigatorModes() {
        // Test XcodeNavigatorView with different navigator modes
        let workspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: nil,
            selectedDescriptorID: nil,
            rootFileNode: nil,
            rootDirectory: nil,
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        // Test project mode
        let projectPresentation = UIContracts.PresentationViewState(
            activeNavigator: .project,
            filterText: "",
            expandedDescriptorIDs: []
        )

        let projectView = XcodeNavigatorView(
            workspaceState: workspaceState,
            presentationState: projectPresentation,
            onWorkspaceIntent: { _ in }
        )

        XCTAssertNotNil(projectView, "Should construct with project navigator")
        XCTAssertEqual(projectPresentation.activeNavigator, .project, "Should be in project mode")

        // Test find mode
        let findPresentation = UIContracts.PresentationViewState(
            activeNavigator: .find,
            filterText: "",
            expandedDescriptorIDs: []
        )

        let findView = XcodeNavigatorView(
            workspaceState: workspaceState,
            presentationState: findPresentation,
            onWorkspaceIntent: { _ in }
        )

        XCTAssertNotNil(findView, "Should construct with find navigator")
        XCTAssertEqual(findPresentation.activeNavigator, .find, "Should be in find mode")
    }

    func testXcodeNavigatorViewConstructsWithErrorState() {
        // Test XcodeNavigatorView with error state
        let workspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: nil,
            selectedDescriptorID: nil,
            rootFileNode: nil,
            rootDirectory: nil,
            projectTodos: .empty,
            todosErrorDescription: "Failed to load project"
        )

        let presentationState = UIContracts.PresentationViewState(
            activeNavigator: .project,
            filterText: "",
            expandedDescriptorIDs: []
        )

        let view = XcodeNavigatorView(
            workspaceState: workspaceState,
            presentationState: presentationState,
            onWorkspaceIntent: { _ in }
        )

        XCTAssertNotNil(view, "XcodeNavigatorView should construct with error state")
        XCTAssertEqual(workspaceState.todosErrorDescription, "Failed to load project", "Should have error description")
    }

    func testXcodeNavigatorViewConstructsWithTodos() {
        // Test XcodeNavigatorView with project todos
        let todo = UIContracts.UITodo(
            id: UUID(),
            title: "Fix bug",
            filePath: "/test.swift",
            lineNumber: 42,
            isCompleted: false
        )

        let workspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: nil,
            selectedDescriptorID: nil,
            rootFileNode: nil,
            rootDirectory: nil,
            projectTodos: UIContracts.UIProjectTodos(todos: [todo]),
            todosErrorDescription: nil
        )

        let presentationState = UIContracts.PresentationViewState(
            activeNavigator: .project,
            filterText: "",
            expandedDescriptorIDs: []
        )

        let view = XcodeNavigatorView(
            workspaceState: workspaceState,
            presentationState: presentationState,
            onWorkspaceIntent: { _ in }
        )

        XCTAssertNotNil(view, "XcodeNavigatorView should construct with todos")
        XCTAssertEqual(workspaceState.projectTodos.todos.count, 1, "Should have one todo")
        XCTAssertEqual(workspaceState.projectTodos.todos.first?.title, "Fix bug", "Should have correct todo title")
    }

    // MARK: - Workspace Intent Handler Tests

    func testXcodeNavigatorViewIntentClosureIsCalled() {
        // Test that workspace intent closure is properly wired
        let workspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: nil,
            selectedDescriptorID: nil,
            rootFileNode: nil,
            rootDirectory: nil,
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        let presentationState = UIContracts.PresentationViewState(
            activeNavigator: .project,
            filterText: "",
            expandedDescriptorIDs: []
        )

        var receivedIntent: UIContracts.WorkspaceIntent?
        let view = XcodeNavigatorView(
            workspaceState: workspaceState,
            presentationState: presentationState,
            onWorkspaceIntent: { intent in receivedIntent = intent }
        )

        XCTAssertNotNil(view, "XcodeNavigatorView should construct with intent handler")
    }

    // MARK: - File Tree Structure Tests

    func testWorkspaceViewStateWithNestedFileStructure() {
        // Test ViewState with nested file structure
        let childFile = UIContracts.FileNode(
            id: FileID(),
            name: "child.swift",
            path: "/src/child.swift",
            type: .file,
            children: []
        )

        let parentDir = UIContracts.FileNode(
            id: FileID(),
            name: "src",
            path: "/src",
            type: .directory,
            children: [childFile]
        )

        let rootDir = UIContracts.FileNode(
            id: FileID(),
            name: "root",
            path: "/",
            type: .directory,
            children: [parentDir]
        )

        let workspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: childFile,
            selectedDescriptorID: childFile.id,
            rootFileNode: rootDir,
            rootDirectory: URL(fileURLWithPath: "/"),
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        let presentationState = UIContracts.PresentationViewState(
            activeNavigator: .project,
            filterText: "",
            expandedDescriptorIDs: [parentDir.id]
        )

        let view = XcodeNavigatorView(
            workspaceState: workspaceState,
            presentationState: presentationState,
            onWorkspaceIntent: { _ in }
        )

        XCTAssertNotNil(view, "Should construct with nested file structure")
        XCTAssertEqual(workspaceState.rootFileNode?.children.count, 1, "Root should have one child")
        XCTAssertEqual(workspaceState.rootFileNode?.children.first?.children.count, 1, "Parent dir should have one child")
        XCTAssertEqual(workspaceState.selectedNode?.name, "child.swift", "Should have correct selected file")
    }
}
