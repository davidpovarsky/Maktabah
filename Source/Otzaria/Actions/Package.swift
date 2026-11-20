// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OtzariaActionCore",
    platforms: [.iOS(.v13)],
    products: [.library(name: "OtzariaActionCore", targets: ["OtzariaActionCore"])],
    targets: [
        .target(name: "OtzariaActionCore", resources: [.process("Resources")]),
        .testTarget(name: "OtzariaActionCoreTests", dependencies: ["OtzariaActionCore"])
    ],
    swiftLanguageModes: [.v6]
)
