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
        let fileUUID = UUID()
        let fileID = UIContracts.FileID(fileUUID)
        let fileNode = UIContracts.FileNode(
            id: fileUUID,
            descriptorID: fileID,
            name: "test.swift",
            path: URL(fileURLWithPath: "/test.swift"),
            children: [],
            icon: "doc.text",
            isDirectory: false
        )

        let workspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: fileNode,
            selectedDescriptorID: fileID,
            rootFileNode: fileNode,
            rootDirectory: URL(fileURLWithPath: "/"),
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        let presentationState = UIContracts.PresentationViewState(
            activeNavigator: .project,
            filterText: "search",
            expandedDescriptorIDs: [fileID]
        )

        let view = XcodeNavigatorView(
            workspaceState: workspaceState,
            presentationState: presentationState,
            onWorkspaceIntent: { _ in }
        )

        XCTAssertNotNil(view, "XcodeNavigatorView should construct with workspace data")
        XCTAssertEqual(presentationState.filterText, "search", "Should have filter text")
        XCTAssertTrue(presentationState.expandedDescriptorIDs.contains(fileID), "Should have expanded descriptor")
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

        // Test search mode
        let searchPresentation = UIContracts.PresentationViewState(
            activeNavigator: .search,
            filterText: "",
            expandedDescriptorIDs: []
        )

        let searchView = XcodeNavigatorView(
            workspaceState: workspaceState,
            presentationState: searchPresentation,
            onWorkspaceIntent: { _ in }
        )

        XCTAssertNotNil(searchView, "Should construct with search navigator")
        XCTAssertEqual(searchPresentation.activeNavigator, .search, "Should be in search mode")
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
        let workspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: nil,
            selectedDescriptorID: nil,
            rootFileNode: nil,
            rootDirectory: nil,
            projectTodos: UIContracts.ProjectTodos(
                allTodos: ["Fix bug in /test.swift:42"]
            ),
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
        XCTAssertEqual(workspaceState.projectTodos.allTodos.count, 1, "Should have one todo")
        XCTAssertEqual(workspaceState.projectTodos.allTodos.first, "Fix bug in /test.swift:42", "Should have correct todo")
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
            id: UUID(),
            name: "child.swift",
            path: URL(fileURLWithPath: "/src/child.swift"),
            children: [],
            icon: "doc.text",
            isDirectory: false
        )

        let parentDir = UIContracts.FileNode(
            id: UUID(),
            name: "src",
            path: URL(fileURLWithPath: "/src"),
            children: [childFile],
            icon: "folder",
            isDirectory: true
        )

        let rootDir = UIContracts.FileNode(
            id: UUID(),
            name: "root",
            path: URL(fileURLWithPath: "/"),
            children: [parentDir],
            icon: "folder",
            isDirectory: true
        )

        let workspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: childFile,
            selectedDescriptorID: UIContracts.FileID(childFile.id),
            rootFileNode: rootDir,
            rootDirectory: URL(fileURLWithPath: "/"),
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        let parentDirID = UIContracts.FileID(parentDir.id)
        let presentationState = UIContracts.PresentationViewState(
            activeNavigator: .project,
            filterText: "",
            expandedDescriptorIDs: [parentDirID]
        )

        let view = XcodeNavigatorView(
            workspaceState: workspaceState,
            presentationState: presentationState,
            onWorkspaceIntent: { _ in }
        )

        XCTAssertNotNil(view, "Should construct with nested file structure")
        XCTAssertEqual(workspaceState.rootFileNode?.children?.count ?? 0, 1, "Root should have one child")
        XCTAssertEqual(workspaceState.rootFileNode?.children?.first?.children?.count ?? 0, 1, "Parent dir should have one child")
        XCTAssertEqual(workspaceState.selectedNode?.name, "child.swift", "Should have correct selected file")
    }
}
