// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "jot",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
        .package(url: "https://github.com/x-sheep/swift-property-based", exact: "2.0.1"),
    ],
    targets: [
        .target(name: "JotCore"),
        .executableTarget(name: "Jot", dependencies: ["JotCore", .product(name: "Sparkle", package: "Sparkle")]),
        .testTarget(name: "JotCoreTests", dependencies: ["JotCore", .product(name: "PropertyBased", package: "swift-property-based")]),
        .testTarget(name: "JotTests", dependencies: ["Jot", "JotCore"]),
    ],
    swiftLanguageModes: [.v5]
)
