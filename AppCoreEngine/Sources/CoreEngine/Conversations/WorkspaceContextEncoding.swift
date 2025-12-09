import Foundation

public struct EncodedContextFile: Equatable, Sendable {
    public let path: String
    public let language: String?
    public let hash: String
    public let size: Int
    public let tokenEstimate: Int
    public let content: String
}

public struct ContextSegment: Equatable, Sendable {
    public let files: [EncodedContextFile]
    public let totalTokens: Int
    public let totalBytes: Int
}

public struct WorkspaceContextEncoder: Sendable {
    public init() {}

    public func encode(files: [LoadedFile]) -> [EncodedContextFile] {
        files
            .sorted { $0.url.path.localizedCaseInsensitiveCompare($1.url.path) == .orderedAscending }
            .map { file in
                let hash = Self.hash(for: file.content)
                return EncodedContextFile(
                    path: file.url.path,
                    language: file.fileTypeIdentifier,
                    hash: hash,
                    size: file.byteCount,
                    tokenEstimate: file.tokenEstimate,
                    content: file.content
                )
            }
    }

    private static func hash(for content: String) -> String {
        return StableHasher.sha256(data: Data(content.utf8))
    }
}

public struct WorkspaceContextSegmenter: Sendable {
    public let maxTokensPerSegment: Int
    public let maxBytesPerSegment: Int

    public init(maxTokensPerSegment: Int = 8_000, maxBytesPerSegment: Int = 64 * 1024) {
        self.maxTokensPerSegment = maxTokensPerSegment
        self.maxBytesPerSegment = maxBytesPerSegment
    }

    public func segment(files: [EncodedContextFile]) -> [ContextSegment] {
        var segments: [ContextSegment] = []
        var current: [EncodedContextFile] = []
        var runningTokens = 0
        var runningBytes = 0

        for file in files {
            let nextTokens = runningTokens + file.tokenEstimate
            let nextBytes = runningBytes + file.size
            if !current.isEmpty && (nextTokens > maxTokensPerSegment || nextBytes > maxBytesPerSegment) {
                segments.append(ContextSegment(files: current, totalTokens: runningTokens, totalBytes: runningBytes))
                current = []
                runningTokens = 0
                runningBytes = 0
            }
            current.append(file)
            runningTokens += file.tokenEstimate
            runningBytes += file.size
        }

        if !current.isEmpty {
            segments.append(ContextSegment(files: current, totalTokens: runningTokens, totalBytes: runningBytes))
        }
        return segments
    }
}

