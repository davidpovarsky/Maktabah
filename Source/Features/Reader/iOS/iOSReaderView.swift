//
//  iOSReaderView.swift
//  Maktabah
//
//  Created by Ghoys Mawahib on 15/05/26.
//

import SwiftUI
import OSLog

struct iOSReaderView: View {
    let book: BooksData
    let initialContentId: Int?
    let onShowTableOfContents: (() -> Void)?
    private let columnVisibility: Binding<NavigationSplitViewVisibility>?

    var viewModel: ReaderViewModel
    var textViewState = TextViewState.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(iOSNavigationManager.self) var bManager

    var isRegularLayout: Bool {
        horizontalSizeClass == .regular
    }

    var ipad: Bool {
        MaktabahApp.isIpad
    }

    @State private var showingBookInfo = false
    @State private var showingAnnotationActionSheet = false
    @State private var tappedAnnotationId: Int64?
    @State private var isReading = false
    @ObservedObject private var annotationRefreshCoordinator = ReaderAnnotationRefreshCoordinator.shared

    init(
        book: BooksData,
        viewModel: ReaderViewModel? = nil,
        initialContentId: Int? = nil,
        columnVisibility: Binding<NavigationSplitViewVisibility>? = nil,
        onShowTableOfContents: (() -> Void)? = nil
    ) {
        self.book = book
        self.initialContentId = initialContentId
        self.columnVisibility = columnVisibility
        self.onShowTableOfContents = onShowTableOfContents
        self.viewModel = viewModel ?? ReaderViewModel(book: book)
    }

    init(
        book: BooksData,
        viewModel: ReaderViewModel? = nil,
        initialContentId: Int? = nil,
        onShowTableOfContents: (() -> Void)? = nil,
        columnVisibility: Binding<NavigationSplitViewVisibility>? = nil
    ) {
        self.init(
            book: book,
            viewModel: viewModel,
            initialContentId: initialContentId,
            columnVisibility: columnVisibility,
            onShowTableOfContents: onShowTableOfContents
        )
    }

    private var shouldShowPrimarySidebarButton: Bool {
        guard MaktabahApp.isIpad else { return false }

        // iPadOS 27 restores the native NavigationSplitView sidebar toggle.
        // Keep the manual fallback only for iPadOS 26 and earlier.
        if #available(iOS 27.0, *) {
            return false
        }

