// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DuckDuckGoBookTabs",
    platforms: [.iOS(.v17)],
    products: [.library(name: "DuckDuckGoBookTabs", targets: ["DuckDuckGoBookTabs"])],
    targets: [
        .target(name: "DuckDuckGoBookTabs", path: ".", exclude: ["Tests"], sources: [
            "TabsBarLayout.swift", "TabsBarView.swift", "TabsBarCell.swift", "TabsBarViewController.swift",
            "TabFlareBackgroundController.swift", "TabFlaredBackgroundView.swift", "ReaderBookTabsModel.swift", "ReaderTabFadeOutLabel.swift"
        ]),
        .testTarget(name: "DuckDuckGoBookTabsTests", dependencies: ["DuckDuckGoBookTabs"], path: "Tests")
    ]
)
