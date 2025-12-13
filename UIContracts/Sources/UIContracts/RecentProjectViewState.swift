import Foundation

/// Recent project state for UI display (pure value type).
public struct RecentProjectViewState: Equatable, Sendable {
    public let name: String
    public let url: URL
    public let lastOpened: Date?
    
    public init(
        name: String,
        url: URL,
        lastOpened: Date? = nil
    ) {
        self.name = name
        self.url = url
        self.lastOpened = lastOpened
    }
}


