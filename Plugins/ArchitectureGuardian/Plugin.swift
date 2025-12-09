import PackagePlugin
import Foundation

@main
struct ArchitectureGuardian: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let target = target as? SwiftSourceModuleTarget else { return [] }

        // Tool executable
        let tool = try context.tool(named: "ArchitectureGuardianTool")

        // Output log (must be produced even on no-op). Mirror Xcode's expected layout:
        // <workdir>/<target>/ArchitectureGuardian/<target>-archguard.txt
        let outputDir = context.pluginWorkDirectory
            .appending(target.name)
            .appending("ArchitectureGuardian")
        let output = outputDir.appending("\(target.name)-archguard.txt")

        // Only Swift sources are relevant; the plugin must handle empty lists.
        let sources = target.sourceFiles(withSuffix: "swift")
        let sourcePaths = sources.map { $0.path }

        // Hint for the rules file (absolute path); the tool will self-resolve.
        let rulesHint = context.package.directory.appending("ArchitectureRules.json")

        var inputs: [Path] = [rulesHint]
        inputs.append(contentsOf: sourcePaths)

        var arguments: [String] = [
            "--output", output.string,
            "--rules-hint", rulesHint.string
        ]
        arguments.append(contentsOf: sourcePaths.map { $0.string })

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

