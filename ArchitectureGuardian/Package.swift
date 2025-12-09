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
        .target(
            name: "ArchitectureGuardianLib"
        ),
        .executableTarget(
            name: "ArchitectureGuardianTool",
            dependencies: ["ArchitectureGuardianLib"]
        ),
        .plugin(
            name: "ArchitectureGuardian",
            capability: .buildTool(),
            dependencies: ["ArchitectureGuardianTool"]
        ),
        .testTarget(
            name: "ArchitectureGuardianTests",
            dependencies: ["ArchitectureGuardianLib"]
        )
    ]
)


