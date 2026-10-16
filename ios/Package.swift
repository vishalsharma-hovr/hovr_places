// swift-tools-version: 5.9
// Test-only manifest for `swift test` on the arg parsers. Kept outside
// ios/hovr_places/ so Flutter does not treat the plugin as Swift Package
// Manager-ready: the plugin needs the GooglePlaces pod and ships via CocoaPods.

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
            path: "hovr_places/Sources/hovr_places",
            exclude: [
                "HovrPlacesPlugin.swift",
                "PlacesChannelHandler.swift",
                "PlacesResultMaps.swift",
                "PlacesSessionStore.swift",
                "PrivacyInfo.xcprivacy",
            ]
        ),
        .testTarget(
            name: "PlacesArgParsersTests",
            dependencies: ["hovr_places"],
            path: "hovr_places/Tests"
        ),
    ]
)
