// swift-tools-version: 6.0
// FLODesignSystem — Shared design tokens and components for FLO
// Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import PackageDescription

let package = Package(
    name: "FLODesignSystem",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "FLODesignSystem",
            targets: ["FLODesignSystem"]
        ),
    ],
    targets: [
        .target(
            name: "FLODesignSystem",
            path: "Sources/FLODesignSystem"
        ),
        .testTarget(
            name: "FLODesignSystemTests",
            dependencies: ["FLODesignSystem"],
            path: "Tests/FLODesignSystemTests"
        ),
    ]
)
