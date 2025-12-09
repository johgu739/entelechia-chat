import Foundation

/// Attachment model for messages.
public enum Attachment: Codable, Equatable, Sendable {
    case file(path: String)
    case code(language: String, content: String)

    private enum CodingKeys: String, CodingKey {
        case type
        case path
        case language
        case content
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "file":
            let path = try container.decode(String.self, forKey: .path)
            self = .file(path: path)
        case "code":
            let language = try container.decode(String.self, forKey: .language)
            let content = try container.decode(String.self, forKey: .content)
            self = .code(language: language, content: content)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown attachment type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .file(let path):
            try container.encode("file", forKey: .type)
            try container.encode(path, forKey: .path)
        case .code(let language, let content):
            try container.encode("code", forKey: .type)
            try container.encode(language, forKey: .language)
            try container.encode(content, forKey: .content)
        }
    }
}

