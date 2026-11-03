// swift-tools-version: 6.0
import PackageDescription

// Siri AI Developer Preview (Xcode 27.3 / iOS 27.3 SDK) stays out of the default
// build. To compile it, add this setting to ConferenceKitIntents and ConferenceKitUI:
//   swiftSettings: [.define("SIRI_AI_PREVIEW")]
// Xcode 27.2 does not have the macros, so leave the flag unset.

let package = Package(
    name: "ConferenceKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "ConferenceKit", targets: ["ConferenceKit"]),
        .library(name: "ConferenceKitUI", targets: ["ConferenceKitUI"]),
        .library(name: "ConferenceKitIntents", targets: ["ConferenceKitIntents"]),
        .library(name: "ConferenceKitWidgets", targets: ["ConferenceKitWidgets"]),
        .library(name: "ConferenceKitAsk", targets: ["ConferenceKitAsk"])
    ],
    targets: [
        .target(
            name: "ConferenceKit",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "ConferenceKitUI",
            dependencies: ["ConferenceKit", "ConferenceKitIntents"],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "ConferenceKitIntents",
            dependencies: ["ConferenceKit"]
        ),
        .target(
            name: "ConferenceKitWidgets",
            dependencies: ["ConferenceKit", "ConferenceKitIntents"]
        ),
        .target(
            name: "ConferenceKitAsk",
            dependencies: ["ConferenceKit"],
            path: "Integration/ConferenceKitAsk/Sources/ConferenceKitAskLink"
        ),
        .testTarget(
            name: "ConferenceKitTests",
            dependencies: ["ConferenceKit", "ConferenceKitIntents"]
        )
    ]
)
