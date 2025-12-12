// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UIContracts",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "UIContracts",
            targets: ["UIContracts"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "UIContracts",
            dependencies: []
        ),
        .testTarget(
            name: "UIContractsTests",
            dependencies: ["UIContracts"]
        )
    ]
)
