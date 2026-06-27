// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HotkeyKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "HotkeyKit", targets: ["HotkeyKit"]),
    ],
    targets: [
        .target(name: "HotkeyKit"),
        .testTarget(name: "HotkeyKitTests", dependencies: ["HotkeyKit"]),
    ]
)
