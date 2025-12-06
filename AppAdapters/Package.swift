// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppAdapters",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AppAdapters",
            targets: ["AppAdapters"]
        )
    ],
    dependencies: [
        .package(path: "../CoreEngine")
    ],
    targets: [
        .target(
            name: "AppAdapters",
            dependencies: [
                .product(name: "CoreEngine", package: "CoreEngine")
            ]
        ),
        .testTarget(
            name: "AppAdaptersTests",
            dependencies: ["AppAdapters"]
        )
    ]
)

