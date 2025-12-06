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
        .package(path: "../Engine")
    ],
    targets: [
        .target(
            name: "UIConnections",
            dependencies: [
                .product(name: "Engine", package: "Engine")
            ]
        ),
        .testTarget(
            name: "UIConnectionsTests",
            dependencies: ["UIConnections"]
        )
    ]
)

