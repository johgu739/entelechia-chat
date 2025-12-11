import Foundation
import AppCoreEngine

public extension WorkspaceViewModel {
    func isPathIncludedInContext(_ url: URL) -> Bool {
        guard workspaceSnapshot.rootPath != nil else { return true }
        let path = url.path
        if let descriptorID = workspaceSnapshot.descriptorPaths.first(where: { $0.value == path })?.key,
           let inclusion = workspaceSnapshot.contextInclusions[descriptorID] {
            switch inclusion {
            case .excluded:
                return false
            case .included:
                return true
            case .neutral:
                return true
            }
        }
        return true
    }
    
    func setContextInclusion(_ include: Bool, for url: URL) {
        guard workspaceSnapshot.rootPath != nil else { return }
        Task {
            if let snapshot = try? await workspaceEngine.setContextInclusion(path: url.path, included: include) {
                let projection = await workspaceEngine.treeProjection()
                await MainActor.run {
                    applySnapshot(snapshot, projection: projection)
                }
            }
        }
    }
    
    func currentWorkspaceScope() -> WorkspaceScope? {
        switch activeScope {
        case .selection:
            if let descriptorID = selectedDescriptorID {
                return .descriptor(descriptorID)
            }
            if let path = selectedNode?.path.path {
                return .path(path)
            }
            return nil
        case .workspace:
            if let root = workspaceSnapshot.rootPath {
                return .path(root)
            }
            return nil
        case .selectionAndSiblings:
            if let descriptorID = selectedDescriptorID {
                return .descriptor(descriptorID)
            }
            return nil
        case .manual:
            if let descriptorID = selectedDescriptorID {
                return .descriptor(descriptorID)
            }
            return nil
        }
    }
    
    func buildContextSnapshot(from result: ContextBuildResult) -> ContextSnapshot {
        let encoder = WorkspaceContextEncoder()
        let encoded = encoder.encode(files: result.attachments)
        let encodedByPath = Dictionary(uniqueKeysWithValues: encoded.map { ($0.path, $0) })
        
        let segments = buildSegments(from: result.encodedSegments)
        let included = buildFileDescriptors(
            from: result.attachments,
            encodedByPath: encodedByPath,
            isIncluded: true,
            isTruncated: false
        )
        let truncated = buildFileDescriptors(
            from: result.truncatedFiles,
            encodedByPath: encodedByPath,
            isIncluded: true,
            isTruncated: true
        )
        let excluded = buildExcludedDescriptors(
            from: result.excludedFiles,
            encodedByPath: encodedByPath
        )
        
        return ContextSnapshot(
            scope: activeScope,
            snapshotHash: workspaceSnapshot.snapshotHash,
            segments: segments,
            includedFiles: included,
            truncatedFiles: truncated,
            excludedFiles: excluded,
            totalTokens: result.totalTokens,
            totalBytes: result.totalBytes
        )
    }
    
    private func buildSegments(
        from encodedSegments: [ContextBuildResult.EncodedSegment]
    ) -> [ContextSegmentDescriptor] {
        encodedSegments.map { segment in
            let files = segment.files.map { file in
                ContextFileDescriptor(
                    path: file.path,
                    language: file.language,
                    size: file.size,
                    hash: file.hash,
                    isIncluded: true,
                    isTruncated: false
                )
            }
            return ContextSegmentDescriptor(
                totalTokens: segment.totalTokens,
                totalBytes: segment.totalBytes,
                files: files
            )
        }
    }
    
    private func buildFileDescriptors(
        from files: [LoadedFile],
        encodedByPath: [String: WorkspaceContextEncoder.EncodedFile],
        isIncluded: Bool,
        isTruncated: Bool
    ) -> [ContextFileDescriptor] {
        files.sorted { $0.url.path < $1.url.path }.map { file in
            let path = file.url.path
            let encodedFile = encodedByPath[path]
            return ContextFileDescriptor(
                path: path,
                language: encodedFile?.language ?? file.fileTypeIdentifier,
                size: file.byteCount,
                hash: encodedFile?.hash ?? "",
                isIncluded: isIncluded,
                isTruncated: isTruncated
            )
        }
    }
    
    private func buildExcludedDescriptors(
        from excludedFiles: [ContextExclusion],
        encodedByPath: [String: WorkspaceContextEncoder.EncodedFile]
    ) -> [ContextFileDescriptor] {
        excludedFiles.sorted { $0.file.url.path < $1.file.url.path }.map { exclusion in
            let file = exclusion.file
            let path = file.url.path
            let encodedFile = encodedByPath[path]
            return ContextFileDescriptor(
                path: path,
                language: encodedFile?.language ?? file.fileTypeIdentifier,
                size: file.byteCount,
                hash: encodedFile?.hash ?? "",
                isIncluded: false,
                isTruncated: false
            )
        }
    }
}

