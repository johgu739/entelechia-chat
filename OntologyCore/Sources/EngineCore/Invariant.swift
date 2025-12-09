public struct InvariantID: Hashable, Sendable {
    public var rawValue: String
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public enum InvariantKind: Sendable {
    case precondition
    case postcondition
    case state
    case ordering
    case teleology
}

public enum InvariantSeverity: Sendable {
    case must
    case should
}

public struct Invariant: Hashable, Sendable {
    public var id: InvariantID
    public var kind: InvariantKind
    public var scope: Scope
    public var statement: String
    public var severity: InvariantSeverity
    public var provenance: Provenance?

    public init(
        id: InvariantID,
        kind: InvariantKind,
        scope: Scope,
        statement: String,
        severity: InvariantSeverity,
        provenance: Provenance? = nil
    ) {
        self.id = id
        self.kind = kind
        self.scope = scope
        self.statement = statement
        self.severity = severity
        self.provenance = provenance
    }
}

