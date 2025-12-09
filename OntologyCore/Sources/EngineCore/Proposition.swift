public struct Scope: Hashable, Sendable {
    public var name: String
    public init(_ name: String) {
        self.name = name
    }
}

public struct Provenance: Hashable, Sendable {
    public var source: String
    public var note: String?
    public init(source: String, note: String? = nil) {
        self.source = source
        self.note = note
    }
}

public struct PropositionID: Hashable, Sendable {
    public var rawValue: String
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public enum PropositionKind: Sendable {
    case fact
    case claim
    case observation
    case rule
    case delta
}

public struct ValidityWindow: Hashable, Sendable {
    public var fromLogical: String?
    public var untilLogical: String?
    public init(fromLogical: String? = nil, untilLogical: String? = nil) {
        self.fromLogical = fromLogical
        self.untilLogical = untilLogical
    }
}

public struct Proposition: Hashable, Sendable {
    public var id: PropositionID
    public var kind: PropositionKind
    public var content: String
    public var scope: Scope
    public var provenance: Provenance?
    public var contextTags: [String]
    public var validity: ValidityWindow?

    public init(
        id: PropositionID,
        kind: PropositionKind,
        content: String,
        scope: Scope,
        provenance: Provenance? = nil,
        contextTags: [String] = [],
        validity: ValidityWindow? = nil
    ) {
        self.id = id
        self.kind = kind
        self.content = content
        self.scope = scope
        self.provenance = provenance
        self.contextTags = contextTags
        self.validity = validity
    }
}

