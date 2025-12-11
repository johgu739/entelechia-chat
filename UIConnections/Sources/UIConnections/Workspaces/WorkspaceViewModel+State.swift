import Foundation
import Combine

public extension WorkspaceViewModel {
    // MARK: - State Mutations
    func setRootDirectory(_ url: URL) {
        Task { await openWorkspace(at: url) }
    }
    
    func setContextScope(_ scope: ContextScopeChoice) {
        activeScope = scope
        contextSelection.setScopeChoice(scope)
    }
    
    func setModelChoice(_ model: ModelChoice) {
        modelChoice = model
        contextSelection.setModelChoice(model)
    }
    
    func setSelectedURL(_ url: URL?) {
        guard let url else {
            Task { await selectPath(nil) }
            return
        }
        if let descriptorID = descriptorPaths.first(where: { $0.value == url.path })?.key {
            setSelectedDescriptorID(descriptorID)
            return
        }
        Task { await selectPath(url) }
    }
    
    func setSelectedDescriptorID(_ id: FileID?) {
        guard let id else {
            Task { await selectPath(nil) }
            return
        }
        if let path = descriptorPaths[id] {
            Task { await selectPath(URL(fileURLWithPath: path)) }
        }
    }
    
    func toggleExpanded(descriptorID: FileID) {
        if expandedDescriptorIDs.contains(descriptorID) {
            expandedDescriptorIDs.remove(descriptorID)
        } else {
            expandedDescriptorIDs.insert(descriptorID)
        }
    }
    
    func isExpanded(descriptorID: FileID) -> Bool {
        expandedDescriptorIDs.contains(descriptorID)
    }
    
    // MARK: - Derived Accessors
    func streamingText(for conversationID: UUID) -> String {
        streamingMessages[conversationID] ?? ""
    }
    
    var contextErrorPublisher: AnyPublisher<Error, Never> {
        contextErrorSubject.eraseToAnyPublisher()
    }
    
    func url(for descriptorID: FileID) -> URL? {
        descriptorPaths[descriptorID].map { URL(fileURLWithPath: $0) }
    }
    
    func publishFileBrowserError(_ error: Error) {
        handleFileSystemError(error, fallbackTitle: "Failed to Read Folder")
    }
    
    func canAskCodex() -> Bool {
        currentWorkspaceScope() != nil
    }
}

