// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Middling",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Middling",
            path: "Sources/Middling",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
