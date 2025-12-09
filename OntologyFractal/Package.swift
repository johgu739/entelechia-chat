// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OntologyFractal",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "OntologyFractal",
            targets: ["OntologyFractal"]
        )
    ],
    dependencies: [
        .package(name: "ArchitectureGuardian", path: "../ArchitectureGuardian"),
        .package(name: "OntologyCore", path: "../OntologyCore"),
        .package(name: "OntologyAct", path: "../OntologyAct"),
        .package(name: "OntologyState", path: "../OntologyState"),
        .package(name: "OntologyTeleology", path: "../OntologyTeleology"),
        .package(name: "OntologyIntelligence", path: "../OntologyIntelligence")
    ],
    targets: [
        .target(
            name: "OntologyFractal",
            dependencies: [
                .product(name: "OntologyCore", package: "OntologyCore"),
                .product(name: "OntologyAct", package: "OntologyAct"),
                .product(name: "OntologyState", package: "OntologyState"),
                .product(name: "OntologyTeleology", package: "OntologyTeleology"),
                .product(name: "OntologyIntelligence", package: "OntologyIntelligence")
            ],
            plugins: [
                .plugin(name: "ArchitectureGuardian", package: "ArchitectureGuardian")
            ]
        ),
        .testTarget(
            name: "OntologyFractalTests",
            dependencies: ["OntologyFractal"]
        )
    ]
)
