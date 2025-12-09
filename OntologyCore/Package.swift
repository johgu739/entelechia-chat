// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OntologyCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "OntologyCore",
            targets: ["OntologyCore"]
        )
    ],
    dependencies: [
        .package(name: "ArchitectureGuardian", path: "../ArchitectureGuardian")
    ],
    targets: [
        .target(
            name: "OntologyCore",
            dependencies: [],
            plugins: [
                .plugin(name: "ArchitectureGuardian", package: "ArchitectureGuardian")
            ]
        )
    ]
)
