// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_nfc_kit",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "flutter-nfc-kit", targets: ["flutter_nfc_kit"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "flutter_nfc_kit",
            dependencies: [],
            resources: []
        )
    ]
)