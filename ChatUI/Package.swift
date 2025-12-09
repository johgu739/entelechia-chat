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
        .package(name: "ArchitectureGuardian", path: "../ArchitectureGuardian"),
        .package(name: "UIConnections", path: "../UIConnections"),
        .package(name: "AppComposition", path: "../AppComposition")
    ],
    targets: [
        .target(
            name: "ChatUI",
            dependencies: [
                .product(name: "UIConnections", package: "UIConnections"),
                .product(name: "AppComposition", package: "AppComposition")
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
            ],
            plugins: [
                .plugin(name: "ArchitectureGuardian", package: "ArchitectureGuardian")
            ]
        ),
        .testTarget(
            name: "ChatUITests",
            dependencies: [
                "ChatUI",
                .product(name: "AppComposition", package: "AppComposition")
            ]
        )
    ]
)