        guard let columnVisibility else { return false }
        return columnVisibility.wrappedValue == .detailOnly
    }

    private func showPrimarySidebar() {
        columnVisibility?.wrappedValue = .all
    }

    private var tableOfContentsIsPresented: Bool {
        guard let columnVisibility else { return false }
        return columnVisibility.wrappedValue != .detailOnly
    }

    private func toggleTableOfContents() {
        if tableOfContentsIsPresented {
            columnVisibility?.wrappedValue = .detailOnly
        } else {
            onShowTableOfContents?()
        }
    }

    var backgroundColor: Color {
        textViewState.backgroundColor.color
    }

    var isDarkMode: Bool {
        textViewState.isDarkMode
    }

    private var resolvedNavigationTitle: String {
        bManager.openTabs.count > 1 ? "" : book.book
    }

    var body: some View {
        _ReaderTextContentView(
            book: book,
            viewModel: viewModel,
            textViewState: textViewState,
            annotationRevision: annotationRefreshCoordinator.revision,
            tappedAnnotationId: $tappedAnnotationId,
            showingAnnotationActionSheet: $showingAnnotationActionSheet
        )
        .equatable()
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .navigationTitle(resolvedNavigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .platformTabBarVisibility(hiddenOnPhone: true)
        .if(!MaktabahApp.isIpad) { view in
            view.toolbarVisibility(
                isReading ? .hidden : .visible,
                for: .navigationBar, .bottomBar
            )
        }
        .onTapGesture {
            withAnimation(.easeInOut) {
                isReading.toggle()
            }
        }
        .toolbar {
            if shouldShowPrimarySidebarButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation {
                            showPrimarySidebar()
                        }
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                    .accessibilityLabel(String(localized: "Show Sidebar"))
                    .help(String(localized: "Show Sidebar"))
                }
            }

            if (!isRegularLayout && !ipad) || (!isRegularLayout && bManager.openTabs.count > 1) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        bManager.showingTabsList.toggle()
                    } label: {
                        Text(book.book)
                            .lineLimit(1)
                            .frame(maxWidth: 190)
                            .contentShape(Rectangle())
                    }
                }
            }

            CustomToolbarSpacer(placement: .topBarTrailing)

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingBookInfo = true
                } label: {
                    Label(.Library.bookInfo, systemImage: "info.circle")
                }
                .accessibilityLabel(String(localized: .Library.bookInfo))
                .help(String(localized: .Library.bookInfo))
                .popover(isPresented: $showingBookInfo) {
                    iOSBookInfoCardView(book: book)
                        .presentationCompactAdaptation(.popover)
                        .preferredColorScheme(isDarkMode ? .dark : .light)
                }
            }

            ToolbarItemGroup(placement: .bottomBar) {
                iOSReaderBottomToolbarView(
                    viewModel: viewModel,
                    onShowTableOfContents: toggleTableOfContents,
                    tableOfContentsIsPresented: tableOfContentsIsPresented
                )
            }
        }
        .onChange(of: initialContentId) { _, newValue in
            if viewModel.contentText.isEmpty {
                viewModel.loadInitialContent(initialContentId: newValue)
            }
        }
        .onAppear {
            viewModel.needsScrollRestore = true
        }
        .onDisappear {
            viewModel.saveCurrentState()
        }
        .sheet(isPresented: Binding(
            get: { showingAnnotationActionSheet && tappedAnnotationId != nil },
            set: { if !$0 { showingAnnotationActionSheet = false; tappedAnnotationId = nil } }
        )) {
            if let id = tappedAnnotationId, let ann = viewModel.currentAnnotations.first(where: { $0.id == id }) {
                iOSAnnotationEditorSheet(
                    annotation: ann,
                    onSave: { updatedAnn in
                        try viewModel.updateAnnotation(updatedAnn)
                        NotificationCenter.default.post(name: .torahInspectorNotesDidChange, object: nil)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    },
                    onDelete: { idToDelete in
                        try viewModel.deleteAnnotation(id: idToDelete)
                        NotificationCenter.default.post(name: .torahInspectorNotesDidChange, object: nil)
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
    }
}

// MARK: - Isolated Text Content View

/// Extracted to its own struct so that `@State` sheet toggles in `iOSReaderView`
/// don't invalidate the `UIViewRepresentable` body and trigger `updateUIView`.
private struct _ReaderTextContentView: View {
    let book: BooksData
    var viewModel: ReaderViewModel
    var textViewState: TextViewState
    var annotationRevision: UInt64 = 0
    @Binding var tappedAnnotationId: Int64?
    @Binding var showingAnnotationActionSheet: Bool

    var body: some View {
        @Bindable var viewModel = viewModel
        iOSIbarotTextView(
            text: $viewModel.contentText,
            annotations: viewModel.currentAnnotations,
            searchEvent: viewModel.searchEvent,
            annotationEvent: viewModel.annotationEvent,
            targetAnnotation: viewModel.targetAnnotation,
            selectedSegmentRange: viewModel.selectedSegmentRange,
            isMultiLanguage: viewModel.usesNaturalReaderTextDirection,
            isImported: viewModel.backendRenderModel == nil && book.isImported,
            enhancedUnderline: textViewState.enhancedUnderline,
            viewModel: viewModel,
            onAddAnnotation: { range, mode, sourceText, color in
                do {
                    try viewModel.addAnnotation(in: range, mode: mode, sourceText: sourceText, color: color)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } catch {
                    Logger.reader.error("Failed to add annotation: \(error.localizedDescription, privacy: .public)")
                    ReaderAnnotationRefreshCoordinator.shared.recordError(error)
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            },
            onTapAnnotation: { annId in
                tappedAnnotationId = annId
                showingAnnotationActionSheet = true
            },
            onTapTextCharacterIndex: { index in
                viewModel.didTapReaderText(at: index)
            },
            onManualScrollAwayFromSearchResult: {
                viewModel.clearSearchHighlight()
            },
            onNavigateNext: { viewModel.goToNextPage() },
            onNavigatePrev: { viewModel.goToPrevPage() }
        )
        .background(textViewState.backgroundColor.color)
        .ignoresSafeArea(edges: .vertical)
        .legacyVisibleToolbarBackgrounds()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension _ReaderTextContentView: @MainActor Equatable {
    static func == (lhs: _ReaderTextContentView, rhs: _ReaderTextContentView) -> Bool {
        lhs.annotationRevision == rhs.annotationRevision &&
            lhs.book.id == rhs.book.id &&
            lhs.viewModel === rhs.viewModel &&
            !rhs.viewModel.needsScrollRestore &&
            lhs.viewModel.currentContentId == rhs.viewModel.currentContentId &&
            lhs.viewModel.contentText == rhs.viewModel.contentText &&
            lhs.viewModel.currentAnnotations == rhs.viewModel.currentAnnotations &&
            lhs.viewModel.searchEvent == rhs.viewModel.searchEvent &&
            lhs.viewModel.annotationEvent == rhs.viewModel.annotationEvent &&
            lhs.viewModel.selectedSegmentRange == rhs.viewModel.selectedSegmentRange &&
            lhs.viewModel.targetAnnotation == rhs.viewModel.targetAnnotation &&
            lhs.textViewState.showHarakat == rhs.textViewState.showHarakat &&
            lhs.textViewState.enhancedUnderline == rhs.textViewState.enhancedUnderline &&
            lhs.textViewState.fontName == rhs.textViewState.fontName &&
            lhs.textViewState.fontSize == rhs.textViewState.fontSize &&
            lhs.textViewState.lineHeight == rhs.textViewState.lineHeight &&
            lhs.textViewState.backgroundColorIndex == rhs.textViewState.backgroundColorIndex
    }
}

private extension View {
    @ViewBuilder
    func legacyVisibleToolbarBackgrounds() -> some View {
        if #unavailable(iOS 26) {
            toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(.visible, for: .bottomBar)
        } else {
            self
        }
    }

    @ViewBuilder
    func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
