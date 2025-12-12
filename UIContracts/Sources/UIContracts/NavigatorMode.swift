import Foundation

/// Navigator mode matching Xcode's navigator tabs (UI concern only, pure value type).
public enum NavigatorMode: String, CaseIterable, Sendable {
    case project = "Project"
    case todos = "Ontology TODOs"
    case search = "Search"
    case issues = "Issues"
    case tests = "Tests"
    case reports = "Reports"
}

