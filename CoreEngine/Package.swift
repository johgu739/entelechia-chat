// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CoreEngine",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "CoreEngine",
            targets: ["CoreEngine"]
        )
    ],
    dependencies: [
        // No external dependencies; keep the Engine pure and portable.
    ],
    targets: [
        .target(
            name: "CoreEngine",
            dependencies: []
        ),
        .testTarget(
            name: "CoreEngineTests",
            dependencies: ["CoreEngine"]
        )
    ]
)

