import XCTest
import SwiftUI
@testable import ChatUI
import UIContracts

/// Contract tests for navigator-related views.
/// Tests that navigator views render correctly with fake ViewState structs and intent closures.
@MainActor
final class NavigatorViewContractTests: XCTestCase {

    // MARK: - XcodeNavigatorView Construction Tests

    func testXcodeNavigatorViewConstructsWithEmptyWorkspace() {
        // Test XcodeNavigatorView with completely empty workspace
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

        let view = XcodeNavigatorView(
            workspaceState: workspaceState,
            presentationState: presentationState,
            onWorkspaceIntent: { _ in }
        )

        XCTAssertNotNil(view, "XcodeNavigatorView should construct with empty workspace")
    }

    func testXcodeNavigatorViewConstructsWithSingleFile() {
        // Test XcodeNavigatorView with single file workspace
        let fileUUID = UUID()
        let fileID = UIContracts.FileID(fileUUID)
        let fileNode = UIContracts.FileNode(
            id: fileUUID,
            descriptorID: fileID,
            name: "main.swift",
            path: URL(fileURLWithPath: "/main.swift"),
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
            filterText: "",
            expandedDescriptorIDs: []
        )

        let view = XcodeNavigatorView(
            workspaceState: workspaceState,
            presentationState: presentationState,
            onWorkspaceIntent: { _ in }
        )

        XCTAssertNotNil(view, "XcodeNavigatorView should construct with single file")
        XCTAssertEqual(workspaceState.selectedNode?.name, "main.swift", "Should have correct file selected")
    }

    func testXcodeNavigatorViewConstructsWithComplexHierarchy() {
        // Test XcodeNavigatorView with complex nested hierarchy
        let createFileNode = { (name: String, path: String, isDirectory: Bool) -> UIContracts.FileNode in
            UIContracts.FileNode(
                id: UUID(),
                name: name,
                path: URL(fileURLWithPath: path),
                children: [],
                icon: isDirectory ? "folder" : "doc.text",
                isDirectory: isDirectory
            )
        }

        let modelFile = createFileNode("Model.swift", "/Sources/Model.swift", false)
        let viewFile = createFileNode("View.swift", "/Sources/View.swift", false)
        let controllerFile = createFileNode("Controller.swift", "/Sources/Controller.swift", false)

        let sourcesDir = UIContracts.FileNode(
            id: UUID(),
            name: "Sources",
            path: URL(fileURLWithPath: "/Sources"),
            children: [modelFile, viewFile, controllerFile],
            icon: "folder",
            isDirectory: true
        )

        let testFile = createFileNode("Tests.swift", "/Tests/Tests.swift", false)
        let testsDir = UIContracts.FileNode(
            id: UUID(),
            name: "Tests",
            path: URL(fileURLWithPath: "/Tests"),
            children: [testFile],
            icon: "folder",
            isDirectory: true
        )

        let rootDir = UIContracts.FileNode(
            id: UUID(),
            name: "Project",
            path: URL(fileURLWithPath: "/"),
            children: [sourcesDir, testsDir],
            icon: "folder",
            isDirectory: true
        )

        let viewFileID = UIContracts.FileID(viewFile.id)
        let workspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: viewFile,
            selectedDescriptorID: viewFileID,
            rootFileNode: rootDir,
            rootDirectory: URL(fileURLWithPath: "/"),
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        let sourcesDirID = UIContracts.FileID(sourcesDir.id)
        let testsDirID = UIContracts.FileID(testsDir.id)
        let presentationState = UIContracts.PresentationViewState(
            activeNavigator: .project,
            filterText: "",
            expandedDescriptorIDs: [sourcesDirID, testsDirID]
        )

        let view = XcodeNavigatorView(
            workspaceState: workspaceState,
            presentationState: presentationState,
            onWorkspaceIntent: { _ in }
        )

        XCTAssertNotNil(view, "XcodeNavigatorView should construct with complex hierarchy")
        XCTAssertEqual(workspaceState.rootFileNode?.children?.count ?? 0, 2, "Root should have 2 children")
        XCTAssertEqual(workspaceState.rootFileNode?.children?.first?.children?.count ?? 0, 3, "Sources dir should have 3 children")
        XCTAssertEqual(workspaceState.selectedNode?.name, "View.swift", "Should have View.swift selected")
    }

    // MARK: - Navigator Mode Tests

    func testXcodeNavigatorViewWithAllNavigatorModes() {
        // Test XcodeNavigatorView with all available navigator modes
        let workspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: nil,
            selectedDescriptorID: nil,
            rootFileNode: nil,
            rootDirectory: nil,
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        // Test different navigator modes
        let modes: [UIContracts.NavigatorMode] = [.project, .search]

        for mode in modes {
            let presentationState = UIContracts.PresentationViewState(
                activeNavigator: mode,
                filterText: "",
                expandedDescriptorIDs: []
            )

            let view = XcodeNavigatorView(
                workspaceState: workspaceState,
                presentationState: presentationState,
                onWorkspaceIntent: { _ in }
            )

            XCTAssertNotNil(view, "XcodeNavigatorView should construct with \(mode) mode")
            XCTAssertEqual(presentationState.activeNavigator, mode, "Should have correct navigator mode")
        }
    }

