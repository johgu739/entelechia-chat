// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UIConnections",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "UIConnections",
            targets: ["UIConnections"]
        )
    ],
    dependencies: [
        .package(name: "ArchitectureGuardian", path: "../ArchitectureGuardian"),
        .package(name: "AppCoreEngine", path: "../AppCoreEngine")
    ],
    targets: [
        .target(
            name: "UIConnections",
            dependencies: [
                .product(name: "AppCoreEngine", package: "AppCoreEngine")
            ],
            plugins: [
                .plugin(name: "ArchitectureGuardian", package: "ArchitectureGuardian")
            ]
        ),
        .testTarget(
            name: "UIConnectionsTests",
            dependencies: ["UIConnections"]
        )
    ]
)
