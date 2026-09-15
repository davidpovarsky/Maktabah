import SwiftUI

enum iOSTab: Int, CaseIterable, Identifiable {
    case viewer
    case textSearch
    case zayitSearch
    case search
    case author
    case annotations
    case history

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .viewer: "Library".localized
        case .textSearch: "חיפוש טקסטים"
        case .zayitSearch: "Zayit Search"
        case .search: "Search".localized
        case .author: "Narrators".localized
        case .annotations: "Annotations".localized
        case .history: "History".localized
        }
    }

    var icon: String {
        switch self {
        case .viewer: "books.vertical.fill"
        case .textSearch: "text.magnifyingglass"
        case .zayitSearch: "text.page.badge.magnifyingglass"
        case .search: "magnifyingglass"
        case .author: "person.text.rectangle.fill"
        case .annotations: "quote.closing"
        case .history: "clock.fill"
        }
    }

    var appMode: AppMode {
        switch self {
        case .viewer: .viewer
        case .textSearch: .search
        case .zayitSearch: .search
        case .search: .search
        case .author: .narrator
        case .annotations: .annotations
        case .history: .history
        }
    }

    init(appMode: AppMode) {
        switch appMode {
        case .viewer: self = .viewer
        case .search: self = .textSearch
        case .narrator: self = .author
        case .annotations: self = .annotations
        case .history: self = .history
        }
    }
}

// MARK: - Main View

struct iOSMainView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var navigationManager = iOSNavigationManager()
    @State private var selectedTab: iOSTab = .viewer
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showSettings = false
    @ObservedObject private var donationManager = DonationManager.shared

    var body: some View {
        @Bindable var bManager = navigationManager

        Group {
            if horizontalSizeClass == .regular {
                iPadLayout(
                    bManager: bManager,
                    selectedTab: $selectedTab,
                    columnVisibility: $columnVisibility,
                    showSettings: $showSettings
                )
            } else {
                iPhoneLayout(
                    bManager: bManager,
                    selectedTab: $selectedTab,
                    showSettings: $showSettings
                )
            }
        }
        .environment(navigationManager)
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .listRowBackground(Color.appCellBackground)
                    .background(Color.appBackground)
                    .navigationTitle("Settings".localized)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showSettings = false }
                        }
                    }
            }
            .tint(.header)
        }
        .sheet(isPresented: $donationManager.showDonationSheet) {
            DonationSheetView(onDismiss: {
                donationManager.dismiss()
                donationManager.showDonationSheet = false
            })
        }
        .alert(item: $navigationManager.alertMessage) { item in
            Alert(
                title: Text(item.title),
                message: Text(item.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                if AppConfig.useICloud {
                    CloudKitSyncManager.shared.fetchChanges()
                }
                DonationManager.shared.recordActivation()
                DonationManager.shared.checkAndPromptIOSSheet()
            }
        }
        #if DEBUG
        .task {
            await performSmokeAutomationIfNeeded()
        }
        #endif
    }
}


// MARK: - Navigation Helper

extension View {
    func adaptiveReaderPush(item: Binding<BooksData?>, manager: iOSNavigationManager) -> some View {
        navigationDestination(item: item) { book in
            let tab = manager.openTabs.first(where: { $0.book.id == book.id && $0.id == manager.activeTabId })
                   ?? manager.openTabs.first(where: { $0.book.id == book.id })
            iOSReaderView(book: book, viewModel: tab?.viewModel, initialContentId: manager.selectedContentId)
        }
    }

    func toolbarGeneral(showSettings: Binding<Bool>) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showSettings.wrappedValue = true } label: {
                    Image(systemName: "gear")
                }
                .accessibilityLabel(String(localized: "Settings"))
                .help(String(localized: "Settings"))
            }

            CustomToolbarSpacer(placement: .topBarLeading)
        }
    }
}

// MARK: - Custom Toolbar Spacer

struct CustomToolbarSpacer: ToolbarContent {
    let placement: ToolbarItemPlacement
    var minLength: CGFloat?

    init(placement: ToolbarItemPlacement = .automatic, minLength: CGFloat? = 16) {
        self.placement = placement
        self.minLength = minLength
    }

    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarSpacer(placement: placement)
        }
    }
}

struct iOSMainView_Previews: PreviewProvider {
    static var previews: some View {
        iOSMainView()
            .task {
                AppConfig.initializeMode()
                AppConfig.setupAnnotationsAndResults()
                ArabicFont.registerCustomFonts()
            }
    }
}

// MARK: - Smoke Test Automation

#if DEBUG
private extension iOSMainView {
    enum SmokeInspectorMode {
        case none
        case inspector
        case commentatorTab
    }

