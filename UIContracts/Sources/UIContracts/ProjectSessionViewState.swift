import Foundation

/// Project session state for UI display (pure value type).
public struct ProjectSessionViewState: Equatable, Sendable {
    public let activeProjectURL: URL?
    public let projectName: String
    public let isOpen: Bool
    
    public init(
        activeProjectURL: URL?,
        projectName: String,
        isOpen: Bool
    ) {
        self.activeProjectURL = activeProjectURL
        self.projectName = projectName
        self.isOpen = isOpen
    }
}


