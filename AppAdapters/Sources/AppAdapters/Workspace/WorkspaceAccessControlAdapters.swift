import Foundation
import AppCoreEngine
import UniformTypeIdentifiers

public struct DefaultWorkspaceBoundaryFilter: WorkspaceBoundaryFiltering {
    private let denyPrefixes: [String]
    private let denyComponents: Set<String>
    private let ontologyPrefix = "Ontology"

    public init(denyList: [String] = [".git", ".build", "DerivedData", "build", "node_modules", "Pods", ".swiftpm"]) {
        self.denyPrefixes = denyList
        self.denyComponents = Set(denyList)
    }

    public func allows(canonicalPath: String) -> Bool {
        let components = canonicalPath.split(separator: "/").map(String.init)
        for component in components {
            if denyComponents.contains(component) { return false }
            if component.hasPrefix(ontologyPrefix) { return false }
            if component.hasPrefix(".") && !component.isEmpty && component != ".entelechia" {
                return false
            }
        }
        return true
    }
}

public struct DefaultWorkspaceRootProvider: WorkspaceRootProviding {
    private let boundary: WorkspaceBoundaryFiltering

    public init(boundary: WorkspaceBoundaryFiltering = DefaultWorkspaceBoundaryFilter()) {
        self.boundary = boundary
    }

    public func canonicalRoot(for path: String) throws -> String {
        let url = URL(fileURLWithPath: path)
        let canonical = url.resolvingSymlinksInPath().standardizedFileURL.path
        guard boundary.allows(canonicalPath: canonical) else {
            throw WorkspaceError.pathDenied(canonical)
        }
        return canonical
    }
}

public enum WorkspaceError: LocalizedError {
    case pathDenied(String)
    case binaryFile(String)
    case oversizedFile(String, Int, Int)

    public var errorDescription: String? {
        switch self {
        case .pathDenied(let path):
            return "Path denied by boundary filter: \(path)"
        case .binaryFile(let path):
            return "Binary or unsupported file: \(path)"
        case .oversizedFile(let path, let size, let limit):
            return "File too large for descriptor: \(path) (\(size) > \(limit) bytes)"
        }
    }
}


