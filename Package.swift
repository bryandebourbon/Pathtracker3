// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Pathtracker3",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "Pathtracker3",
            targets: ["Pathtracker3"]
        ),
    ],
    targets: [
        .target(
            name: "Pathtracker3",
            dependencies: []
        ),
        .testTarget(
            name: "Pathtracker3Tests",
            dependencies: ["Pathtracker3"]
        ),
    ]
)