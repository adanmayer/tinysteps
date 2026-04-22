// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MBAPI",
    platforms: [
        .iOS(.v17),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "MBAPI",
            targets: ["MBAPI"]
        ),
    ],
    targets: [
        .target(
            name: "MBAPI"
        ),
        .testTarget(
            name: "MBAPITests",
            dependencies: ["MBAPI"]
        ),
    ]
)
