// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "iCloudSyncStatusKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17),
        .visionOS(.v1),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "iCloudSyncStatusKit",
            targets: ["iCloudSyncStatusKit"],
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/fatbobman/SimpleLogger.git", from: "0.8.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "iCloudSyncStatusKit",
            dependencies: ["SimpleLogger"],
            swiftSettings: [
                .enableUpcomingFeature("IsolatedDeinit"),
            ],
        ),
        .testTarget(
            name: "iCloudSyncStatusKitTests",
            dependencies: ["iCloudSyncStatusKit"],
        ),
    ],
    swiftLanguageModes: [.v6],
)
