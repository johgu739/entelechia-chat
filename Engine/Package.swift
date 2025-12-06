// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Engine",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Engine",
            targets: ["Engine"]
        )
    ],
    dependencies: [
        // No external dependencies; keep the Engine pure and portable.
    ],
    targets: [
        .target(
            name: "Engine",
            dependencies: []
        ),
        .testTarget(
            name: "EngineTests",
            dependencies: ["Engine"]
        )
    ]
)

