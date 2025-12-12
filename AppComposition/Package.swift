// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppComposition",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AppComposition",
            targets: ["AppComposition"]
        )
    ],
    dependencies: [
        .package(name: "AppCoreEngine", path: "../AppCoreEngine"),
        .package(name: "AppAdapters", path: "../AppAdapters"),
        .package(name: "OntologyIntegration", path: "../OntologyIntegration"),
        .package(name: "OntologyDomain", path: "../OntologyDomain"),
        .package(name: "UIConnections", path: "../UIConnections"),
        .package(name: "UIContracts", path: "../UIContracts"),
        .package(name: "ChatUI", path: "../ChatUI")
    ],
    targets: [
        .target(
            name: "AppComposition",
            dependencies: [
                .product(name: "AppCoreEngine", package: "AppCoreEngine"),
                .product(name: "AppAdapters", package: "AppAdapters"),
                .product(name: "OntologyIntegration", package: "OntologyIntegration"),
                .product(name: "OntologyDomain", package: "OntologyDomain"),
                .product(name: "UIConnections", package: "UIConnections"),
                .product(name: "UIContracts", package: "UIContracts"),
                .product(name: "ChatUI", package: "ChatUI")
            ],
            resources: [
                .process("CodexSecrets.plist")
            ]
        ),
        .testTarget(
            name: "AppCompositionTests",
            dependencies: ["AppComposition"]
        )
    ]
)


