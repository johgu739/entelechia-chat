import XCTest
import Combine
import AppCoreEngine
@testable import UIConnections

@MainActor
final class ModelAndScopeBindingTests: XCTestCase {
    
    func testChangingModelInChatUpdatesWorkspace() async {
        let wiring = makeSubject()
        await Task.yield()
        wiring.chat.selectModel(.stub)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(wiring.workspace.modelChoice, .stub)
    }
    
    func testChangingScopeInChatUpdatesWorkspace() async {
        let wiring = makeSubject()
        await Task.yield()
        wiring.chat.selectScope(.workspace)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(wiring.workspace.activeScope, .workspace)
    }
    
    func testBindingsDoNotLoopInfinitely() async {
        var cancellables: Set<AnyCancellable> = []
        let wiring = makeSubject()
        await Task.yield()
        var updateCount = 0
        
        wiring.workspace.$modelChoice
            .dropFirst()
            .sink { _ in updateCount += 1 }
            .store(in: &cancellables)
        
        wiring.chat.selectModel(.stub)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertLessThanOrEqual(updateCount, 3)
    }
    
    private func makeSubject() -> (chat: ChatViewModel, workspace: WorkspaceViewModel) {
        let selection = ContextSelectionState()
        let engine = DeterministicWorkspaceEngine(
            root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
            files: [TestWorkspaceFile(relativePath: "file.swift", content: "body")],
            initialSelection: "file.swift"
        )
        let workspace = WorkspaceViewModel(
            workspaceEngine: engine,
            conversationEngine: FakeConversationEngine(),
            projectTodosLoader: SharedStubTodosLoader(),
            codexService: FakeCodexService(),
            contextSelection: selection
        )
        let coordinator = ConversationCoordinator(workspace: workspace, contextSelection: selection)
        let chat = ChatViewModel(coordinator: coordinator, contextSelection: selection)
        return (chat, workspace)
    }
}
