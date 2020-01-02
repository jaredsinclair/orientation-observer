// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "OrientationObserver",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "OrientationObserver",
            targets: ["OrientationObserver"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jaredsinclair/CircularBuffer", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "OrientationObserver",
            dependencies: ["CircularBuffer"]),
        .testTarget(
            name: "OrientationObserverTests",
            dependencies: ["OrientationObserver"]),
    ]
)
