// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "jot",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
    ],
    targets: [
        .target(name: "JotCore"),
        .executableTarget(name: "Jot", dependencies: ["JotCore", .product(name: "Sparkle", package: "Sparkle")]),
        .testTarget(name: "JotCoreTests", dependencies: ["JotCore"]),
    ],
    swiftLanguageModes: [.v5]
)
