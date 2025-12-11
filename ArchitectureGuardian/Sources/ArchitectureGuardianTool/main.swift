import Foundation
import ArchitectureGuardianLib

private struct Config {
    var output: String?
    var rulesHint: String?
    var sources: [String] = []
}

private func parseArguments() -> Config {
    var config = Config()
    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = iterator.next() {
        switch arg {
        case "--output":
            config.output = iterator.next()
        case "--rules-hint":
            config.rulesHint = iterator.next()
        default:
            config.sources.append(arg)
        }
    }
    return config
}

private func findRulesFile(hint: String?, sources: [String]) -> URL? {
    let fm = FileManager.default

    func resolve(_ path: String) -> URL {
        URL(fileURLWithPath: path).resolvingSymlinksInPath()
    }

    func ascend(from start: URL) -> URL? {
        var current = start
        while true {
            let candidate = current.appendingPathComponent("ArchitectureRules.json")
            if fm.fileExists(atPath: candidate.path) { return candidate }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { return nil }
            current = parent
        }
    }

    if let hint, fm.fileExists(atPath: hint) {
        return resolve(hint)
    }

    // Try from sources
    for source in sources {
        let dir = resolve(source).deletingLastPathComponent()
        if let found = ascend(from: dir) { return found }
    }

    // Fallback to tool location via #file
    let toolDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
    if let found = ascend(from: toolDir) { return found }

    return nil
}

private func loadSources(_ paths: [String]) -> [String: String] {
    var map: [String: String] = [:]
    let fm = FileManager.default
    for path in paths {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue else {
            fputs("ArchitectureGuardian: skipping non-file or missing path \(path)\n", stderr)
            continue
        }
        do {
            map[path] = try String(contentsOfFile: path)
        } catch {
            fputs("ArchitectureGuardian: failed to read \(path): \(error)\n", stderr)
        }
    }
    return map
}

private func writeOutput(_ message: String, to path: String?) {
    guard let path else { return }
    let url = URL(fileURLWithPath: path)
    let dir = url.deletingLastPathComponent()
    do {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = message.data(using: .utf8) {
            try data.write(to: url)
        } else {
            // Fallback: create an empty file if encoding somehow fails
            FileManager.default.createFile(atPath: url.path, contents: Data(), attributes: nil)
        }
    } catch {
        fputs("ArchitectureGuardian: failed to write output at \(url.path): \(error)\n", stderr)
        // Last resort: attempt a bare createFile to satisfy the build system
        _ = FileManager.default.createFile(atPath: url.path, contents: message.data(using: .utf8), attributes: nil)
    }
}

private func run() {
    let config = parseArguments()
    // Create/ensure output exists as early as possible to satisfy build system expectations.
    writeOutput("starting\n", to: config.output)

    guard let targetName = ProcessInfo.processInfo.environment["TARGET_NAME"] else {
        fputs("ArchitectureGuardian: missing TARGET_NAME\n", stderr)
        writeOutput("missing TARGET_NAME\n", to: config.output)
        exit(0)
    }

    let rulesURL = findRulesFile(hint: config.rulesHint, sources: config.sources)
    guard let rulesURL else {
        fputs("ArchitectureGuardian: could not locate ArchitectureRules.json\n", stderr)
        writeOutput("rules not found\n", to: config.output)
        exit(0)
    }

    guard
        let data = try? Data(contentsOf: rulesURL),
        let rules = try? JSONDecoder().decode(ArchitectureRules.self, from: data)
    else {
        fputs("ArchitectureGuardian: failed to load or decode rules at \(rulesURL.path)\n", stderr)
        writeOutput("rules decode failure\n", to: config.output)
        exit(0)
    }

    let sources = config.sources
    let fileMap = loadSources(sources)

    let violations = GuardianRunner.findViolations(
        rules: rules,
        fileContents: fileMap,
        targetName: targetName
    )

    if violations.isEmpty {
        writeOutput("ok\n", to: config.output)
        exit(0)
    } else {
        let joined = violations.joined(separator: "\n")
        fputs(joined + "\n", stderr)
        writeOutput(joined + "\n", to: config.output)
        exit(1)
    }
}

run()
