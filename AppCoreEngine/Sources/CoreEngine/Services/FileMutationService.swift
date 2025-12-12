import Foundation

/// Domain service for authorizing and planning file mutations.
/// Power: Descriptive (parses) + Decisional (validates, orders)
/// Does NOT execute mutations - emits MutationPlan for adapter execution.
public final class FileMutationService: FileMutationPlanning, Sendable {
    public init() {}
    
    /// Authorizes and plans mutations from unified diff text.
    /// Returns MutationPlan that adapter must execute.
    public func planMutation(_ diffText: String, rootPath: String) throws -> MutationPlan {
        let fileDiffs = UnifiedDiffParser.parse(diffText: diffText)
        let canonicalRoot = try canonicalizeRoot(rootPath)
        let validationErrors = validateDiffs(fileDiffs, rootPath: canonicalRoot)
        
        return MutationPlan(
            rootPath: rootPath,
            canonicalRoot: canonicalRoot,
            fileDiffs: fileDiffs,
            validationErrors: validationErrors
        )
    }
    
    private func canonicalizeRoot(_ rootPath: String) throws -> String {
        let url = URL(fileURLWithPath: rootPath)
        return url.resolvingSymlinksInPath().standardizedFileURL.path
    }
    
    private func validateDiffs(_ diffs: [FileDiff], rootPath: String) -> [String] {
        var errors: [String] = []
        // Add validation logic: path existence, permissions, etc.
        // For now, basic validation - can be extended later
        for diff in diffs {
            if diff.path.isEmpty {
                errors.append("Empty path in diff")
            }
            if diff.patch.isEmpty {
                errors.append("Empty patch for path: \(diff.path)")
            }
        }
        return errors
    }
}

// Move UnifiedDiffParser from UIConnections here
private enum UnifiedDiffParser {
    static func parse(diffText: String) -> [FileDiff] {
        var diffs: [FileDiff] = []
        let lines = diffText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var currentPath: String?
        var currentPatch: [String] = []

        func flush() {
            guard let path = currentPath, !currentPatch.isEmpty else { return }
            diffs.append(FileDiff(path: path, patch: currentPatch.joined(separator: "\n")))
            currentPatch.removeAll()
        }

        for line in lines {
            if line.hasPrefix("--- ") {
                flush()
                continue
            }
            if line.hasPrefix("+++ ") {
                let path = line.replacingOccurrences(of: "+++ b/", with: "").replacingOccurrences(of: "+++ ", with: "")
                currentPath = path
                currentPatch.append(line)
                continue
            }
            currentPatch.append(line)
        }
        flush()
        return diffs
    }
}

