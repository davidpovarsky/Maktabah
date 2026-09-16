import SwiftUI

enum iOSTab: Int, CaseIterable, Identifiable {
    case viewer = 0
    case textSearch = 1
    case zayitSearch = 2
    case search = 3
    case author = 4
    case annotations = 5
    case history = 6

    static var allCases: [iOSTab] {
        [.viewer, .search, .author, .annotations, .history]
    }

    var id: Int {
        rawValue
    }

    var canonical: iOSTab {
        switch self {
        case .textSearch, .zayitSearch: .search
        default: self
        }
    }

    var title: String {
        switch self {
        case .viewer: "Library".localized
        case .search, .textSearch, .zayitSearch: "Search".localized
        case .author: "Narrators".localized
        case .annotations: "Annotations".localized
        case .history: "History".localized
        }
    }

    var icon: String {
        switch self {
        case .viewer: "books.vertical.fill"
        case .search, .textSearch, .zayitSearch: "magnifyingglass"
        case .author: "person.text.rectangle.fill"
        case .annotations: "quote.closing"
        case .history: "clock.fill"
        }
    }

    var appMode: AppMode {
        switch self {
        case .viewer: .viewer
        case .search, .textSearch, .zayitSearch: .search
        case .author: .narrator
        case .annotations: .annotations
        case .history: .history
        }
    }

