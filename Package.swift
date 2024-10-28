// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "iCloudSyncStatusKit",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .watchOS(.v7),
        .tvOS(.v14),
        .visionOS(.v1),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "iCloudSyncStatusKit",
            targets: ["iCloudSyncStatusKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/fatbobman/SimpleLogger.git", from: "0.1.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "iCloudSyncStatusKit",
            dependencies: ["SimpleLogger"]
        ),
        .testTarget(
            name: "iCloudSyncStatusKitTests",
            dependencies: ["iCloudSyncStatusKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
