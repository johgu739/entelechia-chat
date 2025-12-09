import Foundation

public struct ContextBudget: Equatable, Sendable {
    public let maxPerFileBytes: Int
    public let maxPerFileTokens: Int
    public let maxTotalBytes: Int
    public let maxTotalTokens: Int

    public static let `default` = ContextBudget(
        maxPerFileBytes: 32 * 1024,        // 32 KB per file
        maxPerFileTokens: 8_000,           // ~8k tokens per file
        maxTotalBytes: 220 * 1024,         // ~220 KB per request
        maxTotalTokens: 60_000             // leave headroom of 68k for dialog
    )
}

public struct ContextBuildResult: Equatable, Sendable {
    public let attachments: [LoadedFile]
    public let truncatedFiles: [LoadedFile]
    public let excludedFiles: [ContextExclusion]
    public let totalBytes: Int
    public let totalTokens: Int
    public let budget: ContextBudget
    public let encodedSegments: [ContextSegment]

    public var attachmentCount: Int { attachments.count }

    public init(
        attachments: [LoadedFile],
        truncatedFiles: [LoadedFile],
        excludedFiles: [ContextExclusion],
        totalBytes: Int,
        totalTokens: Int,
        budget: ContextBudget,
        encodedSegments: [ContextSegment] = []
    ) {
        self.attachments = attachments
        self.truncatedFiles = truncatedFiles
        self.excludedFiles = excludedFiles
        self.totalBytes = totalBytes
        self.totalTokens = totalTokens
        self.budget = budget
        self.encodedSegments = encodedSegments
    }
}

public struct ContextExclusion: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let file: LoadedFile
    public let reason: ContextExclusionReason

    public init(id: UUID = UUID(), file: LoadedFile, reason: ContextExclusionReason) {
        self.id = id
        self.file = file
        self.reason = reason
    }
}

public struct ContextBuilder: Sendable {
    private let budget: ContextBudget
    public var budgetConfig: ContextBudget { budget }

    public init(budget: ContextBudget = .default) {
        self.budget = budget
    }

    public func build(from files: [LoadedFile]) -> ContextBuildResult {
        var attachments: [LoadedFile] = []
        var truncated: [LoadedFile] = []
        var exclusions: [ContextExclusion] = []
        var runningBytes = 0
        var runningTokens = 0

        for file in files where file.isIncludedInContext {
            var workingFile = file

            if workingFile.byteCount > budget.maxPerFileBytes || workingFile.tokenEstimate > budget.maxPerFileTokens {
                let trimmed = trimmedFile(from: workingFile)
                workingFile = trimmed
                truncated.append(trimmed)
            }

            let candidateBytes = runningBytes + workingFile.byteCount
            if candidateBytes > budget.maxTotalBytes {
                let excludedFile = flaggedFile(
                    for: workingFile,
                    reason: .exceedsTotalBytes(limit: budget.maxTotalBytes)
                )
                exclusions.append(ContextExclusion(file: excludedFile, reason: .exceedsTotalBytes(limit: budget.maxTotalBytes)))
                continue
            }

            let candidateTokens = runningTokens + workingFile.tokenEstimate
            if candidateTokens > budget.maxTotalTokens {
                let excludedFile = flaggedFile(
                    for: workingFile,
                    reason: .exceedsTotalTokens(limit: budget.maxTotalTokens)
                )
                exclusions.append(ContextExclusion(file: excludedFile, reason: .exceedsTotalTokens(limit: budget.maxTotalTokens)))
                continue
            }

            attachments.append(workingFile)
            runningBytes = candidateBytes
            runningTokens = candidateTokens
        }

        let encoder = WorkspaceContextEncoder()
        let encodedFiles = encoder.encode(files: attachments)
        let segments = WorkspaceContextSegmenter(maxTokensPerSegment: 8_000).segment(files: encodedFiles)

        return ContextBuildResult(
            attachments: attachments,
            truncatedFiles: truncated,
            excludedFiles: exclusions,
            totalBytes: runningBytes,
            totalTokens: runningTokens,
            budget: budget,
            encodedSegments: segments
        )
    }

    private func trimmedFile(from file: LoadedFile) -> LoadedFile {
        let limit = min(budget.maxPerFileBytes, budget.maxTotalBytes)
        let trimmedContent = truncate(content: file.content, byteLimit: limit)
        let trimmedBytes = trimmedContent.utf8.count
        let trimmedTokens = TokenEstimator.estimateTokens(for: trimmedContent)
        let note = """
Trimmed from \(formatBytes(file.originalByteCount ?? file.byteCount)) \
to \(formatBytes(trimmedBytes)) to respect the per-file limit.
"""

        return LoadedFile(
            id: file.id,
            name: file.name,
            url: file.url,
            content: trimmedContent,
            fileTypeIdentifier: file.fileTypeIdentifier,
            isIncludedInContext: file.isIncludedInContext,
            byteCount: trimmedBytes,
            tokenEstimate: trimmedTokens,
            originalByteCount: file.originalByteCount ?? file.byteCount,
            originalTokenEstimate: file.originalTokenEstimate ?? file.tokenEstimate,
            contextNote: note,
            exclusionReason: nil
        )
    }

    private func flaggedFile(for file: LoadedFile, reason: ContextExclusionReason) -> LoadedFile {
        LoadedFile(
            id: file.id,
            name: file.name,
            url: file.url,
            content: file.content,
            fileTypeIdentifier: file.fileTypeIdentifier,
            isIncludedInContext: false,
            byteCount: file.byteCount,
            tokenEstimate: file.tokenEstimate,
            originalByteCount: file.originalByteCount,
            originalTokenEstimate: file.originalTokenEstimate,
            contextNote: file.contextNote,
            exclusionReason: reason
        )
    }

    private func truncate(content: String, byteLimit: Int) -> String {
        guard content.utf8.count > byteLimit else {
            return content
        }

        let metadata = """
…
[Context trimmed automatically to \(formatBytes(byteLimit)) of text. \
Original size was \(formatBytes(content.utf8.count))]
"""
        let metadataBytes = metadata.utf8.count
        let availableForContent = max(0, byteLimit - metadataBytes)

        var accumulated = 0
        var index = content.startIndex

        while index < content.endIndex {
            let character = content[index]
            let characterByteCount = String(character).utf8.count
            if accumulated + characterByteCount > availableForContent {
                break
            }
            accumulated += characterByteCount
            index = content.index(after: index)
        }

        let prefix = String(content[..<index])
        return prefix + metadata
    }

    private func formatBytes(_ count: Int) -> String {
        if count >= 1_048_576 {
            let mb = Double(count) / 1_048_576.0
            return String(format: "%.1f MB", mb)
        } else if count >= 1024 {
            let kb = Double(count) / 1024.0
            return String(format: "%.1f KB", kb)
        } else {
            return "\(count) B"
        }
    }
}

