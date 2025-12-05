// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EntelechiaOntologyGenerator",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "entelechia-ontology",
            targets: ["EntelechiaOntologyGenerator"]
        )
    ],
    targets: [
        .executableTarget(
            name: "EntelechiaOntologyGenerator",
            path: "Sources/EntelechiaOntologyGenerator"
        )
    ]
)
