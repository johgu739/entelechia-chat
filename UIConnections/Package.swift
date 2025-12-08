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
        .package(path: "../CoreEngine")
    ],
    targets: [
        .target(
            name: "UIConnections",
            dependencies: [
                .product(name: "CoreEngine", package: "CoreEngine")
            ]
        ),
        .testTarget(
            name: "UIConnectionsTests",
            dependencies: ["UIConnections"]
        )
    ]
)
