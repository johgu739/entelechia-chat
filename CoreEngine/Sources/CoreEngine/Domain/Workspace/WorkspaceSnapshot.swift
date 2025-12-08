import Foundation

/// Engine-owned immutable snapshot of workspace state and tree.
public struct WorkspaceSnapshot: Codable, Sendable, Equatable {
    public let rootPath: String?
    public let selectedPath: String?
    public let lastPersistedSelection: String?
    public let selectedDescriptorID: FileID?
    public let lastPersistedDescriptorID: FileID?
    public let contextPreferences: WorkspaceContextPreferencesState
    public let descriptorPaths: [FileID: String]
    public let contextInclusions: [FileID: ContextInclusionState]
    public let descriptors: [FileDescriptor]

    public init(
        rootPath: String?,
        selectedPath: String?,
        lastPersistedSelection: String?,
        selectedDescriptorID: FileID?,
        lastPersistedDescriptorID: FileID?,
        contextPreferences: WorkspaceContextPreferencesState,
        descriptorPaths: [FileID: String],
        contextInclusions: [FileID: ContextInclusionState],
        descriptors: [FileDescriptor]
    ) {
        self.rootPath = rootPath
        self.selectedPath = selectedPath
        self.lastPersistedSelection = lastPersistedSelection
        self.selectedDescriptorID = selectedDescriptorID
        self.lastPersistedDescriptorID = lastPersistedDescriptorID
        self.contextPreferences = contextPreferences
        self.descriptorPaths = descriptorPaths
        self.contextInclusions = contextInclusions
        self.descriptors = descriptors
    }

    public static let empty = WorkspaceSnapshot(
        rootPath: nil,
        selectedPath: nil,
        lastPersistedSelection: nil,
        selectedDescriptorID: nil,
        lastPersistedDescriptorID: nil,
        contextPreferences: .empty,
        descriptorPaths: [:],
        contextInclusions: [:],
        descriptors: []
    )
}


