// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CommandPalette",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "CommandPalette", targets: ["CommandPalette"]),
    ],
    targets: [
        .target(name: "CommandPalette"),
        .testTarget(name: "CommandPaletteTests", dependencies: ["CommandPalette"]),
    ]
)
