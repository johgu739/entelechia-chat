import Foundation

public enum FileKind: String {
    case sourceCode
    case text
    case image
    case pdf
    case other
}

struct FileTypeClassifier {
    static func kind(for url: URL) -> FileKind {
        let ext = url.pathExtension.lowercased()
        if sourceExtensions.contains(ext) { return .sourceCode }
        if textExtensions.contains(ext) { return .text }
        if imageExtensions.contains(ext) { return .image }
        if ext == "pdf" { return .pdf }
        return .other
    }

    static func icon(for url: URL, isDirectory: Bool) -> String {
        guard !isDirectory else { return "folder" }
        switch kind(for: url) {
        case .sourceCode, .text:
            return "doc.text"
        case .image:
            return "photo"
        case .pdf:
            return "doc.richtext"
        case .other:
            return "doc"
        }
    }

    static func isTextLike(_ kind: FileKind) -> Bool {
        kind == .text || kind == .sourceCode
    }

    private static let sourceExtensions: Set<String> = [
        "swift", "m", "mm", "c", "cc", "cpp", "cxx", "h", "hpp", "hh",
        "java", "kt", "kts", "ts", "tsx", "js", "jsx", "go", "rs",
        "py", "rb", "php", "cs", "sql", "sh", "bash", "zsh", "fish"
    ]

    private static let textExtensions: Set<String> = [
        "txt", "md", "markdown", "rst", "json", "yaml", "yml", "toml",
        "xml", "plist", "csv", "log"
    ]

    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "heic", "heif", "webp"
    ]
}

