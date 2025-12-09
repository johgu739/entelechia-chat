import Foundation

/// Shared context preparation pipeline that prioritizes descriptor identity and
/// shims path-based callers.
public struct ConversationContextResolver: Sendable {
    private let workspacePreparer: WorkspaceContextPreparer
    private let fileLoader: FileContentLoading
    private let contextBuilder: ContextBuilder

    public var defaultBudget: ContextBudget { contextBuilder.budgetConfig }

    public init(
        fileLoader: FileContentLoading,
        contextBuilder: ContextBuilder = ContextBuilder()
    ) {
        self.workspacePreparer = WorkspaceContextPreparer(fileLoader: fileLoader)
        self.fileLoader = fileLoader
        self.contextBuilder = contextBuilder
    }

    public func resolve(from request: ConversationContextRequest?) async throws -> ContextBuildResult {
        let budget = request?.budget ?? contextBuilder.budgetConfig

        if let snapshot = request?.snapshot {
            return try await workspacePreparer.prepare(
                snapshot: snapshot,
                preferredDescriptorIDs: request?.preferredDescriptorIDs,
                budget: budget
            )
        }

        if let urls = request?.contextFileURLs, !urls.isEmpty {
            let files = try await load(urls: urls)
            return ContextBuilder(budget: budget).build(from: files)
        }

        if let url = request?.fallbackContextURL {
            let files = try await load(urls: [url])
            return ContextBuilder(budget: budget).build(from: files)
        }

        return ContextBuilder(budget: budget).build(from: [])
    }

    // MARK: - Helpers

    private func load(urls: [URL]) async throws -> [LoadedFile] {
        try await withThrowingTaskGroup(of: LoadedFile?.self) { group in
            for url in urls {
                group.addTask {
                    do {
                        let content = try await fileLoader.load(url: url)
                        return LoadedFile(
                            name: url.lastPathComponent,
                            url: url,
                            content: content,
                            fileTypeIdentifier: url.pathExtension.isEmpty ? nil : url.pathExtension
                        )
                    } catch {
                        throw EngineError.contextLoadFailed("Failed to load \(url.path): \(error.localizedDescription)")
                    }
                }
            }

            var files: [LoadedFile] = []
            for try await file in group {
                if let file { files.append(file) }
            }
            return files
        }
    }
}


