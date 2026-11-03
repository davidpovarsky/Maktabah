//
//  ReaderSidebarPager.swift
//  Maktabah
//
//  Downstream-owned Craft-style 2-screen sidebar pager (Library + TOC) and 2-column NavigationSplitView host.
//

#if os(iOS)
import SwiftUI

/// Hosts the 2-screen Craft-style sidebar (`iOSLibraryView` + `iOSTOCView`) in a single sidebar column
/// with horizontal page swiping and a bottom page-dot indicator (`>= 44x44pt` hit targets).
struct ReaderSidebarPager: View {
    @Environment(iOSNavigationManager.self) private var navigationManager
    @Bindable var coordinator: ReaderSidebarStateCoordinator
    @Binding var showSettings: Bool

    var body: some View {
        TabView(selection: $coordinator.selectedPage) {
            libraryPage
                .tag(ReaderSidebarPage.library)

            tocPage
                .tag(ReaderSidebarPage.toc)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            sidebarPageIndicatorBar
        }
        .background(Color.appBackground)
        .onChange(of: navigationManager.activeTabId) { _, newValue in
            coordinator.updateActiveReaderTabPresence(newValue != nil)
        }
        .onAppear {
            coordinator.updateActiveReaderTabPresence(navigationManager.activeTab != nil)
        }
    }

    // MARK: - Pages

    @ViewBuilder
    private var libraryPage: some View {
        NavigationStack {
            if ChavrusaTextFeatureFlags.shared.effectiveSafariToolbarSearchEnabled {
                iOSLibraryView()
                    .navigationTitle(iOSTab.viewer.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarGeneral(showSettings: $showSettings)
            } else {
                iOSLibraryView()
                    .navigationTitle(iOSTab.viewer.title)
                    .searchable(
                        text: Bindable(navigationManager.libraryViewModel).searchQuery,
                        placement: .toolbar,
                        prompt: String(localized: "Search Library")
                    )
                    .toolbarGeneral(showSettings: $showSettings)
            }
        }
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(Color.appBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("library-column")
        .accessibilityLabel(ReaderSidebarPage.library.hebrewTitle)
    }

    @ViewBuilder
    private var tocPage: some View {
        if let activeTab = navigationManager.activeTab {
            iOSTOCView(
                tocViewModel: activeTab.viewModel.tocViewModel,
                selectedId: selectedTOCNode(for: activeTab.viewModel)?.id,
                bookTitle: activeTab.book.book,
                onClose: { coordinator.showLibrary() },
                embedsNavigationStack: false,
                onSelect: activeTab.viewModel.didSelectTOCNode
            )
            .toolbar(removing: .sidebarToggle)
            .onAppear {
                if activeTab.viewModel.tocViewModel.tocNodes.isEmpty && !activeTab.viewModel.tocViewModel.isLoading {
                    activeTab.viewModel.loadTOC(book: activeTab.book)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("toc-column")
            .accessibilityLabel(ReaderSidebarPage.toc.hebrewTitle)
        } else {
            emptyTOCPlaceholder
                .accessibilityIdentifier("toc-column")
        }
    }

    private func selectedTOCNode(for viewModel: ReaderViewModel) -> TOCNode? {
        if let locator = viewModel.backendSection?.locator,
           let node = viewModel.tocViewModel.findNode(for: locator) {
            return node
        }
        return viewModel.tocViewModel.findNode(forContentId: viewModel.currentContentId)
    }

    private var emptyTOCPlaceholder: some View {
        ContentUnavailableView {
            Label("אין ספר פתוח", systemImage: "book.closed")
        } description: {
            Text("בחר ספר מתוך לשונית הספרייה כדי להציג את תוכן העניינים שלו.")
        } actions: {
            Button("מעבר לספרייה") {
                withAnimation(.snappy(duration: 0.25)) {
                    coordinator.showLibrary()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    // MARK: - Bottom Page Dots (44x44pt Hit Targets)

    private var sidebarPageIndicatorBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                ForEach(ReaderSidebarPage.allCases) { page in
                    let isSelected = (coordinator.selectedPage == page)
                    Button {
                        withAnimation(.snappy(duration: 0.25)) {
                            coordinator.selectPage(page)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: page.systemImage)
                                .font(.caption.weight(isSelected ? .semibold : .regular))
                            Text(page.hebrewTitle)
                                .font(.caption.weight(isSelected ? .semibold : .regular))
                            Circle()
                                .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.35))
                                .frame(width: 7, height: 7)
                        }
                        .padding(.horizontal, 12)
                        .frame(minWidth: 44, minHeight: 44)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .accessibilityLabel(page.hebrewTitle)
                    .accessibilityValue(isSelected ? "נבחר" : "לא נבחר")
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
        }
    }
}

/// Downstream-owned 2-column `NavigationSplitView` host for the `.viewer` mode on iPad.
/// Replaces the legacy 3-column `NavigationSplitView(sidebar:content:detail:)` when `sidebarPagerEnabled` is active.
struct ReaderTwoColumnSplitHost: View {
    @Bindable var sidebarCoordinator: ReaderSidebarStateCoordinator
    @Binding var preferredCompactColumn: NavigationSplitViewColumn
    @Binding var showSettings: Bool

    var body: some View {
        NavigationSplitView(
            columnVisibility: sidebarCoordinator.splitViewVisibilityBinding,
            preferredCompactColumn: $preferredCompactColumn
        ) {
            ReaderSidebarPager(
                coordinator: sidebarCoordinator,
                showSettings: $showSettings
            )
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
        } detail: {
            GeometryReader { proxy in
                iOSReaderTabView(
                    columnVisibility: sidebarCoordinator.splitViewVisibilityBinding,
                    preferredCompactColumn: $preferredCompactColumn,
                    sidebarCoordinator: sidebarCoordinator
                )
                .background(ReaderInspectorHostPolicy.resolvedWorkspaceBackgroundColor())
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("reader-detail-column")
                .onAppear {
                    sidebarCoordinator.availableReaderWidth = proxy.size.width
                }
                .onChange(of: proxy.size.width) { _, newWidth in
                    sidebarCoordinator.availableReaderWidth = newWidth
                }
            }
        }
        .environment(sidebarCoordinator)
        .navigationSplitViewStyle(.balanced)
        .background(Color.appBackground.ignoresSafeArea())
    }
}
#endif
