import Foundation
import Darwin

/// Creates a unique temporary directory for file-based tests.
func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

/// Temporarily overrides the process HOME directory so Application Support paths are sandboxed.
struct TemporaryHome {
    let url: URL
    private let previousHome: String?
    private let previousAppSupport: String?

    init() throws {
        url = try makeTemporaryDirectory()
        previousHome = ProcessInfo.processInfo.environment["HOME"]
        previousAppSupport = ProcessInfo.processInfo.environment["ENTELECHIA_APP_SUPPORT"]
        setenv("HOME", url.path, 1)
        let appSupportOverride = url
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .path
        setenv("ENTELECHIA_APP_SUPPORT", appSupportOverride, 1)
    }

    func restore() {
        if let previousHome {
            setenv("HOME", previousHome, 1)
        } else {
            unsetenv("HOME")
        }
        
        if let previousAppSupport {
            setenv("ENTELECHIA_APP_SUPPORT", previousAppSupport, 1)
        } else {
            unsetenv("ENTELECHIA_APP_SUPPORT")
        }

        try? FileManager.default.removeItem(at: url)
    }
}