    init(appMode: AppMode) {
        switch appMode {
        case .viewer: self = .viewer
        case .search: self = .search
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

        if let backendArgIndex = args.firstIndex(of: "-smokeBackend"),
           backendArgIndex + 1 < args.count,
           let requestedBackend = BackendID(rawValue: args[backendArgIndex + 1]) {
            BackendCoordinator.shared.commit(requestedBackend)
        }

        if BackendCoordinator.shared.activeBackendID == .otzaria {
            _ = try? await OtzariaBootstrapAdapter.restoreForAppLaunch()
        }

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
            selectedTab = .search
            navigationManager.switchToMode(.search)

        case "searchResults":
            let query = "בראשית"
            navigationManager.searchViewModel.query = query
            selectedTab = .search
            navigationManager.switchToMode(.search)
            columnVisibility = .all
            if backend == .sefaria {
                await navigationManager.searchViewModel.startSearch()
            }
            try? await Task.sleep(for: .milliseconds(1500))

        case "searchOpen":
            let query = "בראשית"
            selectedTab = .search
            navigationManager.switchToMode(.search)
            columnVisibility = .all
            if backend == .sefaria {
                navigationManager.searchViewModel.query = query
                await navigationManager.searchViewModel.startSearch()
                try? await Task.sleep(for: .milliseconds(1500))
                if let first = navigationManager.searchViewModel.results.first,
                   let book = navigationManager.searchViewModel.resolveBook(from: first) {
                    let targetContentId = first.backendLocator != nil ? first.bookId : first.page
                    navigationManager.openBook(book, initialContentId: targetContentId, searchText: query, recordHistory: false)
                    navigationManager.switchToMode(.viewer)
                }
            } else {
                _ = try? await OtzariaBootstrapAdapter.restoreForAppLaunch()
                if let page = try? await BackendCoordinator.shared.search(.init(query: query, offset: 0, limit: 10)),
                   let hit = page.hits.first {
                    let targetID = LegacyIdentityRegistry.shared.id(for: hit.locator)
                    let canonicalID = CrossBackendBookIdentityIndex.shared.canonicalID(for: hit.locator) ?? 1
                    let book = BooksData(id: canonicalID, book: hit.displayRef, archive: 0, muallif: 0, backendLocator: hit.locator)
                    navigationManager.openBook(book, initialContentId: targetID, searchText: query, recordHistory: false)
                    navigationManager.switchToMode(.viewer)
                }
            }

        case "annotationsList":
            _ = await prepareSmokeAnnotation(for: backend)
            selectedTab = .annotations
            navigationManager.switchToMode(.annotations)
            columnVisibility = .all
            await navigationManager.annotationViewModel.loadAnnotations()

        case "annotationsSearch":
            _ = await prepareSmokeAnnotation(for: backend)
            selectedTab = .annotations
            navigationManager.switchToMode(.annotations)
            columnVisibility = .all
            await navigationManager.annotationViewModel.loadAnnotations()
            navigationManager.annotationViewModel.searchText = "בדיקת סימולטור"
            navigationManager.annotationViewModel.applyFilter()

        case "annotationsOpen":
            if let target = await prepareSmokeAnnotation(for: backend) {
                selectedTab = .viewer
                navigationManager.switchToMode(.viewer)
                columnVisibility = .all
                navigationManager.openBook(target.0, initialContentId: target.1, targetAnnotation: target.2, recordHistory: false)
            }

        case "settings":
            selectedTab = .viewer
            navigationManager.switchToMode(.viewer)
            showSettings = true

        case "engineSwitch":
            let otherBackend: BackendID = (backend == .otzaria) ? .sefaria : .otzaria
            BackendCoordinator.shared.commit(otherBackend)
            selectedTab = .viewer
            navigationManager.switchToMode(.viewer)
            columnVisibility = .all

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
            _ = try? await OtzariaBootstrapAdapter.restoreForAppLaunch()
            let linked = try? OtzariaMaktabahBridge.shared.withDatabase { database in
                try database.fetch(query: """
                    SELECT l.sourceBookId, sourceLine.lineIndex
                    FROM link l
                    JOIN line sourceLine ON sourceLine.id = l.sourceLineId
                    ORDER BY l.id
                    LIMIT 1
                """) { row in
                    (row.int(at: 0), row.int(at: 1))
                }.first
            }

            let bookId = linked?.0 ?? 1
            let lineIndex = linked?.1 ?? 1
            let bookTitle: String = (try? OtzariaMaktabahBridge.shared.withDatabase { database -> String in
                let rows = try database.fetch(query: "SELECT name FROM book WHERE id = \(bookId) LIMIT 1") { row in
                    row.string(at: 0) ?? "ספר"
                }
                return rows.first ?? "ספר"
            }) ?? "ספר"

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

    @discardableResult
    func prepareSmokeAnnotation(for backend: BackendID) async -> (BooksData, Int, Annotation)? {
        if backend == .otzaria {
            _ = try? await OtzariaBootstrapAdapter.restoreForAppLaunch()
        }
        let locator: TextLocator
        let bkId: Int
        let contentId: Int
        let bookTitle: String

        if backend == .otzaria {
            bkId = 103
            contentId = 2034
            locator = TextLocator(backend: .otzaria, workKey: "book:103", position: .legacyLine(2034))
            bookTitle = "ברכות"
        } else {
            bkId = 1
            contentId = -53
            locator = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:1"))
            bookTitle = "Genesis"
        }

        let coordinator = AnnotationCoordinator()
        let manager = AnnotationManager.shared
        let noteText = "בדיקת סימולטור: הערה ב\(bookTitle)"
        let targetText = backend == .otzaria ? "השותה מים לצמאו" : "בראשית ברא אלהים"

        do {
            var highlight = try coordinator.saveHighlight(
                text: targetText,
                range: NSRange(location: 0, length: min(targetText.utf16.count, 10)),
                color: .systemYellow,
                bkId: bkId,
                contentId: contentId,
                page: 1,
                part: 1,
                diacriticsText: nil,
                showHarakat: true,
                mode: .highlight,
                backendLocator: locator
            )
            highlight.note = noteText
            highlight.tags = ["בדיקות סימולטור"]
            try manager.updateAnnotation(highlight)
            let book = BooksData(id: bkId, book: bookTitle, archive: 0, muallif: 0, backendLocator: locator)
            return (book, contentId, highlight)
        } catch {
            return nil
        }
    }
}
#endif

