import Foundation

/// UI mirror of Attachment.
public enum UIAttachment: Sendable, Equatable {
    case file(path: String)
    case code(language: String, content: String)
}

