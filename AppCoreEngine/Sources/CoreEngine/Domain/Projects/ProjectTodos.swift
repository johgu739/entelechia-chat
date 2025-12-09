import Foundation

public struct ProjectTodos: Decodable, Sendable {
    public let generatedAt: String?
    public let missingHeaders: [String]
    public let missingFolderTelos: [String]
    public let filesWithIncompleteHeaders: [String]
    public let foldersWithIncompleteTelos: [String]
    public let allTodos: [String]

    public static let empty = ProjectTodos()

    /// Total count used for badges.
    public var totalCount: Int {
        if !allTodos.isEmpty {
            return allTodos.count
        }
        return missingHeaders.count
        + missingFolderTelos.count
        + filesWithIncompleteHeaders.count
        + foldersWithIncompleteTelos.count
    }

    /// Flattened todos used for display.
    public var flatTodos: [String] {
        if !allTodos.isEmpty {
            return allTodos
        }

        var todos: [String] = []
        todos.append(contentsOf: missingHeaders.map { "Missing header: \($0)" })
        todos.append(contentsOf: missingFolderTelos.map { "Missing folder telos: \($0)" })
        todos.append(contentsOf: filesWithIncompleteHeaders.map { "Incomplete header: \($0)" })
        todos.append(contentsOf: foldersWithIncompleteTelos.map { "Incomplete folder telos: \($0)" })
        return todos
    }

    public init(
        generatedAt: String? = nil,
        missingHeaders: [String] = [],
        missingFolderTelos: [String] = [],
        filesWithIncompleteHeaders: [String] = [],
        foldersWithIncompleteTelos: [String] = [],
        allTodos: [String] = []
    ) {
        self.generatedAt = generatedAt
        self.missingHeaders = missingHeaders
        self.missingFolderTelos = missingFolderTelos
        self.filesWithIncompleteHeaders = filesWithIncompleteHeaders
        self.foldersWithIncompleteTelos = foldersWithIncompleteTelos
        self.allTodos = allTodos
    }

    private enum CodingKeys: String, CodingKey {
        case generatedAt = "GeneratedAt"
        case missingHeaders = "MissingHeaders"
        case missingFolderTelos = "MissingFolderTelos"
        case filesWithIncompleteHeaders = "FilesWithIncompleteHeaders"
        case foldersWithIncompleteTelos = "FoldersWithIncompleteTelos"
        case allTodos = "AllTodos"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            generatedAt: try container.decodeIfPresent(String.self, forKey: .generatedAt),
            missingHeaders: try container.decodeIfPresent([String].self, forKey: .missingHeaders) ?? [],
            missingFolderTelos: try container.decodeIfPresent([String].self, forKey: .missingFolderTelos) ?? [],
            filesWithIncompleteHeaders: try container.decodeIfPresent([String].self, forKey: .filesWithIncompleteHeaders) ?? [],
            foldersWithIncompleteTelos: try container.decodeIfPresent([String].self, forKey: .foldersWithIncompleteTelos) ?? [],
            allTodos: try container.decodeIfPresent([String].self, forKey: .allTodos) ?? []
        )
    }
}

