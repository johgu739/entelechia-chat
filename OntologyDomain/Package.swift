// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OntologyDomain",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "OntologyDomain",
            targets: ["OntologyDomain"]
        )
    ],
    dependencies: [
        .package(name: "OntologyCore", path: "../OntologyCore"),
        .package(name: "OntologyAct", path: "../OntologyAct"),
        .package(name: "OntologyState", path: "../OntologyState"),
        .package(name: "OntologyTeleology", path: "../OntologyTeleology"),
        .package(name: "OntologyIntelligence", path: "../OntologyIntelligence"),
        .package(name: "OntologyFractal", path: "../OntologyFractal"),
        .package(name: "OntologyIntegration", path: "../OntologyIntegration")
    ],
    targets: [
        .target(
            name: "OntologyDomain",
            dependencies: [
                .product(name: "OntologyCore", package: "OntologyCore"),
                .product(name: "OntologyAct", package: "OntologyAct"),
                .product(name: "OntologyState", package: "OntologyState"),
                .product(name: "OntologyTeleology", package: "OntologyTeleology"),
                .product(name: "OntologyIntelligence", package: "OntologyIntelligence"),
                .product(name: "OntologyFractal", package: "OntologyFractal"),
                .product(name: "OntologyIntegration", package: "OntologyIntegration")
            ]
        ),
        .testTarget(
            name: "OntologyDomainTests",
            dependencies: ["OntologyDomain"]
        )
    ]
)
