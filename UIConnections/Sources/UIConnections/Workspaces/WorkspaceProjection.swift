import Foundation
import Combine
import AppCoreEngine
import UIContracts

/// Read-only projections derived from domain streams.
/// Power: Descriptive (projects domain state to UI-readable form)
/// Contains domain-derived artifacts, not user-controlled UI state.
@MainActor
public final class WorkspaceProjection: ObservableObject {
    // MARK: - Domain Projections (Derived from Domain Streams)
    
    @Published public var streamingMessages: [UUID: String] = [:]
    @Published public var lastContextResult: UIContracts.UIContextBuildResult?
    @Published public var lastContextSnapshot: UIContracts.ContextSnapshot?
    @Published public var workspaceState: UIContracts.WorkspaceViewState = UIContracts.WorkspaceViewState(
        rootPath: nil,
        selectedDescriptorID: nil,
        selectedPath: nil,
        projection: nil,
        contextInclusions: [:],
        watcherError: nil
    )
    
    // MARK: - Streaming Publisher for Observation
    
    /// Publisher that emits streaming message updates for observation.
    /// Emits (conversationID, streamingText) tuples when streamingMessages changes.
    /// Note: This is a simplified implementation that emits all current messages.
    /// For per-conversation filtering, use filter() on the subscription side.
    public var streamingPublisher: AnyPublisher<(UUID, String?), Never> {
        $streamingMessages
            .flatMap { messages -> AnyPublisher<(UUID, String?), Never> in
                // Emit each (id, text) tuple from the dictionary
                let publishers = messages.map { id, text in
                    Just((id, text)).eraseToAnyPublisher()
                }
                guard !publishers.isEmpty else {
                    return Empty<(UUID, String?), Never>().eraseToAnyPublisher()
                }
                return Publishers.MergeMany(publishers).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    public init() {}
}

