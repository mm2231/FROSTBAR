// swift-tools-version: 5.8
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import PackageDescription

let package = Package(
    name: "FrostBar",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "FrostBarCore", targets: ["FrostBarCore"]),
        .library(name: "FrostBarModes", targets: ["FrostBarModes"]),
        .library(name: "FrostBarProfiles", targets: ["FrostBarProfiles"]),
        .library(name: "FrostBarSMC", targets: ["FrostBarSMC"]),
        .executable(name: "FrostBarProbe", targets: ["FrostBarProbe"]),
    ],
    targets: [
        .target(name: "SMCKit", path: "Vendored/SMCKit/Sources/SMCKit"),
        .target(name: "FrostBarCore"),
        .target(name: "FrostBarProfiles", dependencies: ["FrostBarCore"]),
        .target(name: "FrostBarModes", dependencies: ["FrostBarCore", "FrostBarProfiles"]),
        .target(
            name: "FrostBarSMC",
            dependencies: ["FrostBarCore", "SMCKit"],
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .executableTarget(
            name: "FrostBarProbe",
            dependencies: ["FrostBarCore", "FrostBarSMC"],
            path: "Tools/SMCProbe"
        ),
        .testTarget(name: "FrostBarCoreTests", dependencies: ["FrostBarCore"]),
        .testTarget(name: "FrostBarModesTests", dependencies: ["FrostBarModes"]),
        .testTarget(name: "FrostBarProfilesTests", dependencies: ["FrostBarProfiles"]),
        .testTarget(name: "FrostBarSMCTests", dependencies: ["FrostBarSMC"]),
    ]
)
