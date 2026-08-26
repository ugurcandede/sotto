// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "sotto",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "sotto",
            path: "Sources/sotto",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "sottoTests",
            dependencies: ["sotto"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
