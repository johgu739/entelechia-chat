import Foundation

/// Project todos for UI display (pure value type).
public struct ProjectTodos: Decodable, Equatable, Sendable {
    public let generatedAt: String?
    public let missingHeaders: [String]
    public let missingFolderTelos: [String]
    public let filesWithIncompleteHeaders: [String]
    public let foldersWithIncompleteTelos: [String]
    public let allTodos: [String]
    
    public static let empty = ProjectTodos()
    
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

