import SwiftUI

// MARK: - Search History Overlay

struct SearchHistoryOverlay: View {
    @Environment(\.isSearching) var isSearching
    @Environment(\.dismissSearch) var dismissSearch
    var session: UnifiedSearchSessionController? = nil
    @Bindable var viewModel: SearchViewModel
    @State var inputBarHeight: CGFloat = 0
    @Binding var isVisible: Bool?
    @State private var showingHelp: Bool = false
    @State private var isShowing = false
    @FocusState private var isDistanceFocused: Bool
    @ScaledMetric(relativeTo: .body) private var distanceFieldWidth: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var distanceFieldHeight: CGFloat = 28

    private var shouldShow: Bool {
        if let session {
            return isVisible == true || isDistanceFocused ||
            (isSearching && isVisible == nil &&
             !session.isSearching && session.results.isEmpty)
        }
        return isVisible == true || isDistanceFocused ||
        (isSearching && isVisible == nil &&
         !viewModel.isSearching && viewModel.results.isEmpty)
    }

    var body: some View {
        Group {
            if isShowing {
                VStack(spacing: 0) {
                    if !viewModel.searchHistory.isEmpty {
                        historyHeader
                        historyList
                    }
                    inputControls
                }
                .fixedSize(horizontal: false, vertical: true)
                .background(Color.appBackground)
                .cornerRadius(12)
                .shadow(radius: 10)
                .padding(.horizontal)
                .padding(.vertical, inputBarHeight)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .readInputBarHeight()
            }
        }
        .animation(
            .interpolatingSpring(stiffness: 250, damping: 24),
            value: isShowing
        )
        .onChange(of: shouldShow) { _, newValue in
            isShowing = newValue
        }
        .onAppear {
            withAnimation(.interpolatingSpring(stiffness: 250, damping: 24)) {
                isShowing = shouldShow
            }
        }
    }

    private var historyHeader: some View {
        HStack {
            Button("Clear All") {
                withAnimation(.easeOut(duration: 0.25)) {
                    viewModel.searchHistory.forEach { viewModel.removeFromHistory($0) }
                }
            }
            .font(.caption)

            Spacer()

            Text("History")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.appSecondaryBackground)
    }

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.searchHistory.enumerated()), id: \.element) { index, historyQuery in
                    VStack(spacing: 0) {
                        Button(action: {
                            if let session {
                                session.query = historyQuery
                                viewModel.addToHistory(historyQuery)
                                session.runSearch()
                                isVisible = false
                            } else {
                                Task {
                                    viewModel.query = historyQuery
                                    viewModel.addToHistory(historyQuery)
                                    await viewModel.startSearch()
                                    isVisible = false
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.secondary)
                                Text(historyQuery)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                        }
                        Divider()
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .animation(
                        .easeOut(duration: 0.2).delay(Double(index) * 0.04),
                        value: viewModel.searchHistory
                    )
                }
            }
        }
        .frame(maxHeight: 260)
        .background(Color.appBackground)
        .environment(\.layoutDirection, .rightToLeft)
    }

    @ViewBuilder
    private var inputControls: some View {
        if session == nil {
            legacyInputControls
        }
    }

    private var legacyInputControls: some View {
        HStack(spacing: 12) {
            Picker("Mode", selection: $viewModel.searchMode) {
                Image(systemName: SearchMode.imageNameForMode(.phrase))
                    .tag(SearchMode.phrase)
                Image(systemName: SearchMode.imageNameForMode(.contains))
                    .tag(SearchMode.contains)
                Image(systemName: SearchMode.imageNameForMode(.or))
                    .tag(SearchMode.or)
                Image(systemName: SearchMode.imageNameForMode(.near))
                    .tag(SearchMode.near)
            }
            .controlSize(.regular)
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)

            if viewModel.searchMode == .near {
                TextField("10", value: $viewModel.nearDistance, format: .number)
                    .focused($isDistanceFocused)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: distanceFieldWidth, height: distanceFieldHeight)
                    .background(Color.appCellBackground)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            Spacer()

            Button(action: { showingHelp = true }) {
                Label("Help", systemImage: "questionmark")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.foreground)
            }
            .popover(isPresented: $showingHelp) {
                SearchHelpView()
                    .frame(width: 300, height: 450)
                    .presentationCompactAdaptation(.popover)
                    .presentationBackground(Color.appBackground)
            }
        }
        .animation(
            .easeInOut(duration: 0.25)
            .delay(0.25),
            value: viewModel.searchMode
        )
        .prominentButtonStyleIfAvailable()
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Unified Search Controls

