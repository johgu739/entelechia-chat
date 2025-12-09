// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ArchitectureGuardian",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .plugin(
            name: "ArchitectureGuardian",
            targets: ["ArchitectureGuardian"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ArchitectureGuardianTool"
        ),
        .plugin(
            name: "ArchitectureGuardian",
            capability: .buildTool(),
            dependencies: ["ArchitectureGuardianTool"]
        )
    ]
)


