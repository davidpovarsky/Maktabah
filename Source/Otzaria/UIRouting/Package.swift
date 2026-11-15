// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OtzariaUIRouting",
    platforms: [.iOS("26.0")],
    products: [.library(name: "OtzariaUIRouting", targets: ["OtzariaUIRouting"])],
    dependencies: [.package(path: "../Actions")],
    targets: [
        .target(name: "OtzariaUIRouting", dependencies: [.product(name: "OtzariaActionCore", package: "Actions")], resources: [.process("Resources")]),
        .testTarget(name: "OtzariaUIRoutingTests", dependencies: ["OtzariaUIRouting"], resources: [.copy("Contracts/Fixtures")])
    ], swiftLanguageModes: [.v6]
)