struct UnifiedSearchAdvancedOptionsButton: View {
    @Bindable var session: UnifiedSearchSessionController
    @State private var isPresented = false

    var body: some View {
        Button(action: {
            isPresented = true
            session.showsAdvancedOptions = true
        }) {
            Image(systemName: "slider.horizontal.3")
                .foregroundStyle(.tint)
        }
        .accessibilityLabel("Advanced Options")
        .help("Advanced Options")
        .popover(isPresented: $isPresented) {
            SearchAdvancedOptionsView(session: session)
                .frame(
                    minWidth: 320,
                    idealWidth: 360,
                    minHeight: 400,
                    idealHeight: 520
                )
                .presentationCompactAdaptation(.popover)
                .presentationBackground(Color.appBackground)
        }
        .onChange(of: isPresented) { _, newValue in
            session.showsAdvancedOptions = newValue
        }
        .onChange(of: session.showsAdvancedOptions) { _, newValue in
            if isPresented != newValue {
                isPresented = newValue
            }
        }
    }
}

struct UnifiedSearchInputControls: View {
    @Bindable var session: UnifiedSearchSessionController
    @State private var showingHelp: Bool = false
    @FocusState private var isDistanceFocused: Bool
    @ScaledMetric(relativeTo: .body) private var distanceFieldWidth: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var distanceFieldHeight: CGFloat = 28

    var body: some View {
        HStack(spacing: 12) {
            Picker("Scope", selection: Binding(
                get: { session.scope },
                set: { session.scope = $0 }
            )) {
                ForEach(session.availableScopes) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .controlSize(.regular)
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)

            if session.hasConfigurableOptions {
                if !session.isSefaria {
                    TextField("10", value: Binding(
                        get: { session.otzariaDistance },
                        set: { session.otzariaDistance = $0 }
                    ), format: .number)
                        .focused($isDistanceFocused)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .frame(width: distanceFieldWidth, height: distanceFieldHeight)
                        .background(Color.appCellBackground)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    TextField("10", value: Binding(
                        get: { session.sefariaWordDistance },
                        set: { session.sefariaWordDistance = $0 }
                    ), format: .number)
                        .focused($isDistanceFocused)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .frame(width: distanceFieldWidth, height: distanceFieldHeight)
                        .background(Color.appCellBackground)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                UnifiedSearchAdvancedOptionsButton(session: session)
            }

            Spacer()

            Button(action: { showingHelp = true }) {
                Label("Help", systemImage: "questionmark")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.foreground)
            }
            .popover(isPresented: $showingHelp) {
                SearchHelpView(isSefaria: session.isSefaria)
                    .frame(width: 320, height: 460)
                    .presentationCompactAdaptation(.popover)
                    .presentationBackground(Color.appBackground)
            }
        }
        .animation(
            .easeInOut(duration: 0.25)
            .delay(0.25),
            value: session.scope
        )
        .prominentButtonStyleIfAvailable()
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.appBackground)
    }
}

// MARK: - Search Input Bar

struct SearchInputBar: View {
    @Binding var text: String
    @FocusState var isFocused: Bool
    @AppStorage("useDefaultTheme") private var useDefaultTheme: Bool = false
    var onSubmit: () -> Void

    init(
        text: Binding<String>,
        isFocused: FocusState<Bool> = FocusState(),
        onSubmit: @escaping () -> Void
    ) {
        self._text = text
        self._isFocused = isFocused
        self.onSubmit = onSubmit
    }

    init(
        viewModel: SearchViewModel,
        isFocused: FocusState<Bool> = FocusState(),
        onSubmit: @escaping () -> Void
    ) {
        self._text = Binding(get: { viewModel.query }, set: { viewModel.query = $0 })
        self._isFocused = isFocused
        self.onSubmit = onSubmit
    }

