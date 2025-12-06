import Foundation

/// Exclusion utility for workspace file tree building (pure, portable).
public enum FileExclusion {
    // MARK: - Forbidden Directory Names

    public static let forbiddenDirectoryNames: Set<String> = [
        ".git",
        ".swift-module-cache",
        ".build",
        "DerivedData",
        ".idea",
        ".vscode",
        "Pods",
        "Carthage",
        "node_modules",
        ".Trash",
        ".history",
        "tmp_home",
        ".tmp_home",
        "xcuserdata",
        "xcshareddata"
    ]

    // MARK: - Whitelisted Dot-Prefixed Directories

    /// Dot-prefixed directories that are explicitly allowed (none by default)
    public static let whitelistedDotDirectories: Set<String> = []

    // MARK: - Forbidden File Names

    public static let forbiddenFileNames: Set<String> = [
        ".DS_Store",
        "Package.resolved",
        ".swiftpm"
    ]

    // MARK: - Forbidden File Extensions

    public static let forbiddenExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "heic",
        "mp3", "wav",
        "ttf", "otf",
        "o", "swiftmodule", "swiftdoc",
        "xcuserstate", "xcworkspacedata"
    ]

    // MARK: - Core Exclusion Logic

    /// Returns true if the directory should be excluded from file tree.
    public static func isForbiddenDirectory(url: URL) -> Bool {
        let pathComponents = url.pathComponents

        for component in pathComponents {
            if forbiddenDirectoryNames.contains(component) {
                return true
            }

            if component.hasPrefix(".") && !whitelistedDotDirectories.contains(component) {
                return true
            }
        }

        return false
    }

    /// Returns true if the file should be excluded from file tree.
    public static func isForbiddenFile(url: URL) -> Bool {
        let fileName = url.lastPathComponent

        if forbiddenFileNames.contains(fileName) {
            return true
        }

        let ext = url.pathExtension.lowercased()
        if !ext.isEmpty && forbiddenExtensions.contains(ext) {
            return true
        }

        return false
    }
}

