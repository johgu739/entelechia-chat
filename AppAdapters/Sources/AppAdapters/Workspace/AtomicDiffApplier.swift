import Foundation
import AppCoreEngine

public final class FileWriteAdapter: @unchecked Sendable {
    public init() {}

    public func write(_ content: String, to url: URL) throws {
        let data = Data(content.utf8)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        try data.write(to: url, options: .atomic)
    }
}

public final class AtomicDiffApplierAdapter: AtomicDiffApplying, @unchecked Sendable {
    private let writer: FileWriteAdapter

    public init(writer: FileWriteAdapter = FileWriteAdapter()) {
        self.writer = writer
    }

    public func apply(diffs: [FileDiff], in root: URL) throws -> [AppliedPatchResult] {
        var backups: [URL: Data?] = [:]
        var results: [AppliedPatchResult] = []

        do {
            for diff in diffs {
                let targetURL = root.appendingPathComponent(diff.path)
                let originalData = try? Data(contentsOf: targetURL)
                backups[targetURL] = originalData
                let originalContent = originalData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                let patched = try UnifiedDiffApplier.apply(patch: diff.patch, to: originalContent)
                try writer.write(patched, to: targetURL)
                results.append(AppliedPatchResult(path: diff.path, applied: true, message: "applied"))
            }
        } catch {
            try RollbackManager.rollback(backups: backups, writer: writer)
            throw error
        }

        return results
    }
}

private enum UnifiedDiffApplier {
    static func apply(patch: String, to original: String) throws -> String {
            let sourceLines = original.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var result: [String] = []
        var currentIndex = 0

        let lines = patch.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var idx = 0
        while idx < lines.count {
            let line = lines[idx]
            guard line.hasPrefix("@@") else {
                idx += 1
                continue
            }
            guard let header = HunkHeader(line) else { throw PatchError.invalidHeader(line) }
            // Append unchanged lines up to hunk start
            let targetStart = max(header.newStart - 1, 0)
            if targetStart > currentIndex {
                result.append(contentsOf: sourceLines[currentIndex..<min(targetStart, sourceLines.count)])
                currentIndex = targetStart
            }
            idx += 1
            while idx < lines.count, !lines[idx].hasPrefix("@@") {
                let hunkLine = lines[idx]
                if hunkLine.hasPrefix(" ") {
                    let content = String(hunkLine.dropFirst())
                    if currentIndex < sourceLines.count {
                        // best effort consistency check
                        currentIndex += 1
                    }
                    result.append(content)
                } else if hunkLine.hasPrefix("-") {
                    currentIndex += 1
                } else if hunkLine.hasPrefix("+") {
                    let content = String(hunkLine.dropFirst())
                    result.append(content)
                }
                idx += 1
            }
        }
        if currentIndex < sourceLines.count {
            result.append(contentsOf: sourceLines[currentIndex..<sourceLines.count])
        }
        return result.joined(separator: "\n")
    }

    private struct HunkHeader {
        let oldStart: Int
        let newStart: Int

        init?(_ line: String) {
            // @@ -a,b +c,d @@
            let pattern = #"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) else { return nil }
            func intAt(_ idx: Int) -> Int? {
                let range = match.range(at: idx)
                guard let swiftRange = Range(range, in: line) else { return nil }
                return Int(line[swiftRange])
            }
            guard let oldStart = intAt(1), let newStart = intAt(2) else { return nil }
            self.oldStart = oldStart
            self.newStart = newStart
        }
    }

    enum PatchError: Error {
        case invalidHeader(String)
    }
}

private enum RollbackManager {
    static func rollback(backups: [URL: Data?], writer: FileWriteAdapter) throws {
        for (url, data) in backups {
            if let data {
                try writer.write(String(data: data, encoding: .utf8) ?? "", to: url)
            } else {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
            }
        }
    }
}

