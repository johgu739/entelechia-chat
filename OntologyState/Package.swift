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
        .package(name: "OntologyCore", path: "../OntologyCore"),
        .package(name: "OntologyAct", path: "../OntologyAct")
    ],
    targets: [
        .target(
            name: "OntologyState",
            dependencies: [
                .product(name: "OntologyCore", package: "OntologyCore"),
                .product(name: "OntologyAct", package: "OntologyAct")
            ]
        ),
        .testTarget(
            name: "OntologyStateTests",
            dependencies: ["OntologyState"]
        )
    ]
)
