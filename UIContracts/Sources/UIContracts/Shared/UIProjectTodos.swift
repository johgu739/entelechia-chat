import Foundation

/// UI mirror of ProjectTodos (immutable, no computed properties).
public struct UIProjectTodos: Sendable, Equatable {
    public let generatedAt: String?
    public let missingHeaders: [String]
    public let missingFolderTelos: [String]
    public let filesWithIncompleteHeaders: [String]
    public let foldersWithIncompleteTelos: [String]
    public let allTodos: [String]
    
    public static let empty = UIProjectTodos()
    
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
}