    var body: some View {
        TextField(
            "", text: $text,
            prompt: Text(.searchInSelectedBooks)
                .foregroundStyle(Color(useDefaultTheme
                                       ? .secondaryLabel
                                       : .iosTint))
        )
        .focused($isFocused)
        .submitLabel(.go)
        .onSubmit(onSubmit)
        .padding(.leading, 20)
        .padding(.trailing, 44)
        .frame(height: 40)
        .background(Color.appCellBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.secondary, lineWidth: 0.3)
        )
        .overlay(alignment: .trailing) {
            Button(action: onSubmit) {
                Image(systemName: "play.fill")
                    .foregroundStyle(Color(useDefaultTheme
                                           ? .secondaryLabel
                                           : .iosTint))
                    .padding(.trailing, 20)
            }
            .accessibilityLabel("Start Search")
            .help("Start Search")
        }
        .shadow(
            color: .black.opacity(isFocused ? 0.15 : 0.1),
            radius: isFocused ? 8 : 15, x: 0, y: 2
        )
        .padding(.vertical)
        .padding(.horizontal, 20)
    }
}

// MARK: - Search Help View

struct SearchHelpView: View {
    var isSefaria: Bool? = nil

    var body: some View {
        ThemeScrollView {
            ThemeVStack(alignment: .leading, spacing: 14) {
                Label("עזרה לאפשרויות חיפוש", systemImage: "questionmark.circle")
                    .font(.headline)
                    .padding(.bottom, 4)

                if isSefaria != true {
                    otzariaModesHelp
                }

                if isSefaria == nil {
                    Divider()
                }

                if isSefaria != false {
                    sefariaModesHelp
                }
            }
            .padding()
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var otzariaModesHelp: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isSefaria == nil {
                Text("מצבי חיפוש באוצריא")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Label("מדויק", systemImage: "text.quote")
                    .font(.subheadline).bold()
                Text("איתור ביטוי או מילים ברצף המדויק כפי שנכתבו. זהו מצב החיפוש המהיר ביותר.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Label("מתקדם", systemImage: "slider.horizontal.3")
                    .font(.subheadline).bold()
                Text("חיפוש רב-עוצמה הכולל מרחק בין מילים, החרגת מילים, קידומות וסיומות דקדוקיות, כתיב מלא וחסר, ארמית, ומילים חלופיות.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Label("מקורב", systemImage: "character.bubble")
                    .font(.subheadline).bold()
                Text("איתור מילים גם כאשר קיימות שגיאות כתיב קלות או שינויי אותיות (מרחק עריכה).")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Label("זית", systemImage: "sparkles")
                    .font(.subheadline).bold()
                Text("חיפוש סמנטי והקשרי מהיר לאיתור מקורות לפי משמעות ונושא.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var sefariaModesHelp: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isSefaria == nil {
                Text("מצבי חיפוש בספריא")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Label("מדויק", systemImage: "text.quote")
                    .font(.subheadline).bold()
                Text("חיפוש מילים או ביטויים בדיוק כפי שהוזנו.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Label("למטיזציה (מתקדם)", systemImage: "character.book.closed")
                    .font(.subheadline).bold()
                Text("חיפוש חכם המזהה שורשים, הטיות דקדוקיות וצורות מילים שונות לפי מילון ספריא, עם אפשרות להגדרת מרחק מילים.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - View Modifiers

extension View {
    func prominentButtonStyleIfAvailable() -> some View {
        modifier(ProminentButtonStyle())
    }

    func hideTabBarWhenKeyboardShown() -> some View {
        modifier(HideTabBarWhenKeyboardShown())
    }

    func readInputBarHeight() -> some View {
        modifier(InputBarHeightReader())
    }
}

struct ProminentButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .buttonStyle(.glassProminent)
                .tint(.clear)
        } else {
            content
                .buttonStyle(.borderedProminent)
        }
    }
}

struct HideTabBarWhenKeyboardShown: ViewModifier {
    @State private var isKeyboardVisible = false

    func body(content: Content) -> some View {
        content
            .toolbarVisibility(isKeyboardVisible ? .hidden : .visible, for: .tabBar)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                isKeyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                isKeyboardVisible = false
            }
    }
}

struct InputBarHeightReader: ViewModifier {
    @State private var inputBarHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { inputBarHeight = geo.size.height }
                        .onChange(of: geo.size.height) { _, h in inputBarHeight = h }
                }
            }
    }
}

// MARK: - Search Toolbar

struct SearchToolbar: ToolbarContent {
    @Bindable var viewModel: SearchViewModel
    var onLeadingAction: (() -> Void)?
    var conditionalLeadingButton: Bool = true
    var showSortMenu: Bool = false
    var showSaveMenu: Bool = false
    var canSaveResults: Bool = true
    var sortKey: SearchSortKey = .bookTitle
    var sortAscending: Bool = true
    var onSortChange: ((SearchSortKey, Bool) -> Void)?
    var onSaveResults: (() -> Void)?
    var onSavedResults: (() -> Void)?

    var body: some ToolbarContent {
        // Leading
        if (!conditionalLeadingButton) ||
            (!viewModel.results.isEmpty && conditionalLeadingButton) {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { onLeadingAction?() }) {
                    Label(.close, systemImage: conditionalLeadingButton
                          ? "xmark.circle"
                          : "")
                }
                .accessibilityLabel(.close)
                .help(.close)
            }
        }

        // Play/Pause + Stop
        ToolbarItemGroup(placement: .topBarTrailing) {
            Toggle(
                "",
                systemImage: viewModel.isSearching && !viewModel.isPaused
                    ? "pause" : "play",
                isOn: Binding(
                    get: { viewModel.isSearching },
                    set: { _, _ in Task { await viewModel.startSearch() }}
                )
            )
            .labelStyle(.iconOnly)
            .toggleStyle(.button)

            if viewModel.isSearching {
                Button(action: { viewModel.stopSearch() }) {
                    Image(systemName: "stop")
                        .foregroundColor(.red)
                }
                .accessibilityLabel("Stop Search")
                .help("Stop Search")
            } else if showSortMenu, !viewModel.results.isEmpty {
                sortMenu
            }
        }

        CustomToolbarSpacer(placement: .topBarTrailing)

        // Save menu
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                if showSaveMenu {
                    Button(action: { onSavedResults?() }) {
                        Label("Saved Results", systemImage: "bookmark")
                    }
                }

                if !viewModel.results.isEmpty && canSaveResults {
                    Button(action: { onSaveResults?() }) {
                        Label("Save Results", systemImage: "pencil.line")
                    }
                }
            } label: {
                Label(.moreOptions, systemImage: "ellipsis")
            }
            .accessibilityLabel("Search Options")
            .help("Search Options")
        }
    }

    @ViewBuilder
    private var sortMenu: some View {
        Menu {
            ForEach(SearchSortKey.allCases, id: \.self) { key in
                Button {
                    if sortKey == key {
                        onSortChange?(key, !sortAscending)
                    } else {
                        onSortChange?(key, true)
                    }
                } label: {
                    Label(
                        key.label,
                        systemImage: sortKey == key
                            ? (sortAscending ? "chevron.up" : "chevron.down")
                            : ""
                    )
                }
            }
        } label: {
            Label("Sort By", systemImage: "arrow.up.arrow.down")
        }
    }
}

