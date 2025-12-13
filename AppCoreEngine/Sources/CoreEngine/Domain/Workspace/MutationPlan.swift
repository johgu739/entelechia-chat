import Foundation

/// Describes a validated, ordered mutation plan.
/// Domain layer authorizes; adapter layer executes.
public struct MutationPlan: Sendable, Equatable {
    public let rootPath: String
    public let canonicalRoot: String
    public let fileDiffs: [FileDiff]
    public let validationErrors: [String]
    
    public init(rootPath: String, canonicalRoot: String, fileDiffs: [FileDiff], validationErrors: [String] = []) {
        self.rootPath = rootPath
        self.canonicalRoot = canonicalRoot
        self.fileDiffs = fileDiffs
        self.validationErrors = validationErrors
    }
    
    public var isValid: Bool {
        validationErrors.isEmpty && !fileDiffs.isEmpty
    }
}


