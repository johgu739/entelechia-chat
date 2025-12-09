public struct View: Hashable, Sendable {
    public var slice: SliceID?
    public var scope: Scope
    public var lens: String?
    public var summary: String?

    public init(
        slice: SliceID? = nil,
        scope: Scope,
        lens: String? = nil,
        summary: String? = nil
    ) {
        self.slice = slice
        self.scope = scope
        self.lens = lens
        self.summary = summary
    }
}

