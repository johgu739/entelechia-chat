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
        .package(name: "OntologyCore", path: "../OntologyCore"),
        .package(name: "OntologyAct", path: "../OntologyAct"),
        .package(name: "OntologyState", path: "../OntologyState"),
        .package(name: "OntologyTeleology", path: "../OntologyTeleology"),
        .package(name: "OntologyIntelligence", path: "../OntologyIntelligence"),
        .package(name: "OntologyFractal", path: "../OntologyFractal")
    ],
    targets: [
        .target(
            name: "OntologyIntegration",
            dependencies: [
                .product(name: "OntologyCore", package: "OntologyCore"),
                .product(name: "OntologyAct", package: "OntologyAct"),
                .product(name: "OntologyState", package: "OntologyState"),
                .product(name: "OntologyTeleology", package: "OntologyTeleology"),
                .product(name: "OntologyIntelligence", package: "OntologyIntelligence"),
                .product(name: "OntologyFractal", package: "OntologyFractal")
            ]
        ),
        .testTarget(
            name: "OntologyIntegrationTests",
            dependencies: ["OntologyIntegration"]
        )
    ]
)
