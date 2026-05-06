import SwiftUI

struct iOSReaderTabView: View {
    @Environment(iOSNavigationManager.self) var bManager
    @State private var showingBookInfo = false

    var textViewState = TextViewState.shared

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
        textViewState.backgroundColorIndex > 1
    }

    var body: some View {
        if bManager.openTabs.count > 0 {
            // Tab Content
            TabView(selection: Binding(
                get: { bManager.activeTabId },
                set: { bManager.activeTabId = $0 }
            )) {
                ForEach(bManager.openTabs) { tab in
                    iOSReaderView(
                        book: tab.book,
                        viewModel: tab.viewModel,
                        initialContentId: tab.initialContentId
                    )
                    .tag(tab.id as UUID?)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(backgroundColor)
            .toolbar {
                if bManager.openTabs.count > 1 {
                    ToolbarItem(placement: .principal) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(Array(bManager.openTabs.enumerated()), id: \.element.id) { index, tab in
                                    ReaderTabItemView(
                                        tab: tab,
                                        isActive: bManager.activeTabId == tab.id,
                                        onSelect: { bManager.selectTab(id: tab.id) },
                                        onClose: { bManager.closeTab(id: tab.id) },
                                        darkMode: isDarkMode
                                    )

                                    if index < bManager.openTabs.count - 1 {
                                        Divider()
                                            .frame(height: 16)
                                    }
                                }
                            }
                            .padding(3)
                            .background(Color(.systemFill).opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                        .environment(\.layoutDirection, .leftToRight)
                    }
                }

                if bManager.openTabs.count == 1,
                    let activeTab = bManager.openTabs.first
                {
                    ToolbarItem(placement: .principal) {
                        Text(activeTab.book.book)
                            .font(iOSReaderViewModel.kfgqpc)
                            .foregroundStyle(isDarkMode ? .white : .black)
                    }
                }

                if let activeTab = bManager.openTabs.first(where: { $0.id == bManager.activeTabId }) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { showingBookInfo = true }) {
                            Image(systemName: "info.circle")
                        }
                        .popover(isPresented: $showingBookInfo) {
                            iOSBookInfoView(book: activeTab.book)
                                .presentationCompactAdaptation(.popover)
                                .frame(maxWidth: 350, maxHeight: 450)
                        }
                    }

                    if MaktabahApp.isIpad {
                        ToolbarItemGroup(placement: .bottomBar) {
                            iOSReaderBottomToolbarView(
                                viewModel: activeTab.viewModel
                            )
                        }
                    }
                }
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "book.closed")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)
                Text("Select a book to read")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct iOSReaderBottomToolbarView: View {
    @Bindable var viewModel: iOSReaderViewModel
    @State private var showingNavigation = false
    @State private var showingOptions = false
    @State private var showingTOC = false
    @State private var showingAnnotationsList = false
    @State private var showingSearch = false

    var body: some View {
        Text(viewModel.statusSubtitle)
            .font(.system(size: 13))
            .lineLimit(1)
            .multilineTextAlignment(.center)
            .frame(width: 100)

        Spacer()

        Button(action: {
            viewModel.goToNextPage()
        }) {
            Image(systemName: "chevron.left")
        }
        .keyboardShortcut(.leftArrow, modifiers: [])

        Button(action: {
            viewModel.goToPrevPage()
        }) {
            Image(systemName: "chevron.right")
        }
        .keyboardShortcut(.rightArrow, modifiers: [])

        Button(action: {
            showingNavigation.toggle()
        }) {
            Image(systemName: "slider.horizontal.3")
                .foregroundColor(showingNavigation ? .accentColor : .primary)
        }
        .popover(isPresented: $showingNavigation) {
            VStack(spacing: 16) {
                if viewModel.totalParts > 1 {
                    HStack {
                        Text("ج")
                            .font(.caption)
                            .frame(width: 40)
                        Slider(value: Binding(
                            get: {
                                let part = viewModel.currentPart ?? 1
                                return Double(part <= 0 ? 1 : part)
                            },
                            set: { viewModel.jumpToPart(Int($0)) }
                        ), in: 1 ... Double(viewModel.totalParts), step: 1)
                        Text("\(viewModel.totalParts)".convertToArabicDigits())
                            .font(.caption)
                            .frame(width: 40)
                    }
                    .environment(\.layoutDirection, .rightToLeft)
                }

                if viewModel.maxPageInPart > viewModel.minPageInPart {
                    HStack {
                        Text("ص")
                            .font(.caption)
                            .frame(width: 40)
                        Slider(value: Binding(
                            get: {
                                let page = viewModel.currentPage ?? 1
                                return Double(page <= 0 ? 1 : page)
                            },
                            set: { viewModel.jumpToPage(Int($0)) }
                        ), in: Double(viewModel.minPageInPart) ... Double(viewModel.maxPageInPart), step: 1)
                        Text("\(viewModel.maxPageInPart)".convertToArabicDigits())
                            .font(.caption)
                            .frame(width: 40)
                    }
                    .environment(\.layoutDirection, .rightToLeft)
                }
            }
            .padding()
            .frame(width: 300)
            .presentationCompactAdaptation(.popover)
        }

        Spacer()

        Button(action: {
            showingOptions = true
        }) {
            Image(systemName: "textformat")
        }
        .popover(isPresented: $showingOptions) {
            ViewOptionsView()
                .frame(width: 300, height: 500)
                .presentationCompactAdaptation(.popover)
        }

        Button(action: {
            showingTOC = true
        }) {
            Image(systemName: "list.bullet")
        }

        Button(action: {
            showingAnnotationsList = true
        }) {
            Image(systemName: "quote.closing")
        }

        Spacer()

        Button(action: {
            showingSearch = true
        }) {
            Image(systemName: "magnifyingglass")
        }
        .sheet(isPresented: $showingSearch) {
            iOSBookSearchView(
                book: viewModel.book,
                onSelect: { contentId, query in
                    viewModel.searchText = query
                    viewModel.fetchContentById(contentId)
                    showingSearch = false
                },
                viewModel: viewModel.searchViewModel
            )
        }
        .sheet(isPresented: $showingTOC) {
            iOSTOCView(
                nodes: viewModel.tocNodes,
                selectedId: viewModel.findNodeId(
                    forContentId: viewModel.currentContentId
                ),
                onSelect: { id in
                    viewModel.fetchContentById(id)
                    showingTOC = false
                }
            )
        }
        .sheet(isPresented: $showingAnnotationsList) {
            iOSBookAnnotationsView(
                bookId: viewModel.book.id,
                annotations: viewModel.currentAnnotations,
                onSelect: { ann in
                    viewModel.fetchContentById(Int(ann.contentId))
                    showingAnnotationsList = false
                }
            )
        }
    }
}

struct ReaderTabItemView: View {
    let tab: iOSNavigationManager.ReaderTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let darkMode: Bool

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .regular))
                    .foregroundColor(
                        isActive
                            ? (darkMode ? Color.white : Color.black)
                            : (darkMode ? Color.white.opacity(0.4) : Color.black.opacity(0.3))
                    )
                    .padding(3)
                    .background(
                        isActive
                            ? (darkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.1))
                            : Color.clear
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text(tab.book.book)
                .font(.subheadline)
                .fontWeight(.regular)
                .lineLimit(1)
                .foregroundColor(
                    isActive
                        ? (darkMode ? Color.white : Color.black)
                        : (darkMode ? Color.white.opacity(0.5) : Color.black.opacity(0.4))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .background(
            isActive
                ? (darkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.08))
                : (darkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}

#Preview {
    iOSReaderTabView()
}
