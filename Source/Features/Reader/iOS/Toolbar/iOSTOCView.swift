//
//  iOSTOCView.swift
//  Maktabah
//
//  Created by Ghoys Mawahib on 28/05/26.
//

import OSLog
import SwiftUI

struct iOSTOCView: View {
    let tocViewModel: BookTOCViewModel
    let selectedId: Int?
    let bookTitle: String?
    let onClose: (() -> Void)?
    let onRetry: (() -> Void)?
    let embedsNavigationStack: Bool
    let onSelect: (Int, String) -> Void

    @State private var searchText = ""
    @State private var expandedPaths: Set<ObjectIdentifier> = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.readerSidebarOwnsToggle) private var sidebarOwnsToggle
    @Environment(\.readerSidebarUsesSharedSearch) private var sidebarUsesSharedSearch

    init(
        tocViewModel: BookTOCViewModel,
        selectedId: Int?,
        bookTitle: String? = nil,
        onClose: (() -> Void)? = nil,
        onRetry: (() -> Void)? = nil,
        embedsNavigationStack: Bool = true,
        onSelect: @escaping (Int, String) -> Void
    ) {
        self.tocViewModel = tocViewModel
        self.selectedId = selectedId
        self.bookTitle = bookTitle
        self.onClose = onClose
        self.onRetry = onRetry
        self.embedsNavigationStack = embedsNavigationStack
        self.onSelect = onSelect
    }

    init(
        tocViewModel: BookTOCViewModel,
        selectedId: Int?,
        bookTitle: String? = nil,
        onClose: (() -> Void)? = nil,
        onRetry: (() -> Void)? = nil,
        embedsNavigationStack: Bool = true,
        onSelect: @escaping (Int) -> Void
    ) {
        self.init(
            tocViewModel: tocViewModel,
            selectedId: selectedId,
            bookTitle: bookTitle,
            onClose: onClose,
            onRetry: onRetry,
            embedsNavigationStack: embedsNavigationStack,
            onSelect: { id, _ in onSelect(id) }
        )
    }

    var identifiableNodes: [TOCNode] {
        if searchText.isEmpty {
            return tocViewModel.tocNodes
        } else {
            let normalizedQuery = searchText.normalizeArabic(true)
            // perf: Use a single compactMap pass instead of chaining .map().filter().map()
            // to eliminate intermediate O(N) array allocations during real-time keystroke searches.
            return tocViewModel.tocRanges.compactMap { range in
                let node = range.node
                if node.bab.normalizeArabic(true).localizedStandardContains(normalizedQuery) {
                    return TOCNode(from: TOC(bab: node.bab, level: node.level, sub: node.sub, id: node.id))
                }
                return nil
            }
        }
    }

    func computeExpandedPaths() {
        guard let targetId = selectedId, let node = tocViewModel.findNodeById(targetId) else { return }
        if let path = tocViewModel.pathToNode(node) {
            expandedPaths = Set(path.map { ObjectIdentifier($0) })
        }
    }

    var body: some View {
        Group {
            if embedsNavigationStack {
                NavigationStack { contents }
            } else {
                contents
            }
        }
        .presentationBackground(Color.appBackground)
        .themeTint()
        .listStyle(.plain)
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        #if DEBUG && targetEnvironment(simulator)
        .task { await SefariaTOCOwnerAcceptance.observe(tocViewModel, onRetry: onRetry) }
        #endif
    }

    private var contents: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                if tocViewModel.navigationStructures.count > 1 {
                    Picker("Structure", selection: Binding(
                        get: { tocViewModel.selectedStructureID },
                        set: { newID in
                            tocViewModel.selectStructure(id: newID)
                        }
                    )) {
                        ForEach(tocViewModel.navigationStructures) { structItem in
                            Text(structItem.title).tag(structItem.id)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("toc-structure-picker")
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.appBackground)
                }

                if let failure = tocViewModel.loadFailure {
                    ContentUnavailableView {
                        Label(String(localized: "Table of Contents Unavailable"),
                              systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(failure.message)
                    } actions: {
                        if let onRetry {
                            Button("Retry", action: onRetry)
                                .accessibilityIdentifier("toc-retry")
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("toc-failure")
                } else if (tocViewModel.isLoading || tocViewModel.loadingStatus == .loading || tocViewModel.loadingStatus == .idle) && identifiableNodes.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(String(localized: "Loading Table of Contents..."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("toc-loading")
                } else if identifiableNodes.isEmpty {
                    ContentUnavailableView(
                        String(localized: "No Table of Contents"),
                        systemImage: "list.bullet.rectangle"
                    )
                    .accessibilityIdentifier("toc-empty")
                } else {
                    ScrollViewReader { proxy in
                        ThemeList(isGrouped: false) {
                            ForEach(identifiableNodes) { item in
                                TOCNodeRow(
                                    item: item,
                                    selectedId: selectedId,
                                    onSelect: onSelect,
                                    expandedPaths: $expandedPaths
                                )
                            }
                        }
                        .accessibilityIdentifier("toc-content-list")
                        .modifier(ReaderSidebarContentsSearch(text: $searchText))
                        .navigationBarTitleDisplayMode(.inline)
                        .modifier(ReaderContentsNavigationTitle(bookTitle: bookTitle))
                        .toolbar {
                            if !sidebarOwnsToggle {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button {
                                        if let onClose {
                                            onClose()
                                        } else {
                                            dismiss()
                                        }
                                    } label: {
                                        ContentsToggleIcon(isOpen: true)
                                    }
                                    .accessibilityLabel(String(localized: "Close Table of Contents"))
                                    .accessibilityIdentifier("toc-close")
                                    .help(String(localized: "Close Table of Contents"))
                                }
                            }
                            if !sidebarUsesSharedSearch {
                                ToolbarItem(placement: .principal) {
                                    VStack(spacing: 1) {
                                        Text(String(localized: "Table of Contents"))
                                            .font(.headline)
                                        if let bookTitle, !bookTitle.isEmpty {
                                            Text(bookTitle)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }
                        .onAppear {
                            scrollSelected(proxy: proxy)
                        }
                        .onChange(of: tocViewModel.tocRanges.count) { _, _ in
                            scrollSelected(proxy: proxy)
                        }
                        .onChange(of: selectedId) { _, _ in
                            scrollSelected(proxy: proxy)
                        }
                    }
                }
            }
        }
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func scrollSelected(proxy: ScrollViewProxy) {
        computeExpandedPaths()
        guard let selectedId else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation {
                proxy.scrollTo(selectedId, anchor: .center)
            }
        }
    }
}

#Preview {
    let node1 = TOCNode(from: TOC(bab: "المقدمة (Tanpa Sub)", level: 1, sub: 0, id: 1))
    let node2 = TOCNode(from: TOC(bab: "كتاب الطهارة (Dengan Sub)", level: 1, sub: 0, id: 2))
    let node2_1 = TOCNode(from: TOC(bab: "باب الوضوء", level: 2, sub: 1, id: 3))
    let node2_2 = TOCNode(from: TOC(bab: "باب الغسل (Dengan Sub)", level: 2, sub: 1, id: 4))
    let node2_2_1 = TOCNode(from: TOC(bab: "فصل في موجبات الغسل", level: 3, sub: 2, id: 5))
    
    node2_2.children = [node2_2_1]
    node2.children = [node2_1, node2_2]
    
    let node3 = TOCNode(from: TOC(bab: "كتاب الصلاة", level: 1, sub: 0, id: 6))
    
    let mockNodes = [node1, node2, node3]
    
    let dummyVM = BookTOCViewModel(connFactory: { BookConnection() })
    dummyVM.tocNodes = mockNodes

    return iOSTOCView(
        tocViewModel: dummyVM,
        selectedId: 3,
        onSelect: { selectedId, title in
            Logger.reader.debug("Selected ID: \(selectedId), Title: \(title)")
        }
    )
}

#if DEBUG && targetEnvironment(simulator)
/// The only initiation is the mounted original TOC owner's existing reload
/// callback. TaskLocal inheritance must be observed by the real HTTP request;
/// no data, status or successful result can be supplied by this acceptance hook.
@MainActor
private enum SefariaTOCOwnerAcceptance {
    static func observe(_ owner: BookTOCViewModel, onRetry: (() -> Void)?) async {
        guard OtzariaDataProfileRegistry.activeProfileID == "miniTest10",
              let configuration = SefariaTOCTransportAcceptance.configuration,
              let onRetry else { return }
        let deadline = ContinuousClock.now.advanced(by: .seconds(60))
        while !Task.isCancelled, ContinuousClock.now < deadline {
            if let nonce = SefariaTOCTransportAcceptance.command(configuration: configuration) {
                let roots = owner.navigationStructures.flatMap(\.nodes)
                guard !owner.isLoading, owner.loadingStatus == .loaded,
                      owner.loadFailure == nil, !roots.isEmpty,
                      roots.allSatisfy({ $0.locator.backend == .sefaria && $0.locator.workKey == "Genesis" }),
                      let context = SefariaTOCTransportAcceptance.arm(configuration: configuration,
                        nonce: nonce, ownerID: String(describing: ObjectIdentifier(owner))) else { return }
                SefariaTOCTransportAcceptance.$context.withValue(context) { onRetry() }
                return
            }
            do { try await Task.sleep(for: .milliseconds(100)) }
            catch { return }
        }
    }
}
#endif
