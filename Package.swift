// swift-tools-version: 6.0

import PackageDescription

#if canImport(AppleProductTypes)
import AppleProductTypes
#endif

// Swift/SwiftUI/UIKit-only workbench. The real production UI is compiled in
// place. Backend/runtime state is represented by PlaygroundSupport facades so
// the iPad workbench never needs database, CloudKit, Rust/C, or download code.
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

    // Real pure-Swift models/helpers used by those screens.
    "Source/Models",
    "Source/Protocols/CopyableResult.swift",
    "Source/Managers/ViewCordinatoor/AppMode.swift",
    "Source/Managers/String",
    "Source/Managers/TextView/TextViewState.swift",
    "Source/Managers/App Config/StorageError.swift",
    "Source/Managers/App Config/Fonts/ArabicFont.swift",
    "Source/Managers/App Config/UserDefaults.swift",
    "Source/iOS/Managers/UserFontManager.swift",

    // Real shared SwiftUI screens used by the iOS shell.
    "Source/View/SettingsView.swift",
    "Source/View/CoreDownloadProgressView.swift",
    "Source/View/ProgressBooksDownload.swift",
    "Source/View/WelcomeScreenView.swift",

    // Otzaria presentation models/views only, no SQLite/search engine.
    "Source/Otzaria/Core/String+OtzariaText.swift",
    "Source/Otzaria/Domain",
    "Source/Otzaria/Features/Authors",
    "Source/Otzaria/Features/Library",
    "Source/Otzaria/Features/Reader",
    "Source/Otzaria/Features/Settings",
    "Source/Otzaria/Features/Sources",
    "Source/Otzaria/Reading/OtzariaLineAnchor.swift",
    "Source/Otzaria/Reading/OtzariaTextViewLineSelectionAdapter.swift",
    "Source/Otzaria/SharedUI/OtzariaStateViews.swift",
    "Source/Otzaria/Search/OtzariaSearchMode.swift",
    "Source/Otzaria/Search/OtzariaSearchModels.swift",
    "Source/Otzaria/Search/OtzariaSearchSnippetRenderer.swift",
    "Source/Otzaria/Search/OtzariaTextSearchView.swift",

    // Unified/Zayit presentation models only. The repository/engine is a
    // PlaygroundSupport facade, while the actual View and ViewModel stay real.
    "Source/ZayitSearch/UnifiedSearchPresentationPolicy.swift",
    "Source/ZayitSearch/UnifiedSearchWorkspaceView.swift",
    "Vendor/ZayitSearchPort/Swift/ZayitSearchModels.swift",
    "Vendor/ZayitSearchPort/Swift/ZayitSearchViewModel.swift",
    "Vendor/ZayitSearchPort/Swift/ZayitSearchView.swift",
    "Vendor/ZayitSearchPort/Swift/ZayitSearchAttributionView.swift",

    // Playground-only host and presentation/backend stand-ins.
    "PlaygroundSupport/MaktabahUIWorkbenchApp.swift",
    "PlaygroundSupport/UIWorkbenchMocks.swift",
    "PlaygroundSupport/UIWorkbenchFacades.swift",
    "PlaygroundSupport/UIWorkbenchCompatibility.swift",
    "PlaygroundSupport/UIWorkbenchReaderModels.swift",
    "PlaygroundSupport/UIWorkbenchBootstrapModels.swift",
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
        "Source/Models/BackgroundOptions.swift",
        // Backend-heavy presentation implementations are replaced only inside
        // the workbench. Production Xcode targets still use these real files.
        "Source/Managers/ViewModels",
        "Source/iOS/Managers/iOSNavigationManager.swift",
        "Vendor/ZayitSearchPort/Swift/ZayitSearchRepository.swift"
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
            displayVersion: "2.4",
            bundleVersion: "6",
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
