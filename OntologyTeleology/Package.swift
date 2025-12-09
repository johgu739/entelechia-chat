// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OntologyTeleology",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "OntologyTeleology",
            targets: ["OntologyTeleology"]
        )
    ],
    dependencies: [
        .package(name: "ArchitectureGuardian", path: "../ArchitectureGuardian"),
        .package(name: "OntologyCore", path: "../OntologyCore"),
        .package(name: "OntologyAct", path: "../OntologyAct"),
        .package(name: "OntologyState", path: "../OntologyState")
    ],
    targets: [
        .target(
            name: "OntologyTeleology",
            dependencies: [
                .product(name: "OntologyCore", package: "OntologyCore"),
                .product(name: "OntologyAct", package: "OntologyAct"),
                .product(name: "OntologyState", package: "OntologyState")
            ],
            plugins: [
                .plugin(name: "ArchitectureGuardian", package: "ArchitectureGuardian")
            ]
        ),
        .testTarget(
            name: "OntologyTeleologyTests",
            dependencies: ["OntologyTeleology"]
        )
    ]
)
