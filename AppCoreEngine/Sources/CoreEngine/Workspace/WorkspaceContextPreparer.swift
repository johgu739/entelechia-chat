import Foundation

public struct WorkspaceContextPreparer: Sendable {
    private let fileLoader: FileContentLoading

    public init(fileLoader: FileContentLoading) {
        self.fileLoader = fileLoader
    }

    /// Build a context bundle from an engine-owned snapshot and preferences.
    /// - Parameters:
    ///   - snapshot: Engine-issued workspace snapshot.
    ///   - preferredDescriptorIDs: Optional descriptor focus; falls back to snapshot selection or context preferences.
    ///   - budget: Context budget to enforce.
    /// - Returns: Context build result with loaded files and budget accounting.
    public func prepare(
        snapshot: WorkspaceSnapshot,
        preferredDescriptorIDs: [FileID]? = nil,
        budget: ContextBudget = .default
    ) async throws -> ContextBuildResult {
        let descriptorMap = Dictionary(uniqueKeysWithValues: snapshot.descriptors.map { ($0.id, $0) })
        let pathMap = snapshot.descriptorPaths
        let descriptorIDsByPath = Dictionary(uniqueKeysWithValues: pathMap.map { ($0.value, $0.key) })
        let exclusions = snapshot.contextPreferences.excludedPaths
        let inclusions = snapshot.contextPreferences.includedPaths

        if let preferred = preferredDescriptorIDs, !preferred.isEmpty {
            let missing = preferred.filter { pathMap[$0] == nil }
            if !missing.isEmpty {
                throw EngineError.contextLoadFailed("Descriptor missing for ids: \(missing.count)")
            }
        }

        let candidatePaths = resolveCandidatePaths(
            snapshot: snapshot,
            preferredDescriptorIDs: preferredDescriptorIDs,
            pathMap: pathMap,
            inclusions: inclusions,
            exclusions: exclusions
        )

        var loadedFiles: [LoadedFile] = []
        for path in candidatePaths {
            guard let descriptorID = descriptorIDsByPath[path] else {
                throw EngineError.contextLoadFailed("Descriptor missing for path: \(path)")
            }
            guard let descriptor = descriptorMap[descriptorID], descriptor.type == .file else {
                continue
            }
            let url = URL(fileURLWithPath: path)
            do {
                let content = try await fileLoader.load(url: url)
                let included = !exclusions.contains(path) && (inclusions.isEmpty || inclusions.contains(path))
                let file = LoadedFile(
                    name: descriptor.name,
                    url: url,
                    content: content,
                    fileTypeIdentifier: url.pathExtension.isEmpty ? nil : url.pathExtension,
                    isIncludedInContext: included
                )
                loadedFiles.append(file)
            } catch {
                throw EngineError.contextLoadFailed("Failed to load \(path): \(error.localizedDescription)")
            }
        }

        let builder = ContextBuilder(budget: budget)
        return builder.build(from: loadedFiles)
    }

    // MARK: - Helpers

    private func resolveCandidatePaths(
        snapshot: WorkspaceSnapshot,
        preferredDescriptorIDs: [FileID]?,
        pathMap: [FileID: String],
        inclusions: Set<String>,
        exclusions: Set<String>
    ) -> [String] {
        if !inclusions.isEmpty {
            return inclusions.filter { !exclusions.contains($0) }
        }

        if let preferred = preferredDescriptorIDs, !preferred.isEmpty {
            return preferred.compactMap { pathMap[$0] }.filter { !exclusions.contains($0) }
        }

        if let selectedID = snapshot.selectedDescriptorID,
           let path = pathMap[selectedID],
           !exclusions.contains(path) {
            return [path]
        }

        if let selectedPath = snapshot.selectedPath,
           !exclusions.contains(selectedPath) {
            return [selectedPath]
        }

        if let focused = snapshot.contextPreferences.lastFocusedFilePath,
           !exclusions.contains(focused) {
            return [focused]
        }

        return []
    }
}


