// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ConferenceKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "ConferenceKit", targets: ["ConferenceKit"])
    ],
    targets: [
        .target(
            name: "ConferenceKit",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ConferenceKitTests",
            dependencies: ["ConferenceKit"]
        )
    ]
)
