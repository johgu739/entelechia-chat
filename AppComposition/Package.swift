// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppComposition",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AppComposition",
            targets: ["AppComposition"]
        )
    ],
    dependencies: [
        .package(name: "ArchitectureGuardian", path: "../ArchitectureGuardian"),
        .package(name: "AppCoreEngine", path: "../AppCoreEngine"),
        .package(name: "AppAdapters", path: "../AppAdapters"),
        .package(name: "OntologyIntegration", path: "../OntologyIntegration"),
        .package(name: "OntologyDomain", path: "../OntologyDomain")
    ],
    targets: [
        .target(
            name: "AppComposition",
            dependencies: [
                .product(name: "AppCoreEngine", package: "AppCoreEngine"),
                .product(name: "AppAdapters", package: "AppAdapters"),
                .product(name: "OntologyIntegration", package: "OntologyIntegration"),
                .product(name: "OntologyDomain", package: "OntologyDomain")
            ],
            resources: [
                .process("CodexSecrets.plist")
            ],
            plugins: [
                .plugin(name: "ArchitectureGuardian", package: "ArchitectureGuardian")
            ]
        )
    ]
)


