// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EPUBDecoder",
    platforms: [
        .macOS(.v10_11), .iOS(.v9), .watchOS(.v3)
    ],
    products: [
        .library(
            name: "EPUBDecoder",
            targets: ["EPUBDecoder"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tadija/AEXML.git", .upToNextMajor(from: "4.5.9")),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMajor(from: "0.9.0"))
    ],
    targets: [
        .target(
            name: "EPUBDecoder",
            dependencies: [.product(name: "AEXML", package: "AEXML"),
                           .product(name: "ZIPFoundation", package: "ZIPFoundation")])
    ]
)
