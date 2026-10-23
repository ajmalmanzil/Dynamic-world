// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "DynamicIsland",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic (no AppKit) so it can be unit tested.
        .target(name: "IslandCore"),
        .executableTarget(name: "DynamicIsland", dependencies: ["IslandCore"]),
        .testTarget(name: "IslandCoreTests", dependencies: ["IslandCore"]),
    ]
)
