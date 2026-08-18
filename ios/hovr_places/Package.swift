// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "hovr_places",
    platforms: [
        .iOS("16.0"),
    ],
    products: [
        .library(name: "hovr-places", targets: ["hovr_places"]),
    ],
    targets: [
        .target(
            name: "hovr_places",
            path: "Sources/hovr_places",
            exclude: [
                "HovrPlacesPlugin.swift",
                "PlacesChannelHandler.swift",
                "PlacesSessionStore.swift",
                "PrivacyInfo.xcprivacy",
            ]
        ),
        .testTarget(
            name: "PlacesArgParsersTests",
            dependencies: ["hovr_places"],
            path: "Tests"
        ),
    ]
)
