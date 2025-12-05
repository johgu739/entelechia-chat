// @EntelechiaHeaderStart
// Signifier: ProjectTodos
// Substance: Project ontology TODOs manifest
// Genus: Project model
// Differentia: Represents ontology gaps per project
// Form: Decodable record of generated todos
// Matter: JSON fields for missing headers and teloi
// Powers: Expose counts and flattened todos
// FinalCause: Surface ontology work items to the UI
// Relations: Loaded when a project opens; serves navigator badge/list
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation

struct ProjectTodos: Decodable {
    let generatedAt: String?
    let missingHeaders: [String]
    let missingFolderTelos: [String]
    let filesWithIncompleteHeaders: [String]
    let foldersWithIncompleteTelos: [String]
    let allTodos: [String]
    
    static let empty = ProjectTodos()
    
    /// Total count used for badges.
    var totalCount: Int {
        if !allTodos.isEmpty {
            return allTodos.count
        }
        return missingHeaders.count
        + missingFolderTelos.count
        + filesWithIncompleteHeaders.count
        + foldersWithIncompleteTelos.count
    }
    
    /// Flattened todos used for display.
    var flatTodos: [String] {
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
    
    init(
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
    
    enum CodingKeys: String, CodingKey {
        case generatedAt = "GeneratedAt"
        case missingHeaders = "MissingHeaders"
        case missingFolderTelos = "MissingFolderTelos"
        case filesWithIncompleteHeaders = "FilesWithIncompleteHeaders"
        case foldersWithIncompleteTelos = "FoldersWithIncompleteTelos"
        case allTodos = "AllTodos"
    }
    
    init(from decoder: Decoder) throws {
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
