import Foundation

public struct GuardianRunner {
    public static func findViolations(
        rules: [String: [String]],
        fileContents: [String: String],
        targetName: String
    ) -> [String] {
        guard let allowed = rules[targetName] else { return [] }
        var violations: [String] = []
        for (file, content) in fileContents {
            for line in content.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("import ") else { continue }
                let parts = trimmed.split(separator: " ", maxSplits: 1)
                guard parts.count == 2 else { continue }
                let module = String(parts[1])
                let cleanModule = module.replacingOccurrences(of: "@_exported", with: "").trimmingCharacters(in: .whitespaces)
                if !allowed.contains(cleanModule) {
                    let allowedList = allowed.joined(separator: ", ")
                    violations.append("\(file): illegal import '\(cleanModule)' in target '\(targetName)'. Allowed: \(allowedList)")
                }
            }
        }
        return violations
    }
}

