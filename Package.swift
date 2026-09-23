// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HideBar",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure rules, no AppKit and no stored state, so they can be tested.
        .target(name: "HideBarCore", path: "Sources/HideBarCore"),
        .executableTarget(
            name: "HideBar",
            dependencies: ["HideBarCore"],
            path: "Sources/HideBar"),
        .testTarget(
            name: "HideBarCoreTests",
            dependencies: ["HideBarCore"],
            path: "Tests/HideBarCoreTests"),
    ]
)
