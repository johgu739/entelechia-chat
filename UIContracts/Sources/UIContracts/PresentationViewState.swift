import Foundation

/// Immutable view state for presentation UI (pure form, no power).
public struct PresentationViewState: Equatable, Sendable {
    public let activeNavigator: NavigatorMode
    public let filterText: String
    public let expandedDescriptorIDs: Set<FileID>
    
    public init(
        activeNavigator: NavigatorMode,
        filterText: String,
        expandedDescriptorIDs: Set<FileID>
    ) {
        self.activeNavigator = activeNavigator
        self.filterText = filterText
        self.expandedDescriptorIDs = expandedDescriptorIDs
    }
}

