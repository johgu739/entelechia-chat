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
    dependencies: [],
    targets: [
        .target(
            name: "OntologyCore",
            dependencies: []
        ),
        .testTarget(
            name: "OntologyCoreTests",
            dependencies: ["OntologyCore"]
        )
    ]
)
