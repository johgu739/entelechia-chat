import Foundation
import Combine
import UIContracts

/// Single coherent state object representing the current detail in a navigation → detail view architecture.
/// Owns all detail-scoped, ephemeral state. Selection change replaces the entire instance.
/// Power: Descriptive (state container, no domain logic)
@MainActor
internal final class DetailState: ObservableObject {
    // MARK: - Identity (IMMUTABLE)
    
    /// The identity of this detail (the selected file/folder descriptor).
    /// `nil` means no detail is selected.
    /// This is the primary key that scopes all other detail state.
    /// Selection change replaces the entire DetailState instance.
    public let selectedDescriptorID: UIContracts.FileID?
    
    // MARK: - Detail-Scoped State
    
    /// Context snapshot for this detail (built on send, invalidated on detail change).
    /// `nil` until first send operation completes for this detail.
    @Published public var contextSnapshot: UIContracts.ContextSnapshot?
    
    /// Context build result for this detail (built on send, invalidated on detail change).
    /// `nil` until first send operation completes for this detail.
    @Published public var contextResult: UIContracts.UIContextBuildResult?
    
    /// Streaming messages for conversations in this detail.
    /// Keyed by conversation ID, cleared when detail changes.
    @Published public var streamingMessages: [UUID: String] = [:]
    
    /// Inspector tab selection for this detail.
    /// Reset to default when detail changes.
    @Published public var inspectorTab: UIContracts.InspectorTab = .files
    
    // MARK: - Initialization
    
    /// Create a new detail state for the given selection.
    /// Context and inspector state start as nil/default.
    init(selectedDescriptorID: UIContracts.FileID?) {
        self.selectedDescriptorID = selectedDescriptorID
        self.contextSnapshot = nil
        self.contextResult = nil
        self.streamingMessages = [:]
        self.inspectorTab = .files
    }
    
    /// Create an empty detail state (no selection).
    static var empty: DetailState {
        DetailState(selectedDescriptorID: nil)
    }
}
