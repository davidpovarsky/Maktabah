import SwiftUI

struct iOSReaderView: View {
    let book: BooksData
    let initialContentId: Int?
    var ipad: Bool {
        MaktabahApp.isIpad
    }

    var viewModel: iOSReaderViewModel
    @State private var textViewState = TextViewState.shared

    @State private var showingTOC = false
    @State private var showingOptions = false
    @State private var showingSearch = false
    @State private var showingAnnotationsList = false
    @State private var showingBookInfo = false
    @State private var showingAnnotationActionSheet = false
    @State private var tappedAnnotationId: Int64?
    @State private var showingEditNoteAlert = false
    @State private var editingNoteText = ""
    @State private var showingNavigation = false

    init(book: BooksData,
         viewModel: iOSReaderViewModel? = nil,
         initialContentId: Int? = nil)
    {
        self.book = book
        self.initialContentId = initialContentId
        self.viewModel = viewModel ?? iOSReaderViewModel(book: book)
    }

    var backgroundColor: Color {
        let colors: [Color] = [
            .white,
            .bgSepia,
            .bgSepiaDark,
            .bgGray,
            .black,
        ]
        let index = textViewState.backgroundColorIndex

        if index >= 0, index < colors.count {
            return colors[index]
        }
        return Color(UIColor.systemBackground)
    }

