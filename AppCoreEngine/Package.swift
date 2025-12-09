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
        // No external dependencies; keep the Engine pure and portable.
    ],
    targets: [
        .target(
            name: "AppCoreEngine",
            dependencies: []
        ),
        .testTarget(
            name: "AppCoreEngineTests",
            dependencies: ["AppCoreEngine"]
        )
    ]
)

