// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OntologyIntelligence",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "OntologyIntelligence",
            targets: ["OntologyIntelligence"]
        )
    ],
    dependencies: [
        .package(name: "OntologyCore", path: "../OntologyCore"),
        .package(name: "OntologyAct", path: "../OntologyAct"),
        .package(name: "OntologyState", path: "../OntologyState"),
        .package(name: "OntologyTeleology", path: "../OntologyTeleology")
    ],
    targets: [
        .target(
            name: "OntologyIntelligence",
            dependencies: [
                .product(name: "OntologyCore", package: "OntologyCore"),
                .product(name: "OntologyAct", package: "OntologyAct"),
                .product(name: "OntologyState", package: "OntologyState"),
                .product(name: "OntologyTeleology", package: "OntologyTeleology")
            ]
        ),
        .testTarget(
            name: "OntologyIntelligenceTests",
            dependencies: ["OntologyIntelligence"]
        )
    ]
)
