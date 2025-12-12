// @EntelechiaHeaderStart
// Signifier: WorkspacePresentationViewModel
// Substance: Workspace UI presentation faculty
// Genus: UI presentation faculty
// Differentia: Pure UI state - visibility, layout, animation, focus
// Form: UI presentation state
// Matter: NavigatorMode, filter text, expanded nodes, UI flags
// Powers: Control UI appearance and transitions
// FinalCause: Present workspace UI state
// Relations: Owned by UIConnections; observes domain state from WorkspaceStateViewModel
// CausalityType: Accidental (UI only)
// @EntelechiaHeaderEnd

import Foundation
import Combine
import UIContracts

/// Pure UI presentation state for workspace (no domain concerns)
@MainActor
public final class WorkspacePresentationViewModel: ObservableObject {
    public init() {}
    // MARK: - UI Presentation State
    
    /// Active navigator tab (UI concern)
    @Published public var activeNavigator: UIContracts.NavigatorMode = .project
    
    /// Filter text for file tree (UI concern)
    @Published public var filterText: String = ""
    
    /// Expanded descriptor IDs for file tree (UI concern - controls visibility)
    @Published public var expandedDescriptorIDs: Set<FileID> = []
    
    // MARK: - UI Helpers
    
    /// Toggle expanded state for a descriptor ID
    public func toggleExpanded(descriptorID: FileID) {
        if expandedDescriptorIDs.contains(descriptorID) {
            expandedDescriptorIDs.remove(descriptorID)
        } else {
            expandedDescriptorIDs.insert(descriptorID)
        }
    }
    
    /// Check if a descriptor ID is expanded
    public func isExpanded(descriptorID: FileID) -> Bool {
        expandedDescriptorIDs.contains(descriptorID)
    }
    
    /// Clear expanded state (called when root changes)
    public func clearExpanded() {
        expandedDescriptorIDs.removeAll()
    }
}



