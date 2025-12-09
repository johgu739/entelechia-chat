// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OntologyState",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "OntologyState",
            targets: ["OntologyState"]
        )
    ],
    dependencies: [
        .package(name: "ArchitectureGuardian", path: "../ArchitectureGuardian"),
        .package(name: "OntologyCore", path: "../OntologyCore"),
        .package(name: "OntologyAct", path: "../OntologyAct")
    ],
    targets: [
        .target(
            name: "OntologyState",
            dependencies: [
                .product(name: "OntologyCore", package: "OntologyCore"),
                .product(name: "OntologyAct", package: "OntologyAct")
            ],
            plugins: [
                .plugin(name: "ArchitectureGuardian", package: "ArchitectureGuardian")
            ]
        ),
        .testTarget(
            name: "OntologyStateTests",
            dependencies: ["OntologyState"]
        )
    ]
)
