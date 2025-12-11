import Foundation

public struct ArchitectureRules: Codable {
    public var targets: [String: TargetRules]
    public var globalForbidden: [ForbiddenRule]?
}

public struct TargetRules: Codable {
    public var allowedImports: [String]
    public var forbidden: [ForbiddenRule]?
}

public struct ForbiddenRule: Codable {
    public var regex: String
    public var message: String
    public var excludedPaths: [String]?
    public var onlyTargets: [String]?
    public var excludedTargets: [String]?
}

public struct GuardianRunner {
    public static func findViolations(
        rules: ArchitectureRules,
        fileContents: [String: String],
        targetName: String
    ) -> [String] {
        guard let targetRules = rules.targets[targetName] else { return [] }
        var violations: [String] = []

        // Import checks
        violations.append(contentsOf: checkImports(
            allowed: targetRules.allowedImports,
            files: fileContents,
            targetName: targetName
        ))

        // Target-specific forbidden patterns
        if let forbidden = targetRules.forbidden {
            violations.append(contentsOf: checkForbidden(
                rules: forbidden,
                files: fileContents,
                targetName: targetName
            ))
        }

        // Global forbidden constructors / patterns
        if let global = rules.globalForbidden {
            violations.append(contentsOf: checkForbidden(
                rules: global,
                files: fileContents,
                targetName: targetName
            ))
        }

        return violations
    }
}

// MARK: - Private helpers

private extension GuardianRunner {
    static func checkImports(
        allowed: [String],
        files: [String: String],
        targetName: String
    ) -> [String] {
        var violations: [String] = []
        for (file, content) in files {
            for line in content.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("import ") else { continue }
                let parts = trimmed.split(separator: " ", maxSplits: 1)
                guard parts.count == 2 else { continue }
                let module = String(parts[1])
                let cleanModule = module
                    .replacingOccurrences(of: "@_exported", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !allowed.contains(cleanModule) {
                    let allowedList = allowed.joined(separator: ", ")
                    violations.append("\(file): illegal import '\(cleanModule)' in target '\(targetName)'. Allowed: \(allowedList)")
                }
            }
        }
        return violations
    }

    static func checkForbidden(
        rules: [ForbiddenRule],
        files: [String: String],
        targetName: String
    ) -> [String] {
        var violations: [String] = []
        for rule in rules where isRuleApplicable(rule, to: targetName) {
            guard let matcher = try? NSRegularExpression(pattern: rule.regex, options: []) else { continue }
            for (file, content) in files {
                if let excluded = rule.excludedPaths, excluded.contains(where: { file.hasSuffix($0) }) {
                    continue
                }
                let range = NSRange(location: 0, length: (content as NSString).length)
                if matcher.firstMatch(in: content, options: [], range: range) != nil {
                    violations.append("\(file): \(rule.message)")
                }
            }
        }
        return violations
    }

    static func isRuleApplicable(_ rule: ForbiddenRule, to target: String) -> Bool {
        if let only = rule.onlyTargets, !only.contains(target) {
            return false
        }
        if let excluded = rule.excludedTargets, excluded.contains(target) {
            return false
        }
        return true
    }
}
