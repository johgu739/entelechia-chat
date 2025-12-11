import Foundation
import AppCoreEngine

/// Coordinates diff application for Codex mutations.
/// Marked `@unchecked Sendable` because internal state is accessed only via async methods
/// and mutation authority is thread-safe.
final class CodexMutationPipeline: @unchecked Sendable {
    private let authority: FileMutationAuthorizing

    init(authority: FileMutationAuthorizing) {
        self.authority = authority
    }

    func applyUnifiedDiff(_ diffText: String, rootPath: String) throws -> [AppliedPatchResult] {
        let fileDiffs = UnifiedDiffParser.parse(diffText: diffText)
        return try authority.apply(diffs: fileDiffs, rootPath: rootPath)
    }
}

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