    var isDarkMode: Bool {
        textViewState.isDarkMode
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        iOSIbarotTextView(
            text: $viewModel.contentText,
            annotations: viewModel.currentAnnotations,
            searchText: $viewModel.searchText,
            targetAnnotation: viewModel.targetAnnotation,
            isMultiLanguage: book.isMultiLanguage,
            viewModel: viewModel,
            onAddAnnotation: { range, mode, sourceText, color in
                viewModel.addAnnotation(in: range, mode: mode, sourceText: sourceText, color: color)
            },
            onTapAnnotation: { annId in
                tappedAnnotationId = annId
                showingAnnotationActionSheet = true
            }
        )
        .background(backgroundColor)
        .ignoresSafeArea(edges: .vertical)
        .legacyVisibleToolbarBackgrounds()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .navigationTitle(viewModel.book.book)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    showingBookInfo = true
                }) {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel(String(localized: "Book Information"))
                .help(String(localized: "Book Information"))
                .popover(isPresented: $showingBookInfo) {
                    iOSBookInfoView(book: book)
                        .preferredColorScheme(isDarkMode ? .dark : .light)
                        .presentationCompactAdaptation(.popover)
                        .frame(maxWidth: 350, maxHeight: 450)
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: {
                    viewModel.goToNextPage()
                }) {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel(String(localized: "Next Page"))
                .help(String(localized: "Next Page"))
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button(action: {
                    viewModel.goToPrevPage()
                }) {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel(String(localized: "Previous Page"))
                .help(String(localized: "Previous Page"))
                .keyboardShortcut(.rightArrow, modifiers: [])
            }

            ToolbarItemGroup(placement: .bottomBar) {
                iOSReaderBottomToolbarView(viewModel: viewModel)
            }
        }
        .onAppear {
            if viewModel.contentText.isEmpty {
                viewModel.loadInitialContent(initialContentId: initialContentId)
            }
        }
        .onChange(of: initialContentId) { _, newValue in
            if let newValue {
                viewModel.fetchContentById(newValue)
            }
        }
        .sheet(isPresented: $showingSearch) {
            iOSBookSearchView(book: book, onSelect: { contentId, query in
                viewModel.searchText = query
                viewModel.fetchContentById(contentId)
                showingSearch = false
            }, viewModel: viewModel.searchViewModel)
        }
        .sheet(isPresented: $showingTOC) {
            iOSTOCView(
                nodes: viewModel.tocNodes,
                selectedId: viewModel.findNodeId(forContentId: viewModel.currentContentId),
                onSelect: { id in
                    viewModel.searchText = ""
                    viewModel.targetAnnotation = nil
                    viewModel.fetchContentById(id)
                    showingTOC = false
                }
            )
        }
        .sheet(isPresented: $showingAnnotationsList) {
            iOSBookAnnotationsView(
                bookId: book.id,
                annotations: viewModel.currentAnnotations,
                onSelect: { ann in
                    viewModel.targetAnnotation = ann
                    viewModel.fetchContentById(Int(ann.contentId))
                    showingAnnotationsList = false
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { showingAnnotationActionSheet && tappedAnnotationId != nil },
            set: { if !$0 { showingAnnotationActionSheet = false; tappedAnnotationId = nil } }
        )) {
            if let id = tappedAnnotationId, let ann = viewModel.currentAnnotations.first(where: { $0.id == id }) {
                iOSAnnotationEditorSheet(
                    annotation: ann,
                    onSave: { updatedAnn in
                        viewModel.updateAnnotation(updatedAnn)
                    },
                    onDelete: { idToDelete in
                        viewModel.deleteAnnotation(id: idToDelete)
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
    }
}

// MARK: - TOC View

/// We need an identifiable wrapper for TOCNode to work nicely with SwiftUI List
struct iOSIdentifiableTOCNode: Identifiable {
    let id: Int
    let node: TOCNode
    var children: [iOSIdentifiableTOCNode]?

    init(_ node: TOCNode) {
        id = node.id
        self.node = node
        if !node.children.isEmpty {
            children = node.children.map { iOSIdentifiableTOCNode($0) }
        } else {
            children = nil
        }
    }
}

struct iOSTOCView: View {
    let nodes: [TOCNode]
    let selectedId: Int?
    let onSelect: (Int) -> Void
    @Environment(\.presentationMode) var presentationMode

    @State private var expandedPaths: Set<Int> = []
    @State private var searchText = ""

    var identifiableNodes: [iOSIdentifiableTOCNode] {
        if searchText.isEmpty {
            return nodes.map { iOSIdentifiableTOCNode($0) }
        } else {
            let normalizedQuery = searchText.normalizeArabic(true)

            func searchAndFlatten(nodes: [TOCNode]) -> [TOCNode] {
                var matches: [TOCNode] = []
                for node in nodes {
                    if node.bab.normalizeArabic(true).localizedStandardContains(normalizedQuery) {
                        let flatNode = TOCNode(from: TOC(bab: node.bab, level: node.level, sub: node.sub, id: node.id))
                        matches.append(flatNode)
                    }
                    matches.append(contentsOf: searchAndFlatten(nodes: node.children))
                }
                return matches
            }

            return searchAndFlatten(nodes: nodes).map { iOSIdentifiableTOCNode($0) }
        }
    }

    func computeExpandedPaths() -> Set<Int> {
        guard let targetId = selectedId else { return [] }
        var paths = Set<Int>()

        func search(nodes: [TOCNode], path: [Int]) -> Bool {
            for node in nodes {
                if node.id == targetId {
                    paths.formUnion(path)
                    return true
                }
                if !node.children.isEmpty {
                    if search(nodes: node.children, path: path + [node.id]) {
                        paths.formUnion(path)
                        return true
                    }
                }
            }
            return false
        }

        _ = search(nodes: nodes, path: [])
        return paths
    }

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ThemeList(isGrouped: true) {
                    ForEach(identifiableNodes) { item in
                        TOCNodeRow(item: item, selectedId: selectedId, onSelect: onSelect, expandedPaths: $expandedPaths)
                    }
                }
                .searchable(text: $searchText, prompt: "Search Contents")
                .navigationTitle("Table of Contents")
                .navigationBarItems(leading: Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                })
                .onAppear {
                    expandedPaths = computeExpandedPaths()
                    if let selectedId {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation {
                                proxy.scrollTo(selectedId, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct TOCNodeRow: View {
    let item: iOSIdentifiableTOCNode
    let selectedId: Int?
    let onSelect: (Int) -> Void
    @Binding var expandedPaths: Set<Int>

    var isExpanded: Binding<Bool> {
        Binding(
            get: { expandedPaths.contains(item.id) },
            set: { isExpanding in
                if isExpanding {
                    expandedPaths.insert(item.id)
                } else {
                    expandedPaths.remove(item.id)
                }
            }
        )
    }

    var body: some View {
        if let children = item.children, !children.isEmpty {
            DisclosureGroup(isExpanded: isExpanded) {
                ForEach(children) { child in
                    TOCNodeRow(item: child, selectedId: selectedId, onSelect: onSelect, expandedPaths: $expandedPaths)
                }
            } label: {
                nodeLabel
            }
            .id(item.id)
        } else {
            nodeLabel
                .id(item.id)
        }
    }

    var nodeLabel: some View {
        Button(action: {
            onSelect(item.node.id)
        }) {
            Text(item.node.bab)
                .font(iOSReaderViewModel.kfgqpc)
                .foregroundColor(item.node.id == selectedId ? .accentColor : .primary)
        }
    }
}

// MARK: - Book Search View

struct iOSBookSearchView: View {
    let book: BooksData
    let onSelect: (Int, String) -> Void
    @Environment(\.presentationMode) var presentationMode

    @Bindable var viewModel: iOSSearchViewModel

    var body: some View {
        NavigationView {
            ThemeVStack(spacing: 0) {
                // Search Bar
                ThemeHStack {
                    TextField("Search in book...", text: $viewModel.query)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            viewModel.startSearch()
                        }

                    if viewModel.isSearching {
                        Button(action: { viewModel.stopSearch() }) {
                            Image(systemName: "stop.fill")
                                .foregroundColor(.red)
                        }
                        .accessibilityLabel(String(localized: "Stop Search"))
                        .help(String(localized: "Stop Search"))
                    } else {
                        Button(action: { viewModel.startSearch() }) {
                            Image(systemName: "magnifyingglass")
                        }
                        .accessibilityLabel(String(localized: "Start Search"))
                        .help(String(localized: "Start Search"))
                    }
                }
                .padding()

                // Options
                HStack {
                    Picker("Mode", selection: $viewModel.searchMode) {
                        Text("==").tag(SearchMode.phrase)
                        Text("&").tag(SearchMode.contains)
                        Text("/").tag(SearchMode.or)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                // Progress
                if viewModel.isSearching {
                    VStack(alignment: .leading) {
                        if viewModel.totalRowsInTable > 0 {
                            ProgressView(value: Double(viewModel.completedRowsInTable), total: Double(viewModel.totalRowsInTable))
                                .progressViewStyle(LinearProgressViewStyle())
                        } else {
                            ProgressView()
                        }
                    }
                    .padding(.horizontal)
                }

                Divider()

                // Results List
                SearchResultsListView(results: viewModel.results, showsBookTitle: false) { item in
                    onSelect(item.bookId, viewModel.query)
                }
            }
            .navigationTitle("Search in \(book.book)")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                viewModel.selectedBookIds = [book.id]
            }
        }
    }
}

// MARK: - Book Annotations View

struct iOSBookAnnotationsView: View {
    let bookId: Int
    let annotations: [Annotation]
    let onSelect: (Annotation) -> Void
    @Environment(\.presentationMode) var presentationMode

    /// Load annotations specific to this book directly from the manager
    @State private var bookAnnotations: [Annotation] = []

    var body: some View {
        NavigationView {
            ThemeList(bookAnnotations, id: \.id, isGrouped: false) { ann in
                Button(action: {
                    onSelect(ann)
                }) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(ann.context)
                            .font(iOSReaderViewModel.kfgqpc)
                            .lineLimit(3)
                            .truncationMode(.tail)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        if let note = ann.note, !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        HStack {
                            Circle()
                                .fill(Color(hex: ann.colorHex) ?? .yellow)
                                .frame(width: 12, height: 12)

                            Text(ann.type == .highlight ? "Highlight" : "Underline")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Spacer()

                            if let pgArb = ann.pageArb {
                                Text("Vol: \(ann.partArb ?? "") Page: \(pgArb)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .environment(\.layoutDirection, .leftToRight)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Annotations")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(action: {
                    CloudKitSyncManager.shared.resetChangeToken()
                }) {
                    Image(systemName: "arrow.counterclockwise.icloud")
                }
                .accessibilityLabel(String(localized: "Synchronize Data"))
                .help(String(localized: "Synchronize Data"))
            )
            .onAppear {
                loadBookAnnotations()
            }
        }
    }

    private func loadBookAnnotations() {
        if let bookNode = AnnotationManager.shared.rootNode?.children.first(where: {
            $0.kind == .book && $0.children.first?.annotation?.bkId == bookId
        }) {
            bookAnnotations = bookNode.children.compactMap(\.annotation)
        } else {
            let allAnns = AnnotationManager.shared.loadAnnotations(bkId: bookId)
            bookAnnotations = allAnns
        }
    }
}

private extension View {
    @ViewBuilder
    func legacyVisibleToolbarBackgrounds() -> some View {
        if #unavailable(iOS 26) {
            self
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(.visible, for: .bottomBar)
        } else {
            self
        }
    }
}
