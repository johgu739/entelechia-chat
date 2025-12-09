import PackagePlugin
import Foundation

@main
struct ArchitectureGuardian: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let target = target as? SwiftSourceModuleTarget else { return [] }
        let tool = try context.tool(named: "ArchitectureGuardianTool")
        let repoRoot = context.package.directory.removingLastComponent()
        let rules = repoRoot.appending(["ArchitectureGuardian", "ArchitectureRules.json"])
        let output = context.pluginWorkDirectory.appending("\(target.name)-archguard.txt")
        var inputs = [rules]
        inputs.append(contentsOf: target.sourceFiles.map { $0.path })

        var arguments: [String] = []
        arguments.append(rules.string)
        arguments.append(output.string)
        arguments.append(contentsOf: target.sourceFiles.map { $0.path.string })

        return [
            .buildCommand(
                displayName: "ArchitectureGuardian: \(target.name)",
                executable: tool.path,
                arguments: arguments,
                environment: ["TARGET_NAME": target.name],
                inputFiles: inputs,
                outputFiles: [output]
            )
        ]
    }
}


