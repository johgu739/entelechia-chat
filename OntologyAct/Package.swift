// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OntologyAct",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "OntologyAct",
            targets: ["OntologyAct"]
        )
    ],
    dependencies: [
        .package(name: "ArchitectureGuardian", path: "../ArchitectureGuardian"),
        .package(name: "OntologyCore", path: "../OntologyCore")
    ],
    targets: [
        .target(
            name: "OntologyAct",
            dependencies: [
                .product(name: "OntologyCore", package: "OntologyCore")
            ],
            plugins: [
                .plugin(name: "ArchitectureGuardian", package: "ArchitectureGuardian")
            ]
        )
    ]
)
