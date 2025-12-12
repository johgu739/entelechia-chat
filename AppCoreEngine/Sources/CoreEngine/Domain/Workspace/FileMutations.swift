import Foundation

public struct FileDiff: Sendable, Equatable {
    public let path: String
    public let patch: String

    public init(path: String, patch: String) {
        self.path = path
        self.patch = patch
    }
}

public struct AppliedPatchResult: Sendable, Equatable {
    public let path: String
    public let applied: Bool
    public let message: String

    public init(path: String, applied: Bool, message: String) {
        self.path = path
        self.applied = applied
        self.message = message
    }
}

public protocol AtomicDiffApplying: Sendable {
    func apply(diffs: [FileDiff], in root: URL) throws -> [AppliedPatchResult]
}

public protocol FileMutationAuthorizing: Sendable {
    func execute(_ plan: MutationPlan) throws -> [AppliedPatchResult]
}

