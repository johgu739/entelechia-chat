import Foundation
import AppCoreEngine

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

    public func execute(_ plan: MutationPlan) throws -> [AppliedPatchResult] {
        guard plan.isValid else {
            throw EngineError.invalidMutation("Validation errors: \(plan.validationErrors.joined(separator: ", "))")
        }
        let rootURL = URL(fileURLWithPath: plan.canonicalRoot)
        return try applier.apply(diffs: plan.fileDiffs, in: rootURL)
    }
}


