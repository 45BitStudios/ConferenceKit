// swift-tools-version: 6.4
import PackageDescription

// AskKit’s minimum is 27.0 on every Apple platform. SwiftPM will not let the
// iOS 17 ConferenceKit package depend on it. This package is the opt-in.
let package = Package(
    name: "ConferenceKitAsk",
    platforms: [
        .iOS(.v27),
        .macOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27)
    ],
    products: [
        .library(name: "ConferenceKitAskLink", targets: ["ConferenceKitAskLink"])
    ],
    dependencies: [
        .package(name: "ConferenceKit", path: "../.."),
        .package(url: "https://github.com/45BitStudios/AskKit.git", branch: "main")
    ],
    targets: [
        .target(
            name: "ConferenceKitAskLink",
            dependencies: [
                .product(name: "ConferenceKit", package: "ConferenceKit"),
                .product(name: "AskKit", package: "AskKit")
            ],
            path: "Sources/ConferenceKitAskLink",
            swiftSettings: [
                .define("CONFERENCEKIT_ASK")
            ]
        ),
        .testTarget(
            name: "ConferenceKitAskLinkTests",
            dependencies: ["ConferenceKitAskLink"],
            path: "Tests/ConferenceKitAskLinkTests"
        )
    ]
)