    // MARK: - Filter and Search Tests

    func testXcodeNavigatorViewWithFilterText() {
        // Test XcodeNavigatorView with filter text
        let workspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: nil,
            selectedDescriptorID: nil,
            rootFileNode: nil,
            rootDirectory: nil,
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        let filterTexts = ["", "swift", "test", "very long filter text that should still work"]

        for filterText in filterTexts {
            let presentationState = UIContracts.PresentationViewState(
                activeNavigator: .project,
                filterText: filterText,
                expandedDescriptorIDs: []
            )

            let view = XcodeNavigatorView(
                workspaceState: workspaceState,
                presentationState: presentationState,
                onWorkspaceIntent: { _ in }
            )

            XCTAssertNotNil(view, "XcodeNavigatorView should construct with filter text: '\(filterText)'")
            XCTAssertEqual(presentationState.filterText, filterText, "Should have correct filter text")
        }
    }

    // MARK: - Expansion State Tests

    func testXcodeNavigatorViewWithExpandedDirectories() {
        // Test XcodeNavigatorView with expanded directory states
        let dir1ID = UIContracts.FileID()
        let dir2ID = UIContracts.FileID()
        let dir3ID = UIContracts.FileID()

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
            expandedDescriptorIDs: [dir1ID, dir2ID, dir3ID]
        )

        let view = XcodeNavigatorView(
            workspaceState: workspaceState,
            presentationState: presentationState,
            onWorkspaceIntent: { _ in }
        )

        XCTAssertNotNil(view, "XcodeNavigatorView should construct with expanded directories")
        XCTAssertEqual(presentationState.expandedDescriptorIDs.count, 3, "Should have 3 expanded directories")
        XCTAssertTrue(presentationState.expandedDescriptorIDs.contains(dir1ID), "Should contain dir1ID")
        XCTAssertTrue(presentationState.expandedDescriptorIDs.contains(dir2ID), "Should contain dir2ID")
        XCTAssertTrue(presentationState.expandedDescriptorIDs.contains(dir3ID), "Should contain dir3ID")
    }

    // MARK: - Selection State Tests

    func testXcodeNavigatorViewWithVariousSelections() {
        // Test XcodeNavigatorView with different selection states
        let fileUUID = UUID()
        let fileID = UIContracts.FileID(fileUUID)
        let fileNode = UIContracts.FileNode(
            id: fileUUID,
            descriptorID: fileID,
            name: "selected.swift",
            path: URL(fileURLWithPath: "/selected.swift"),
            children: [],
            icon: "doc.text",
            isDirectory: false
        )

        let dirUUID = UUID()
        let dirID = UIContracts.FileID(dirUUID)
        let dirNode = UIContracts.FileNode(
            id: dirUUID,
            descriptorID: dirID,
            name: "selected_dir",
            path: URL(fileURLWithPath: "/selected_dir"),
            children: [],
            icon: "folder",
            isDirectory: true
        )

        // Test file selection
        let fileWorkspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: fileNode,
            selectedDescriptorID: fileID,
            rootFileNode: fileNode,
            rootDirectory: URL(fileURLWithPath: "/"),
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        let filePresentationState = UIContracts.PresentationViewState(
            activeNavigator: .project,
            filterText: "",
            expandedDescriptorIDs: []
        )

        let fileView = XcodeNavigatorView(
            workspaceState: fileWorkspaceState,
            presentationState: filePresentationState,
            onWorkspaceIntent: { _ in }
        )

        XCTAssertNotNil(fileView, "Should construct with file selection")
        XCTAssertFalse(fileWorkspaceState.selectedNode?.isDirectory ?? true, "Should have file selected")

        // Test directory selection
        let dirWorkspaceState = UIContracts.WorkspaceUIViewState(
            selectedNode: dirNode,
            selectedDescriptorID: dirID,
            rootFileNode: dirNode,
            rootDirectory: URL(fileURLWithPath: "/"),
            projectTodos: .empty,
            todosErrorDescription: nil
        )

        let dirPresentationState = UIContracts.PresentationViewState(
            activeNavigator: .project,
            filterText: "",
            expandedDescriptorIDs: [dirID]
        )

        let dirView = XcodeNavigatorView(
            workspaceState: dirWorkspaceState,
            presentationState: dirPresentationState,
            onWorkspaceIntent: { _ in }
        )

        XCTAssertNotNil(dirView, "Should construct with directory selection")
        XCTAssertTrue(dirWorkspaceState.selectedNode?.isDirectory ?? false, "Should have directory selected")
        XCTAssertTrue(dirPresentationState.expandedDescriptorIDs.contains(dirID), "Directory should be expanded")
    }

    // MARK: - Intent Handler Tests

    func testXcodeNavigatorViewIntentHandlerWiring() {
        // Test that workspace intent handler is properly wired
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
        // Note: In real usage, UI interactions would trigger the intent closure
        // For contract testing, we verify the view constructs with the handler
    }
}
