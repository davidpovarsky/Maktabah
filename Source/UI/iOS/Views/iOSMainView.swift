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

    func isAvailable(for capabilities: BackendCapabilities) -> Bool {
        switch canonical {
        case .search: capabilities.contains(.search)
        case .author: capabilities.contains(.authors)
        default: true
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
    @Bindable var donationManager = DonationManager.shared

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
        .onOpenURL { url in
            handleOpenURL(url, bManager: bManager)
        }
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
        .sheet(item: $bManager.selectedBookForInfo) { book in
            iOSBookInfoView(book: book)
        }
        .sheet(isPresented: $bManager.showingTabsList) {
            iOSReaderTabsPopoverView(bManager: bManager, isPresented: $bManager.showingTabsList)
                .environment(navigationManager)
        }
        .alert(item: $navigationManager.alertMessage) { item in
            Alert(
                title: Text(item.title),
                message: Text(item.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            navigationManager.restoreSessionIfNeeded()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                if AppConfig.useICloud {
                    CloudKitSyncManager.shared.fetchChanges()
                }
                DonationManager.shared.recordActivation()
                DonationManager.shared.checkAndPromptIOSSheet()
                navigationManager.restoreSessionIfNeeded()
            } else if newPhase == .inactive || newPhase == .background {
                navigationManager.persistCurrentSession(immediate: true)
            }
        }
        #if DEBUG
        .task {
            await performSmokeAutomationIfNeeded()
        }
        #endif
    }

    private func handleOpenURL(_ url: URL, bManager: iOSNavigationManager) {
        guard let deepLink = WidgetDeepLink.parse(from: url) else { return }

        Task {
            switch deepLink {
            case let .annotation(annId):
                if let annotation = AnnotationStore.shared.loadAnnotationById(annId),
                   let book = LibraryDataManager.shared.getBook([annotation.bkId]).first
                {
                    await MainActor.run {
                        bManager.openBook(
                            book,
                            options: OpenBookOptions(
                                contentId: Int(annotation.contentId),
                                annotationEvent: ReaderAnnotationEvent(annotation: annotation)
                            )
                        )
                    }
                }

            case let .history(bkId, contentId):
                if let book = LibraryDataManager.shared.getBook([bkId]).first {
                    await MainActor.run {
                        bManager.openBook(book, options: OpenBookOptions(contentId: contentId))
                    }
                }
            }
        }
    }
}

// MARK: - Navigation Helper

extension View {
    func adaptiveReaderPush(item: Binding<BooksData?>, manager: iOSNavigationManager) -> some View {
        navigationDestination(item: item) { book in
            let tab = manager.openTabs.first(where: { $0.book.id == book.id && $0.id == manager.activeTabId })
                ?? manager.openTabs.first(where: { $0.book.id == book.id })
            iOSReaderWorkspaceView(
                book: book,
                viewModel: tab?.viewModel ?? ReaderViewModel(book: book),
                initialContentId: manager.selectedContentId
            )
            .id(tab?.id)
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
        var smokeSucceeded = true
        var smokeFailureDetail: String?
        defer {
            writeSmokeAutomationResult(
                scenario: scenario,
                succeeded: smokeSucceeded,
                failureDetail: smokeFailureDetail
            )
        }

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
            await navigationManager.libraryViewModel.refreshLibrary()
            smokeSucceeded = await validateLibrarySnapshotUsingUIKit(
                navigationManager.libraryViewModel.rootCategories
            ) && validateCanonicalBookIndex(navigationManager.libraryViewModel.rootCategories)

        case "librarySnapshotRegression":
            smokeSucceeded = await runSyntheticLibrarySnapshotRegression()

        case "backendSwitchRegression":
            let result = await runBackendSwitchSnapshotRegression()
            smokeSucceeded = result.succeeded
            smokeFailureDetail = result.failureDetail

        case "reader", "readerTOC", "readerDetail":
            selectedTab = .viewer
            columnVisibility = scenario == "readerDetail" ? .detailOnly : .all
            await openSmokeBook(for: backend, inspectorMode: .none)

        case "inspector", "studyCommentaries", "studyFloating", "studyFloatingFull", "studyLinks", "studyNotes", "studyCompactLarge", "compactStudyToTOC":
            selectedTab = .viewer
            columnVisibility = ["studyCommentaries", "studyLinks", "studyNotes"].contains(scenario) ? .detailOnly : .all
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
            selectedTab = .search
            navigationManager.switchToMode(.search)
            columnVisibility = .all
            try? await Task.sleep(for: .milliseconds(500))
            smokeSucceeded = await prepareSmokeSearch(query: query) != nil

        case "searchPreview":
            let query = "בראשית"
            selectedTab = .search
            navigationManager.switchToMode(.search)
            columnVisibility = .all
            TextViewState.shared.setReaderTextMode(.both)
            try? await Task.sleep(for: .milliseconds(500))
            // Prepare the real result list only. Acceptance automation must tap
            // an actual row to expand its preview; no overlay is injected here.
            smokeSucceeded = await prepareSmokeSearch(query: query) != nil

        case "searchOpen":
            let query = "בראשית"
            selectedTab = .search
            navigationManager.switchToMode(.search)
            columnVisibility = .all
            try? await Task.sleep(for: .milliseconds(500))
            if let first = await prepareSmokeSearch(query: query) {
                navigationManager.unifiedSearchSession.openResult(first, using: navigationManager)
                navigationManager.switchToMode(.viewer)
            } else {
                smokeSucceeded = false
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

    func writeSmokeAutomationResult(
        scenario: String,
        succeeded: Bool,
        failureDetail: String? = nil
    ) {
        guard let path = ProcessInfo.processInfo.environment["MAKTABAH_SMOKE_READY_FILE"],
              !path.isEmpty else { return }
        let detail = failureDetail.map { "\($0)\n" } ?? ""
        let value = succeeded ? "success\n\(scenario)\n" : "failure\n\(scenario)\n\(detail)"
        try? Data(value.utf8).write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    @MainActor
    func validateLibrarySnapshotUsingUIKit(
        _ categories: [CategoryData],
        showLoadMore: Bool = false
    ) -> Bool {
        let controller = iOSLibraryViewController()
        controller.showLoadMore = showLoadMore
        controller.loadViewIfNeeded()
        controller.applyCategories(categories)

        let snapshot = controller.dataSource.snapshot(for: 0)
        let expected = countLibraryItems(in: categories) + (showLoadMore ? 1 : 0)
        return controller.lastSnapshotError == nil
            && controller.lastAppliedItemCount == expected
            && snapshot.items.count == expected
            && Set(snapshot.items).count == expected
    }

    @MainActor
    func runSyntheticLibrarySnapshotRegression() -> Bool {
        let sharedLocator = TextLocator(
            backend: .sefaria,
            workKey: "Shared Work",
            position: .canonicalRef("Shared Work")
        )
        let shared = BooksData(
            id: 42,
            book: "Shared Title",
            archive: 0,
            muallif: 0,
            backendLocator: sharedLocator
        )
        let colliding = BooksData(
            id: 42,
            book: "Shared Title",
            archive: 0,
            muallif: 0,
            backendLocator: TextLocator(
                backend: .sefaria,
                workKey: "Distinct Work",
                position: .canonicalRef("Distinct Work")
            )
        )
        let first = CategoryData(id: 7, name: "First Path", level: 1, order: 0)
        first.children = [shared, colliding]
        let second = CategoryData(id: 7, name: "Second Path", level: 1, order: 1)
        second.children = [shared]

        guard validateLibrarySnapshotUsingUIKit([first, second], showLoadMore: true),
              validateLibrarySnapshotUsingUIKit([first]) else { return false }

        let controller = iOSLibraryViewController()
        controller.loadViewIfNeeded()
        controller.applyCategories([first, second])
        guard let firstCategory = controller.dataSource.snapshot(for: 0).rootItems.first else { return false }
        controller.toggleCategory(firstCategory)
        guard controller.dataSource.snapshot(for: 0).isExpanded(firstCategory) else { return false }

        let invalid = CategoryData(id: 8, name: "Invalid", level: 1, order: 0)
        invalid.children = [NSObject()]
        controller.applyCategories([invalid])
        return controller.lastSnapshotError != nil
            && controller.collectionView.backgroundView?.accessibilityIdentifier == "library-catalog-recovery"
    }

    @MainActor
    func runBackendSwitchSnapshotRegression() async -> (succeeded: Bool, failureDetail: String?) {
        let model = navigationManager.libraryViewModel
        for backend in [BackendID.otzaria, .sefaria, .otzaria, .sefaria] {
            BackendCoordinator.shared.commit(backend)
            let taskToAwait = model.reloadTask.withLock { $0 }
            if let taskToAwait {
                await taskToAwait.value
            }
            if model.loadedBackendID != backend
                || model.loadedBackendGeneration != BackendCoordinator.shared.generation {
                await model.refreshLibrary()
            }

            let contextIsValid = model.loadedBackendID == backend
                && model.loadedBackendGeneration == BackendCoordinator.shared.generation
            guard contextIsValid else {
                return (false, "backend=\(backend.rawValue) context=\(String(describing: model.loadedBackendID))/\(String(describing: model.loadedBackendGeneration)) expectedGeneration=\(BackendCoordinator.shared.generation)")
            }
            guard validateLibrarySnapshotUsingUIKit(model.rootCategories) else {
                return (false, "backend=\(backend.rawValue) UIKitSnapshot roots=\(model.rootCategories.count)")
            }
            guard validateCanonicalBookIndex(model.rootCategories) else {
                return (false, "backend=\(backend.rawValue) canonicalIndex roots=\(model.rootCategories.count) indexedBooks=\(LibraryDataManager.shared.booksById.count)")
            }
        }
        return (true, nil)
    }

    func countLibraryItems(in categories: [CategoryData]) -> Int {
        categories.reduce(into: 0) { count, category in
            count += 1
            for child in category.children {
                if let subcategory = child as? CategoryData {
                    count += countLibraryItems(in: [subcategory])
                } else if child is BooksData {
                    count += 1
                }
            }
        }
    }

    func validateCanonicalBookIndex(_ categories: [CategoryData]) -> Bool {
        var occurrences: [BooksData] = []
        func collect(_ categories: [CategoryData]) {
            for category in categories {
                for child in category.children {
                    if let subcategory = child as? CategoryData {
                        collect([subcategory])
                    } else if let book = child as? BooksData {
                        occurrences.append(book)
                    }
                }
            }
        }
        collect(categories)

        let located = occurrences.compactMap(\.backendLocator)
        guard !located.isEmpty else {
            return Set(occurrences.map(\.id)).count == LibraryDataManager.shared.booksById.count
        }
        let uniqueLocators = Set(located.map { "\($0.backend.rawValue)|\($0.workKey)" })
        let indexedLocators = Set(LibraryDataManager.shared.booksById.values.compactMap { book in
            book.backendLocator.map { "\($0.backend.rawValue)|\($0.workKey)" }
        })
        return uniqueLocators == indexedLocators
            && Set(LibraryDataManager.shared.booksById.keys).count == LibraryDataManager.shared.booksById.count
    }

    func prepareSmokeSearch(query: String) async -> SearchResultItem? {
        let session = navigationManager.unifiedSearchSession
        session.searchViewModel = navigationManager.searchViewModel
        session.handleBackendChanged()
        session.scope = .advanced
        session.query = query
        session.runSearch()

        for _ in 0..<80 {
            if let first = session.results.first {
                return first
            }
            if session.hasSubmitted, !session.isSearching, session.errorMessage != nil {
                return nil
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return session.results.first
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
                let rows = try database.fetch(query: "SELECT title FROM book WHERE id = \(bookId) LIMIT 1") { row in
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
                if let anchor = await OtzariaMaktabahBridge.shared.lineAnchorAsync(
                    bookId: bookId,
                    contentId: lineIndex,
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

