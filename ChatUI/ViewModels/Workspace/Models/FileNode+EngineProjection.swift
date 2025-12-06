import Foundation
import CoreEngine
import UniformTypeIdentifiers
private typealias FileExclusion = CoreEngine.FileExclusion

extension FileNode {
    /// Build a UI `FileNode` tree from Engine `FileDescriptor` values.
    /// - Parameters:
    ///   - descriptors: Flat list of descriptors returned from `WorkspaceEngine.descriptors()`.
    ///   - rootPath: Absolute root path used when opening the workspace.
    /// - Returns: Root `FileNode` or `nil` if descriptors are empty or malformed.
    static func fromDescriptors(_ descriptors: [FileDescriptor], rootPath: String) -> FileNode? {
        guard !descriptors.isEmpty else { return nil }

        let descriptorMap = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.id, $0) })
        let childIDs = Set(descriptors.flatMap { $0.children })
        guard
            let rootDescriptor = descriptors.first(where: { !childIDs.contains($0.id) })
        else {
            return nil
        }

        let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
        return buildNode(
            descriptor: rootDescriptor,
            url: rootURL,
            descriptorMap: descriptorMap
        )
    }

    private static func buildNode(
        descriptor: FileDescriptor,
        url: URL,
        descriptorMap: [FileID: FileDescriptor]
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
                let childURL = url.appendingPathComponent(child.name, isDirectory: child.type == .directory)
                return buildNode(descriptor: child, url: childURL, descriptorMap: descriptorMap)
            }
            children = childNodes.sorted(by: sortNodes)
        } else {
            children = nil
        }

        return FileNode(
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
}

