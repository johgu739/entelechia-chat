// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChatUI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ChatUI",
            targets: ["ChatUI"]
        )
    ],
    dependencies: [
        .package(name: "UIConnections", path: "../UIConnections")
    ],
    targets: [
        .target(
            name: "ChatUI",
            dependencies: [
                .product(name: "UIConnections", package: "UIConnections")
            ],
            exclude: [],
            resources: [
                .process("Assets/Assets.xcassets")
            ],
            swiftSettings: [
                .enableUpcomingFeature("DisableOutwardActorInference"),
                .enableUpcomingFeature("InferSendableFromCaptures"),
                .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("InferIsolatedConformances"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault")
            ]
        ),
        .testTarget(
            name: "ChatUITests",
            dependencies: [
                "ChatUI",
                .product(name: "UIConnections", package: "UIConnections")
            ]
        )
    ]
)
