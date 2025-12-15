// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "JunLogger",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .watchOS(.v7),
        .tvOS(.v14),
        .macCatalyst(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "JunLogger",
            targets: ["JunLogger"]
        ),
    ],
    targets: [
        .target(
            name: "JunLogger",
            dependencies: []
        ),
        .testTarget(
            name: "JunLoggerTests",
            dependencies: ["JunLogger"]
        ),
    ]
)
