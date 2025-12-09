import Foundation

struct ArchitectureGuardianTool {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count >= 4 else {
            fputs("ArchitectureGuardian: missing arguments\n", stderr)
            exit(1)
        }
        let rulesPath = args[1]
        let outputPath = args[2]
        let files = Array(args.dropFirst(3))

        let data = try Data(contentsOf: URL(fileURLWithPath: rulesPath))
        let rules = try JSONDecoder().decode([String: [String]].self, from: data)

        var violations: [String] = []

        for file in files {
            var isDir: ObjCBool = false
            if !FileManager.default.fileExists(atPath: file, isDirectory: &isDir) { continue }
            if isDir.boolValue { continue }
            guard let targetName = targetNameFromEnv() else { continue }
            guard let allowed = rules[targetName] else { continue }
            let contents = try String(contentsOfFile: file)
            for line in contents.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("import ") else { continue }
                let parts = trimmed.split(separator: " ", maxSplits: 1)
                guard parts.count == 2 else { continue }
                var module = String(parts[1])
                module = module.replacingOccurrences(of: "@_exported", with: "").trimmingCharacters(in: .whitespaces)
                if !allowed.contains(module) {
                    let allowedList = allowed.joined(separator: ", ")
                    violations.append("\(file): illegal import '\(module)' in target '\(targetName)'. Allowed: \(allowedList)")
                }
            }
        }

        if !violations.isEmpty {
            for v in violations { fputs(v + "\n", stderr) }
            exit(1)
        }

        // Emit a marker file so the build tool has an output.
        let outURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("ok".utf8).write(to: outURL)
    }

    private static func targetNameFromEnv() -> String? {
        ProcessInfo.processInfo.environment["TARGET_NAME"]
    }
}

// Entry point
try ArchitectureGuardianTool.main()