// MARK: - Search Progress View

struct SearchProgressView: View {
    @Bindable var viewModel: SearchViewModel
    var showTablesProgress: Bool = false
    var showIntegrationState: Bool = true
    @Environment(iOSNavigationManager.self) var navigationManager: iOSNavigationManager

    var body: some View {
        let integrationStates = navigationManager.activeIntegrationStates
        if viewModel.isSearching || !integrationStates.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isSearching {
                    VStack(alignment: .leading) {
                        if showTablesProgress {
                            ProgressView(
                                value: Double(min(viewModel.completedTables, viewModel.totalTables)),
                                total: Double(max(viewModel.totalTables, 1))
                            )
                            .progressViewStyle(.linear)
                        }

                        if viewModel.totalRowsInTable > 0 {
                            ProgressView(
                                value: Double(viewModel.completedRowsInTable),
                                total: Double(viewModel.totalRowsInTable)
                            )
                            .progressViewStyle(.linear)
                            .padding(.top, showTablesProgress ? 4 : 0)
                        } else if !showTablesProgress {
                            ProgressView()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                }
                if showIntegrationState {
                    ActiveIntegrationStatesView()
                }
            }
            .animation(
                .easeIn(duration: 0.5),
                value: [viewModel.completedRowsInTable, viewModel.completedTables]
            )
        }
    }
}


// MARK: - Unified Search Toolbar

