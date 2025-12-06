// @EntelechiaHeaderStart
// Signifier: ContextBuilder
// Substance: Conversation context governor
// Genus: Intelligence service
// Differentia: Applies byte/token limits and generates summaries
// Form: Deterministic budgeting over LoadedFile collections
// Matter: Loaded files; budget limits; exclusion reasons
// Powers: Trim oversized files; exclude overflow; surface diagnostics
// FinalCause: Deliver ontology-safe context to Codex without exceeding limits
// Relations: Serves ConversationService, inspectors, and UI affordances
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation

struct ContextBudget: Equatable {
    let maxPerFileBytes: Int
    let maxPerFileTokens: Int
    let maxTotalBytes: Int
    let maxTotalTokens: Int

    static let `default` = ContextBudget(
        maxPerFileBytes: 32 * 1024,        // 32 KB per file
        maxPerFileTokens: 8_000,          // ~8k tokens per file
        maxTotalBytes: 220 * 1024,        // ~220 KB per request
        maxTotalTokens: 60_000            // leave headroom of 68k for dialog
    )
}

struct ContextBuildResult: Equatable {
    let attachments: [LoadedFile]
    let truncatedFiles: [LoadedFile]
    let excludedFiles: [ContextExclusion]
    let totalBytes: Int
    let totalTokens: Int
    let budget: ContextBudget

    var attachmentCount: Int { attachments.count }
}

struct ContextExclusion: Identifiable, Equatable {
    let id = UUID()
    let file: LoadedFile
    let reason: ContextExclusionReason
}

struct ContextBuilder {
    private let budget: ContextBudget
    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter
    }()

    init(budget: ContextBudget = .default) {
        self.budget = budget
    }

    func build(from files: [LoadedFile]) -> ContextBuildResult {
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

        return ContextBuildResult(
            attachments: attachments,
            truncatedFiles: truncated,
            excludedFiles: exclusions,
            totalBytes: runningBytes,
            totalTokens: runningTokens,
            budget: budget
        )
    }

    private func trimmedFile(from file: LoadedFile) -> LoadedFile {
        let limit = min(budget.maxPerFileBytes, budget.maxTotalBytes)
        let trimmedContent = truncate(content: file.content, byteLimit: limit)
        let trimmedBytes = trimmedContent.utf8.count
        let trimmedTokens = TokenEstimator.estimateTokens(for: trimmedContent)
        let note = """
Trimmed from \(byteFormatter.string(fromByteCount: Int64(file.originalByteCount ?? file.byteCount))) \
to \(byteFormatter.string(fromByteCount: Int64(trimmedBytes))) to respect the per-file limit.
"""

        return LoadedFile(
            id: file.id,
            name: file.name,
            url: file.url,
            content: trimmedContent,
            fileType: file.fileType,
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
            fileType: file.fileType,
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

        var accumulated = 0
        var index = content.startIndex

        while index < content.endIndex {
            let character = content[index]
            let characterByteCount = String(character).utf8.count
            if accumulated + characterByteCount > byteLimit {
                break
            }
            accumulated += characterByteCount
            index = content.index(after: index)
        }

        let prefix = String(content[..<index])
        let metadata = """
…
[Context trimmed automatically to \(byteFormatter.string(fromByteCount: Int64(byteLimit))) of text. \
Original size was \(byteFormatter.string(fromByteCount: Int64(content.utf8.count)))]
"""
        return prefix + metadata
    }
}
