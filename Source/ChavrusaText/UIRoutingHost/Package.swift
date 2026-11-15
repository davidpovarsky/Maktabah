// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChavrusaUIRoutingHost",
    platforms: [.iOS("26.0")],
    products: [.library(name: "ChavrusaUIRoutingHost", targets: ["ChavrusaUIRoutingHost"])],
    dependencies: [.package(path: "../../Otzaria/UIRouting"), .package(path: "../../Otzaria/Actions")],
    targets: [
        .target(name: "ChavrusaUIRoutingHost", dependencies: [
            .product(name: "OtzariaUIRouting", package: "UIRouting"),
            .product(name: "OtzariaActionCore", package: "Actions")
        ]),
        .testTarget(name: "ChavrusaUIRoutingHostTests", dependencies: ["ChavrusaUIRoutingHost"])
    ], swiftLanguageModes: [.v6]
)