struct UnifiedSearchToolbar: ToolbarContent {
    @Bindable var session: UnifiedSearchSessionController
    var onLeadingAction: (() -> Void)? = nil
    var showSortMenu: Bool = true
    var showSaveMenu: Bool = true
    var canSaveResults: Bool = true
    var onSaveResults: (() -> Void)? = nil
    var onSavedResults: (() -> Void)? = nil

    var body: some ToolbarContent {
        // Leading: Close / Clear
        if !session.results.isEmpty {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: {
                    if let onLeadingAction {
                        onLeadingAction()
                    } else {
                        session.clearResults()
                        session.query = ""
                    }
                }) {
                    Label(.close, systemImage: "xmark.circle")
                }
                .accessibilityLabel(.close)
                .help(.close)
            }
        }

        // Filter button
        ToolbarItem(placement: .topBarLeading) {
            Button(action: { session.showsBookFilterSheet = true }) {
                Label(
                    session.selectedBookIds.isEmpty ? "Filter" : "Filter (\(session.selectedBookIds.count))",
                    systemImage: session.selectedBookIds.isEmpty
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill"
                )
            }
            .accessibilityLabel("Filter Books")
            .help("Filter Books")
        }

        // Play/Stop + Sort
        ToolbarItemGroup(placement: .topBarTrailing) {
            if session.isSearching {
                Button(action: {
                    if session.isSefaria {
                        session.searchViewModel?.stopSearch()
                    }
                    session.isSearching = false
                }) {
                    Image(systemName: "stop.fill")
                        .foregroundColor(.red)
                }
                .accessibilityLabel("Stop Search")
                .help("Stop Search")
            } else {
                Button(action: { session.runSearch() }) {
                    Image(systemName: "play.fill")
                }
                .accessibilityLabel("Start Search")
                .help("Start Search")
            }

            if session.hasConfigurableOptions {
                UnifiedSearchAdvancedOptionsButton(session: session)
            }

            if showSortMenu, !session.results.isEmpty {
                sortMenu
            }
        }

        CustomToolbarSpacer(placement: .topBarTrailing)

        // Save menu
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                if showSaveMenu {
                    Button(action: { onSavedResults?() }) {
                        Label("Saved Results", systemImage: "bookmark")
                    }
                }

                if !session.results.isEmpty && canSaveResults {
                    Button(action: { onSaveResults?() }) {
                        Label("Save Results", systemImage: "pencil.line")
                    }
                }

                if !session.isSefaria {
                    Button(action: { session.showsSearchDataSheet = true }) {
                        Label("Search Data Status", systemImage: "internaldrive")
                    }
                }
            } label: {
                Label(.moreOptions, systemImage: "ellipsis")
            }
            .accessibilityLabel("More Options")
            .help("More Options")
        }
    }

    @ViewBuilder
    private var sortMenu: some View {
        if session.isSefaria {
            Menu {
                Button {
                    session.sefariaSortOrder = .relevance
                    session.runSearch()
                } label: {
                    Label("רלוונטיות", systemImage: session.sefariaSortOrder == .relevance ? "checkmark" : "")
                }
                Button {
                    session.sefariaSortOrder = .canonical
                    session.runSearch()
                } label: {
                    Label("סדר קנוני", systemImage: session.sefariaSortOrder == .canonical ? "checkmark" : "")
                }
                Button {
                    session.sefariaSortOrder = .chronological
                    session.runSearch()
                } label: {
                    Label("כרונולוגי", systemImage: session.sefariaSortOrder == .chronological ? "checkmark" : "")
                }

                Divider()

                Button {
                    session.sefariaReverseSort.toggle()
                    session.runSearch()
                } label: {
                    Label("סדר הפוך", systemImage: session.sefariaReverseSort ? "checkmark.square" : "square")
                }
            } label: {
                Label("מיון", systemImage: "arrow.up.arrow.down")
            }
        } else if session.scope != .zayit {
            Menu {
                Button {
                    session.otzariaOrder = .catalogue
                    session.runSearch()
                } label: {
                    Label("סדר קטלוגי", systemImage: session.otzariaOrder == .catalogue ? "checkmark" : "")
                }
                Button {
                    session.otzariaOrder = .relevance
                    session.runSearch()
                } label: {
                    Label("רלוונטיות", systemImage: session.otzariaOrder == .relevance ? "checkmark" : "")
                }
            } label: {
                Label("מיון", systemImage: "arrow.up.arrow.down")
            }
        }
    }
}

