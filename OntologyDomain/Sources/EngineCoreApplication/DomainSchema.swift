import OntologyCore

public struct DomainScope: Hashable, Sendable {
    public let name: String
    public init(_ name: String) {
        self.name = name
    }
}

public protocol DomainSchemaProtocol: Sendable {
    var name: String { get }
    var allowedPropositionKinds: Set<PropositionKind> { get }
    var allowedRelationKinds: Set<RelationKind> { get }
    var requiredInvariants: [Invariant] { get }
    var domainScopes: Set<DomainScope> { get }
    var teleologyDescription: String { get }
    var enforceTeleologyBeforeSeal: Bool { get }
    func canonicalDecompositionScopes(for state: PropositionSet) -> [DomainScope]
    func canonicalProjectionRules(for state: PropositionSet) -> [Projection]
    func canonicalRetrodictionRules(for state: PropositionSet) -> [Prerequisite]
    func localScope(for proposition: Proposition) -> DomainScope
}

