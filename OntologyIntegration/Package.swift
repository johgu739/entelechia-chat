// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OntologyIntegration",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "OntologyIntegration",
            targets: ["OntologyIntegration"]
        )
    ],
    dependencies: [
        .package(name: "ArchitectureGuardian", path: "../ArchitectureGuardian"),
        .package(name: "OntologyFractal", path: "../OntologyFractal")
    ],
    targets: [
        .target(
            name: "OntologyIntegration",
            dependencies: [
                .product(name: "OntologyFractal", package: "OntologyFractal")
            ],
            plugins: [
                .plugin(name: "ArchitectureGuardian", package: "ArchitectureGuardian")
            ]
        ),
        .testTarget(
            name: "OntologyIntegrationTests",
            dependencies: ["OntologyIntegration"]
        )
    ]
)