// MARK: - Unified Search Progress View

struct UnifiedSearchProgressView: View {
    @Bindable var session: UnifiedSearchSessionController
    var showIntegrationState: Bool = true
    @Environment(iOSNavigationManager.self) var navigationManager: iOSNavigationManager

    var body: some View {
        let integrationStates = navigationManager.activeIntegrationStates
        if session.isSearching || !integrationStates.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                if session.isSearching {
                    HStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.small)
                        Text(session.statusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                }
                if showIntegrationState {
                    ActiveIntegrationStatesView()
                }
            }
            .animation(.easeIn(duration: 0.3), value: session.isSearching)
        }
    }
}

// MARK: - Search Advanced Options View
 
struct SearchAdvancedOptionsView: View {
    @Bindable var session: UnifiedSearchSessionController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if session.isSefaria {
                    sefariaOptionsSection
                } else {
                    otzariaOptionsSection
                }
            }
            .navigationTitle("אפשרויות חיפוש")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("סיום") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var sefariaOptionsSection: some View {
        Section(header: Text("הגדרות ספריא")) {
            Picker("מצב התאמה", selection: $session.sefariaMatchMode) {
                Text("מדויק").tag(LibrarySearchMatchMode.exact)
                Text("למטיזציה (הטיות דקדוקיות)").tag(LibrarySearchMatchMode.hebrewLemmatized)
            }

            Stepper("מרחק מילים מקסימלי: \(session.sefariaWordDistance)", value: $session.sefariaWordDistance, in: 0...50)

            Picker("סדר תוצאות", selection: $session.sefariaSortOrder) {
                Text("רלוונטיות").tag(LibrarySearchSortOrder.relevance)
                Text("סדר קנוני").tag(LibrarySearchSortOrder.canonical)
                Text("כרונולוגי").tag(LibrarySearchSortOrder.chronological)
            }

            Toggle("סדר הפוך", isOn: $session.sefariaReverseSort)
        }
    }

    @ViewBuilder
    private var otzariaOptionsSection: some View {
        Section(header: Text("סדר ומיון")) {
            Picker("סדר תוצאות", selection: $session.otzariaOrder) {
                ForEach(OtzariaSearchOrder.allCases, id: \.self) { order in
                    Text(order.label).tag(order)
                }
            }
        }

        Section(header: Text("החרגת מילים")) {
            TextField("מילים להחרגה", text: $session.otzariaNegativeQuery)
        }

        Section(header: Text("מרחק והתאמה")) {
            Stepper("מרחק מילים: \(session.otzariaDistance)", value: $session.otzariaDistance, in: 0...50)

            Picker("אופן התאמת מילים", selection: $session.otzariaWordMatchMode) {
                ForEach(OtzariaWordMatchMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            if session.otzariaWordMatchMode == .atLeast {
                Stepper("מספר מילים להתאמה: \(session.otzariaWordMatchCount)", value: $session.otzariaWordMatchCount, in: 1...20)
            }
        }

        Section(header: Text("מורפולוגיה ודקדוק")) {
            Toggle("קידומות", isOn: $session.otzariaEnablesPrefixes)
            Toggle("סיומות", isOn: $session.otzariaEnablesSuffixes)
            Toggle("כתיב מלא / חסר", isOn: $session.otzariaEnablesSpellingVariants)
            Toggle("ארמית (תרגום וסיומות)", isOn: $session.otzariaEnablesAramaic)
            Toggle("התעלם מגרשיים / ראשי תיבות", isOn: $session.otzariaIgnoresQuotes)
            Toggle("התאמת ניקוד", isOn: $session.otzariaMatchNikud)
            Toggle("התאמת טעמים", isOn: $session.otzariaMatchTaamim)
        }

        Section(header: Text("הגדרות מתקדמות נוספות")) {
            TextField("ריווח מותאם אישית", text: $session.otzariaCustomSpacingText)
            TextField("מילים חלופיות", text: $session.otzariaAlternativeWordsText)
        }
    }
}

typealias UnifiedSearchAdvancedOptionsSheet = SearchAdvancedOptionsView


