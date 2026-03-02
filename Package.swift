// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HealthKitRunGenerator",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HealthKitRunGenerator",
            targets: ["HealthKitRunGenerator"]
        ),
    ],
    targets: [
        .target(
            name: "HealthKitRunGenerator",
            path: "Sources/HealthKitRunGenerator"
        ),
        .testTarget(
            name: "HealthKitRunGeneratorTests",
            dependencies: ["HealthKitRunGenerator"],
            path: "Tests/HealthKitRunGeneratorTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
