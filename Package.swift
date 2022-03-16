// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "MMMArrayChanges",
    platforms: [
        .iOS(.v11),
        .watchOS(.v2),
        .tvOS(.v9),
        .macOS(.v10_10)
    ],
    products: [
        .library(
            name: "MMMArrayChanges",
            targets: ["MMMArrayChanges"]
		)
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MMMArrayChanges",
            dependencies: [],
            path: "Sources/MMMArrayChanges"
		),
        .testTarget(
            name: "MMMArrayChangesTests",
            dependencies: ["MMMArrayChanges"],
            path: "Tests/MMMArrayChangesTestCase"
		)
    ]
)