    func performSmokeAutomationIfNeeded() async {
        let args = ProcessInfo.processInfo.arguments
        guard let scenarioIndex = args.firstIndex(of: "-smokeScenario"),
              scenarioIndex + 1 < args.count else {
            return
        }
        let scenario = args[scenarioIndex + 1]

        // Allow SwiftUI initial layout to finish
        try? await Task.sleep(for: .milliseconds(700))

        let backend = BackendCoordinator.shared.activeBackendID

        switch scenario {
        case "catalog":
            selectedTab = .viewer
            navigationManager.switchToMode(.viewer)
            columnVisibility = .all

        case "reader":
            selectedTab = .viewer
            columnVisibility = .all
            await openSmokeBook(for: backend, inspectorMode: .none)

        case "inspector":
            selectedTab = .viewer
            columnVisibility = .all
            await openSmokeBook(for: backend, inspectorMode: .inspector)

        case "commentator":
            selectedTab = .viewer
            columnVisibility = .all
            await openSmokeBook(for: backend, inspectorMode: .commentatorTab)

        case "search":
            if BackendCoordinator.shared.capabilities.contains(.search) {
                selectedTab = .textSearch
                navigationManager.switchToMode(.search)
            } else {
                selectedTab = .search
                navigationManager.switchToMode(.search)
            }

        default:
            break
        }
    }

    func openSmokeBook(for backend: BackendID, inspectorMode: SmokeInspectorMode) async {
        switch backend {
        case .sefaria:
            let genesisLocator = TextLocator(
                backend: .sefaria,
                workKey: "Genesis",
                position: .canonicalRef("Genesis 1:1")
            )
            let canonicalID = CrossBackendBookIdentityIndex.shared.canonicalID(for: genesisLocator) ?? 1
            let targetID = LegacyIdentityRegistry.shared.id(for: genesisLocator)
            let book = BooksData(
                id: canonicalID,
                book: "Genesis",
                archive: 0,
                muallif: 0,
                backendLocator: genesisLocator
            )
            navigationManager.openBook(book, initialContentId: targetID, recordHistory: false)

            var loadedTab: iOSNavigationManager.ReaderTab?
            for _ in 0..<60 {
                if let tab = navigationManager.openTabs.first(where: { $0.id == navigationManager.activeTabId }),
                   tab.viewModel.backendRenderModel != nil || !tab.viewModel.contentText.isEmpty {
                    loadedTab = tab
                    break
                }
                try? await Task.sleep(for: .milliseconds(100))
            }

            guard let activeTab = loadedTab else { return }

            if inspectorMode != .none {
                try? await Task.sleep(for: .milliseconds(500))
                activeTab.viewModel.selectedSegmentLocator = genesisLocator
                activeTab.viewModel.readerInspectorVisible = true

                if inspectorMode == .commentatorTab {
                    try? await Task.sleep(for: .milliseconds(1000))
                    if let sources = try? await BackendCoordinator.shared.links(for: genesisLocator),
                       let firstSource = sources.first {
                        navigationManager.openTorahInspectorLocationInNewTab(firstSource.locator)
                    }
                }
            }

        case .otzaria:
            let linked = try? OtzariaMaktabahBridge.shared.withDatabase { database in
                try database.fetch(query: """
                    SELECT l.sourceBookId, sourceLine.lineIndex, b.name
                    FROM link l
                    JOIN line sourceLine ON sourceLine.id = l.sourceLineId
                    JOIN book b ON b.id = l.sourceBookId
                    ORDER BY l.id
                    LIMIT 1
                """) { row in
                    (row.int(at: 0), row.int(at: 1), row.string(at: 2))
                }.first
            }

            let bookId = linked?.0 ?? 1
            let lineIndex = linked?.1 ?? 1
            let bookTitle = linked?.2 ?? "בראשית"

            let locator = TextLocator(
                backend: .otzaria,
                workKey: "book:\(bookId)",
                position: .legacyLine(lineIndex)
            )

            let book = BooksData(
                id: bookId,
                book: bookTitle,
                archive: 0,
                muallif: 0,
                backendLocator: locator
            )

            navigationManager.openBook(book, initialContentId: lineIndex, recordHistory: false)

            var loadedTab: iOSNavigationManager.ReaderTab?
            for _ in 0..<60 {
                if let tab = navigationManager.openTabs.first(where: { $0.id == navigationManager.activeTabId }),
                   tab.viewModel.backendRenderModel != nil || !tab.viewModel.contentText.isEmpty {
                    loadedTab = tab
                    break
                }
                try? await Task.sleep(for: .milliseconds(100))
            }

            guard let activeTab = loadedTab else { return }

            if inspectorMode != .none {
                try? await Task.sleep(for: .milliseconds(500))
                activeTab.viewModel.selectedSegmentLocator = locator
                if let anchor = OtzariaMaktabahBridge.shared.lineAnchor(
                    bookId: bookId,
                    contentId: activeTab.viewModel.currentContentId,
                    characterIndex: 0
                ) {
                    activeTab.viewModel.otzariaSelectedLineAnchor = anchor
                }
                activeTab.viewModel.readerInspectorVisible = true

                if inspectorMode == .commentatorTab {
                    try? await Task.sleep(for: .milliseconds(1000))
                    if let sources = try? await BackendCoordinator.shared.links(for: locator),
                       let firstSource = sources.first {
                        navigationManager.openTorahInspectorLocationInNewTab(firstSource.locator)
                    }
                }
            }
        }
    }
}
#endif

