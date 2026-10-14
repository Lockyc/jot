// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "jot",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "JotCore"),
        .executableTarget(name: "Jot", dependencies: ["JotCore"]),
        .testTarget(name: "JotCoreTests", dependencies: ["JotCore"]),
    ],
    swiftLanguageModes: [.v5]
)
