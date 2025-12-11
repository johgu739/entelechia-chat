import XCTest

final class ArchitectureBoundariesTests: XCTestCase {
    private let sourcesRoot = URL(fileURLWithPath: #file)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources")

    private let allowedImports: Set<String> = [
        "Foundation",
        "Combine",
        "os",
        "os.log",
        "AppAdapters",
        "AppCoreEngine"
    ]

    private let forbiddenImports: Set<String> = [
        "SwiftUI",
        "AppKit",
        "ChatUI",
        "AppComposition"
    ]

    func testUIConnectionsHasNoForbiddenImports() throws {
        let importViolations = try scanImports()
            .filter { forbiddenImports.contains($0.module) }
            .map { "\($0.file):\($0.line): forbidden import \($0.module)" }

        XCTAssertTrue(importViolations.isEmpty, "Forbidden imports found:\n\(importViolations.joined(separator: "\n"))")
    }

    func testUIConnectionsUsesOnlyAllowedImports() throws {
        let violations = try scanImports()
            .filter { !allowedImports.contains($0.module) }
            .map { "\($0.file):\($0.line): disallowed import '\($0.module)'. Allowed: \(allowedImports.sorted().joined(separator: ", "))" }

        XCTAssertTrue(violations.isEmpty, "Disallowed imports found:\n\(violations.joined(separator: "\n"))")
    }

    private struct ImportLine {
        let file: String
        let line: Int
        let module: String
    }

    private func scanImports() throws -> [ImportLine] {
        let fm = FileManager.default
        var results: [ImportLine] = []

        let enumerator = fm.enumerator(at: sourcesRoot, includingPropertiesForKeys: nil)!
        while let url = enumerator.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let contents = try String(contentsOf: url)
            for (idx, line) in contents.split(separator: "\n").enumerated() where line.trimmingCharacters(in: .whitespaces).hasPrefix("import ") {
                let module = line
                    .replacingOccurrences(of: "import", with: "")
                    .replacingOccurrences(of: "@_exported", with: "")
                    .trimmingCharacters(in: .whitespaces)
                results.append(ImportLine(file: url.lastPathComponent, line: idx + 1, module: module))
            }
        }

        return results
    }
}
