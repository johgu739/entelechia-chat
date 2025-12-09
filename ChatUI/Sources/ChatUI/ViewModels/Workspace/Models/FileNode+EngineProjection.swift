import Foundation
import AppComposition
import UniformTypeIdentifiers
private typealias FileExclusion = AppCoreEngine.FileExclusion

extension FileNode {
    /// Build a UI `FileNode` tree from Engine `FileDescriptor` values.
    /// - Parameters:
    ///   - descriptors: Flat list of descriptors returned from `WorkspaceEngine.descriptors()`.
    ///   - rootPath: Absolute root path used when opening the workspace.
    ///   - descriptorPaths: Engine-issued absolute paths keyed by descriptor ID.
    /// - Returns: Root `FileNode` or `nil` if descriptors are empty or malformed.
    static func fromDescriptors(
        _ descriptors: [FileDescriptor],
        rootPath: String,
        descriptorPaths: [FileID: String] = [:]
    ) -> FileNode? {
        guard !descriptors.isEmpty else { return nil }

        let descriptorMap = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.id, $0) })
        let childIDs = Set(descriptors.flatMap { $0.children })
        guard
            let rootDescriptor = descriptors.first(where: { !childIDs.contains($0.id) })
        else {
            return nil
        }

        let rootURL = URL(fileURLWithPath: descriptorPaths[rootDescriptor.id] ?? rootPath, isDirectory: true)
        return buildNode(
            descriptor: rootDescriptor,
            url: rootURL,
            descriptorMap: descriptorMap,
            descriptorPaths: descriptorPaths
        )
    }

    private static func buildNode(
        descriptor: FileDescriptor,
        url: URL,
        descriptorMap: [FileID: FileDescriptor],
        descriptorPaths: [FileID: String]
    ) -> FileNode? {
        let isDirectory = descriptor.type == .directory

        // Apply the same exclusion rules used by the legacy tree builder.
        if isDirectory {
            if FileExclusion.isForbiddenDirectory(url: url) { return nil }
        } else {
            if FileExclusion.isForbiddenFile(url: url) { return nil }
        }

        let children: [FileNode]?
        if isDirectory {
            let childDescriptors = descriptor.children.compactMap { descriptorMap[$0] }
            let childNodes = childDescriptors.compactMap { child in
                let childURL = descriptorPaths[child.id].map {
                    URL(fileURLWithPath: $0, isDirectory: child.type == .directory)
                } ?? url.appendingPathComponent(child.name, isDirectory: child.type == .directory)
                return buildNode(descriptor: child, url: childURL, descriptorMap: descriptorMap, descriptorPaths: descriptorPaths)
            }
            children = childNodes.sorted(by: sortNodes)
        } else {
            children = nil
        }

        return FileNode(
            descriptorID: descriptor.id,
            name: descriptor.name,
            path: url,
            children: children,
            icon: icon(for: url, isDirectory: isDirectory),
            isDirectory: isDirectory
        )
    }

    private static func icon(for url: URL, isDirectory: Bool) -> String {
        guard !isDirectory else { return "folder" }
        let fileType = UTType(filenameExtension: url.pathExtension)
        if fileType?.conforms(to: .sourceCode) == true {
            return "doc.text"
        }
        if fileType?.conforms(to: .text) == true {
            return "doc.text"
        }
        if fileType?.conforms(to: .image) == true {
            return "photo"
        }
        return "doc"
    }

    private static func sortNodes(lhs: FileNode, rhs: FileNode) -> Bool {
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory && !rhs.isDirectory
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    /// Build a `FileNode` tree from an engine-issued `WorkspaceTreeProjection`.
    static func fromProjection(_ projection: WorkspaceTreeProjection) -> FileNode {
        let children = projection.children.map { fromProjection($0) }
        return FileNode(
            descriptorID: projection.id,
            name: projection.name,
            path: URL(fileURLWithPath: projection.path, isDirectory: projection.isDirectory),
            children: children.isEmpty ? nil : children.sorted(by: sortNodes),
            icon: projection.isDirectory ? "folder" : icon(for: URL(fileURLWithPath: projection.path), isDirectory: projection.isDirectory),
            isDirectory: projection.isDirectory
        )
    }
}

