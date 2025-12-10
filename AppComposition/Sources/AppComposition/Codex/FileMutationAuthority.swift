import Foundation
import AppCoreEngine
import AppAdapters

public final class FileMutationAuthority: FileMutationAuthorizing {
    private let applier: AtomicDiffApplying
    private let rootProvider: WorkspaceRootProviding

    public init(
        applier: AtomicDiffApplying = AtomicDiffApplierAdapter(),
        rootProvider: WorkspaceRootProviding = DefaultWorkspaceRootProvider()
    ) {
        self.applier = applier
        self.rootProvider = rootProvider
    }

    public func apply(diffs: [FileDiff], rootPath: String) throws -> [AppliedPatchResult] {
        let canonical = try rootProvider.canonicalRoot(for: rootPath)
        return try applier.apply(diffs: diffs, in: URL(fileURLWithPath: canonical))
    }
}


