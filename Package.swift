// swift-tools-version: 6.0

import PackageDescription

#if canImport(AppleProductTypes)
import AppleProductTypes
#endif

// Swift/SwiftUI/UIKit-only workbench. The real production UI and pure-Swift
// presentation state are compiled in place. Database/download/search engines
// are deliberately absent and are represented by PlaygroundSupport mocks.
let uiSources = [
    // Real iOS UI — deliberately omit Bootstrap views/resources.
    "Source/iOS/Theme",
    "Source/iOS/Views/Annotation",
    "Source/iOS/Views/Common",
    "Source/iOS/Views/Reader",
    "Source/iOS/Views/Search",
    "Source/iOS/Views/AnnotationListView.swift",
    "Source/iOS/Views/AuthorModeView.swift",
    "Source/iOS/Views/LibraryViewControllerWrapper.swift",
    "Source/iOS/Views/SearchModeView.swift",
    "Source/iOS/Views/SearchResultsListView.swift",
    "Source/iOS/Views/ViewOptionsView.swift",
    "Source/iOS/Views/iOSHistoryView.swift",
    "Source/iOS/Views/iOSLibraryView.swift",
    "Source/iOS/Views/iOSLibraryViewController.swift",
    "Source/iOS/Views/iOSMainView.swift",
    "Source/iOS/Views/iOSRowiSidebarView.swift",
    "Source/iOS/Views/iPadLayout.swift",
    "Source/iOS/Views/iPhoneLayout.swift",
    "Source/iOS/Wrappers",

    // Real pure-Swift model/presentation state used by those screens.
    "Source/Models",
    "Source/Managers/ViewCordinatoor/AppMode.swift",
    "Source/Managers/ViewModels",
    "Source/Managers/String",
    "Source/Managers/TextView/TextViewState.swift",
    "Source/Managers/App Config/Fonts/ArabicFont.swift",
    "Source/Managers/App Config/UserDefaults.swift",
    "Source/iOS/Managers/iOSNavigationManager.swift",
    "Source/iOS/Managers/UserFontManager.swift",

    // Real shared SwiftUI screens used by the iOS shell.
    "Source/View/SettingsView.swift",
    "Source/View/CoreDownloadProgressView.swift",
    "Source/View/ProgressBooksDownload.swift",
    "Source/View/WelcomeScreenView.swift",

    // Otzaria presentation models/view-models and real UI, no SQLite/search engine.
    "Source/Otzaria/Domain",
    "Source/Otzaria/Features/Authors",
    "Source/Otzaria/Features/Library",
    "Source/Otzaria/Features/Reader",
    "Source/Otzaria/Features/Settings",
    "Source/Otzaria/Features/Sources",
    "Source/Otzaria/SharedUI/OtzariaStateViews.swift",
    "Source/Otzaria/Search/OtzariaSearchMode.swift",
    "Source/Otzaria/Search/OtzariaSearchModels.swift",
    "Source/Otzaria/Search/OtzariaSearchSnippetRenderer.swift",
    "Source/Otzaria/Search/OtzariaTextSearchView.swift",

    // Unified/Zayit presentation models only.
    "Source/ZayitSearch/UnifiedSearchPresentationPolicy.swift",
    "Source/ZayitSearch/UnifiedSearchWorkspaceView.swift",
    "Vendor/ZayitSearchPort/Swift/ZayitSearchModels.swift",
    "Vendor/ZayitSearchPort/Swift/ZayitSearchRepository.swift",
    "Vendor/ZayitSearchPort/Swift/ZayitSearchViewModel.swift",
    "Vendor/ZayitSearchPort/Swift/ZayitSearchView.swift",
    "Vendor/ZayitSearchPort/Swift/ZayitSearchAttributionView.swift",

    // Playground-only host and backend stand-ins.
    "PlaygroundSupport/MaktabahUIWorkbenchApp.swift",
    "PlaygroundSupport/UIWorkbenchMocks.swift",
    "PlaygroundSupport/GeneratedResourceSymbols.swift"
]

var uiSwiftSettings: [SwiftSetting] = [
    .define("MAKTABAH_PLAYGROUND"),
    .define("MAKTABAH_UI_WORKBENCH"),
    .define("MAKTABAH_PLAYGROUND_STRINGS_SHIM")
]

#if !canImport(AppleProductTypes)
uiSwiftSettings.append(.define("MAKTABAH_SWIFTPM_CI"))
#endif

let appTarget: Target = .executableTarget(
    name: "AppModule",
    dependencies: [],
    path: ".",
    exclude: [
        ".github",
        "Maktabah.xcodeproj",
        "Scripts",
        "ci_scripts",
        "docs",
        "Screenshots",
        // macOS-only model; not used by the iPad presentation layer.
        "Source/Models/BackgroundOptions.swift"
    ],
    sources: uiSources,
    resources: [
        .process("Source/Assets.xcassets"),
        .process("Source/Managers/App Config/Fonts/Lateef-Bold.ttf"),
        .process("Source/Managers/App Config/Fonts/Lateef-Regular.ttf"),
        .process("Source/Managers/App Config/Fonts/ScheherazadeNew-Regular.ttf"),
        .process("Source/Managers/App Config/Fonts/UthmanTN1-Ver10.otf")
    ],
    swiftSettings: uiSwiftSettings
)

#if canImport(AppleProductTypes)
let package = Package(
    name: "MaktabahUIWorkbench",
    defaultLocalization: "he",
    platforms: [.iOS("18.0")],
    products: [
        .iOSApplication(
            name: "Maktabah UI Workbench",
            targets: ["AppModule"],
            bundleIdentifier: "com.davidpovarsky.maktabah.uiworkbench",
            displayVersion: "2.3",
            bundleVersion: "5",
            supportedDeviceFamilies: [.pad],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    dependencies: [],
    targets: [appTarget],
    swiftLanguageModes: [.v5]
)
#else
let package = Package(
    name: "MaktabahUIWorkbench",
    defaultLocalization: "he",
    platforms: [.iOS(.v18)],
    products: [.executable(name: "MaktabahUIWorkbench", targets: ["AppModule"])],
    dependencies: [],
    targets: [appTarget],
    swiftLanguageModes: [.v5]
)
#endif
