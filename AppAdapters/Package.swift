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
        .package(name: "AppCoreEngine", path: "../AppCoreEngine")
    ],
    targets: [
        .target(
            name: "AppAdapters",
            dependencies: [
                .product(name: "AppCoreEngine", package: "AppCoreEngine")
            ]
        ),
        .testTarget(
            name: "AppAdaptersTests",
            dependencies: ["AppAdapters"]
        )
    ]
)

