import SwiftUI

struct iOSReaderTabView: View {
    @Environment(iOSNavigationManager.self) var bManager
    @State private var showingBookInfo = false
    @State private var textViewState = TextViewState.shared

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
        if bManager.openTabs.count > 0,
           let activeTab = bManager.openTabs.first(where: { $0.id == bManager.activeTabId })
               ?? bManager.openTabs.first
        {
            iOSReaderView(
                book: activeTab.book,
                viewModel: activeTab.viewModel,
                initialContentId: activeTab.initialContentId
            )
            .id(activeTab.id)
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
                                }
                            }
                            .padding(4)
                            .background(Color(.systemBackground).opacity(0.4))
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
    @State private var textViewState = TextViewState.shared
    @State private var showingNavigation = false
    @State private var showingOptions = false
    @State private var showingTOC = false
    @State private var showingAnnotationsList = false
    @State private var showingSearch = false

    var isDarkMode: Bool {
        textViewState.isDarkMode
    }

    var body: some View {
        Button(viewModel.statusSubtitle, action: {
            showingNavigation.toggle()
        })
        .popover(isPresented: $showingNavigation) {
            iOSReaderNavigationPopoverView(viewModel: viewModel)
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
                .preferredColorScheme(isDarkMode ? .dark : .light)
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

        if MaktabahApp.isIpad { Spacer() }

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

    var activeColor: Color {
        if #available(iOS 26.0, *) {
            return Color.accentColor
        } else {
            return Color(uiColor: .systemBackground)
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            if isActive {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.8))
                        .padding(2)
                        .background(Color.secondary.opacity(0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Text(tab.book.book)
                .fontWeight(isActive ? .medium : .regular)
                .lineLimit(1)
                .foregroundColor(
                    isActive
                        ? activeColor
                        : .primary
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            isActive
                ? Color.secondary
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}

// MARK: - Navigation Popover View

struct iOSReaderNavigationPopoverView: View {
    @Bindable var viewModel: iOSReaderViewModel
    @State private var textViewState = TextViewState.shared
    
    // Feedback and local slider states
    @State private var localPart: Double = 1
    @State private var localPage: Double = 1
    @State private var isSlidingPart = false
    @State private var isSlidingPage = false
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 20) {
            if viewModel.totalParts > 1 {
                VStack(spacing: 8) {
                    if isSlidingPart {
                        Text("الجزء: \(Int(localPart))".convertToArabicDigits())
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    } else {
                        Text("الجزء")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("١".convertToArabicDigits())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Slider(value: $localPart, in: 1 ... Double(max(1, viewModel.totalParts)), step: 1) { editing in
                            isSlidingPart = editing
                            if !editing {
                                viewModel.jumpToPart(Int(localPart))
                            }
                        }
                        
                        Text("\(viewModel.totalParts)".convertToArabicDigits())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .environment(\.layoutDirection, .rightToLeft)
            }

            if viewModel.maxPageInPart > viewModel.minPageInPart {
                VStack(spacing: 8) {
                    if isSlidingPage {
                        Text("الصفحة: \(Int(localPage))".convertToArabicDigits())
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    } else {
                        Text("الصفحة")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("\(viewModel.minPageInPart)".convertToArabicDigits())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Slider(value: $localPage, in: Double(viewModel.minPageInPart) ... Double(viewModel.maxPageInPart), step: 1) { editing in
                            isSlidingPage = editing
                            if !editing {
                                viewModel.jumpToPage(Int(localPage))
                            }
                        }
                        
                        Text("\(viewModel.maxPageInPart)".convertToArabicDigits())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .environment(\.layoutDirection, .rightToLeft)
            }
        }
        .padding()
        .frame(width: 300)
        .presentationCompactAdaptation(.popover)
        .preferredColorScheme(textViewState.isDarkMode ? .dark : .light)
        .onAppear {
            localPart = Double(max(1, viewModel.currentPart ?? 1))
            localPage = Double(max(1, viewModel.currentPage ?? 1))
        }
        .onChange(of: viewModel.currentPart) { _, newValue in
            if !isSlidingPart {
                localPart = Double(max(1, newValue ?? 1))
            }
        }
        .onChange(of: viewModel.currentPage) { _, newValue in
            if !isSlidingPage {
                localPage = Double(max(1, newValue ?? 1))
            }
        }
        .onChange(of: localPart) { _, newValue in
            if isSlidingPart {
                debounceJump(mode: .part, value: Int(newValue))
            }
        }
        .onChange(of: localPage) { _, newValue in
            if isSlidingPage {
                debounceJump(mode: .page, value: Int(newValue))
            }
        }
    }
    
    private enum JumpMode { case part, page }

    private func debounceJump(mode: JumpMode, value: Int) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000) // 0.25s
            if !Task.isCancelled {
                if mode == .part {
                    viewModel.jumpToPart(value)
                } else {
                    viewModel.jumpToPage(value)
                }
            }
        }
    }
}
