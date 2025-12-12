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
        .package(name: "AppCoreEngine", path: "../AppCoreEngine"),
        .package(name: "AppAdapters", path: "../AppAdapters"),
        .package(name: "UIContracts", path: "../UIContracts")
    ],
    targets: [
        .target(
            name: "UIConnections",
            dependencies: [
                .product(name: "AppCoreEngine", package: "AppCoreEngine"),
                .product(name: "AppAdapters", package: "AppAdapters"),
                .product(name: "UIContracts", package: "UIContracts")
            ]
        ),
        .testTarget(
            name: "UIConnectionsTests",
            dependencies: [
                "UIConnections",
                .product(name: "AppCoreEngine", package: "AppCoreEngine"),
                .product(name: "AppAdapters", package: "AppAdapters")
            ]
        )
    ]
)
