// @EntelechiaHeaderStart
// Substance: Attachment model
// Genus: Conversation data model
// Differentia: Represents message attachment metadata
// Form: Codable fields describing an attachment
// Matter: Attachment metadata values
// Powers: Represent attachment data
// FinalCause: Carry attachment info within messages
// Relations: Participates in conversations; used by stores/services
// CausalityType: Material
// @EntelechiaHeaderEnd

import Foundation

/// Attachment model for messages
enum Attachment: Codable, Equatable {
    case file(path: String)
    case code(language: String, content: String)
    
    enum CodingKeys: String, CodingKey {
        case type
        case path
        case language
        case content
    }
    
    init(from decoder: Decoder) throws {
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
    
    func encode(to encoder: Encoder) throws {
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
