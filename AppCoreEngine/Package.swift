// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppCoreEngine",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AppCoreEngine",
            targets: ["AppCoreEngine"]
        )
    ],
    dependencies: [
        .package(name: "ArchitectureGuardian", path: "../ArchitectureGuardian")
    ],
    targets: [
        .target(
            name: "AppCoreEngine",
            dependencies: [],
            plugins: [
                .plugin(name: "ArchitectureGuardian", package: "ArchitectureGuardian")
            ]
        ),
        .testTarget(
            name: "AppCoreEngineTests",
            dependencies: ["AppCoreEngine"]
        )
    ]
)

