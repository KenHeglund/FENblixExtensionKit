// swift-tools-version: 6.2
// Created on 2026-11-13
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

import PackageDescription

/// The settings every target here is compiled with: Swift 6 language mode (the
/// tools version's default), plus the upcoming features Xcode's "Approachable
/// Concurrency" and member import visibility turn on.
let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility")
]

/// The framework FENblix extensions are written against, and its tests.
let package = Package(
    name: "FENblixExtensionKit",
    platforms: [
        .macOS("26.5")
    ],
    products: [
        .library(name: "FENblixExtensionKit", targets: ["FENblixExtensionKit"])
    ],
    targets: [
        .target(
            name: "FENblixExtensionKit",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "FENblixExtensionKitTests",
            dependencies: ["FENblixExtensionKit"],
            swiftSettings: swiftSettings
        )
    ]
)
