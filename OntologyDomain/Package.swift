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
        .package(name: "OntologyIntegration", path: "../OntologyIntegration")
    ],
    targets: [
        .target(
            name: "OntologyDomain",
            dependencies: [
                .product(name: "OntologyIntegration", package: "OntologyIntegration")
            ]
        ),
        .testTarget(
            name: "OntologyDomainTests",
            dependencies: ["OntologyDomain"]
        )
    ]
)

