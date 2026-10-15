// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "BongoWaifu",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "WaifuCore"),
        .executableTarget(name: "BongoWaifu", dependencies: ["WaifuCore"]),
        .testTarget(name: "WaifuCoreTests", dependencies: ["WaifuCore"]),
    ],
    swiftLanguageModes: [.v5]
)
