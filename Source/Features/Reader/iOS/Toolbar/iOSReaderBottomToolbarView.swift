//
//  iOSReaderBottomToolbarView.swift
//  Maktabah
//
//  Created by Ghoys Mawahib on 28/05/26.
//

import SwiftUI

struct iOSReaderBottomToolbarView: View {
    @Bindable var viewModel: ReaderViewModel
    var onShowTableOfContents: (() -> Void)? = nil
    var tableOfContentsIsPresented = false
    @Binding var showingAnnotationsList: Bool
    var textViewState = TextViewState.shared
    @State private var showingNavigation = false
    @State private var showingOptions = false
    @State private var showingTOC = false
    @State private var showingSearch = false

    @Environment(\.layoutDirection) private var layoutDirection

    var isDarkMode: Bool {
        textViewState.isDarkMode
    }

    var body: some View {
        Button {
            showingNavigation.toggle()
        } label: {
            ReaderNavigationDisplayLabel(viewModel: viewModel, fallback: viewModel.statusSubtitle)
        }
        .popover(isPresented: $showingNavigation) {
            iOSReaderNavigationPopoverView(viewModel: viewModel)
                .presentationCompactAdaptation(.popover)
        }
        .onChange(of: showingNavigation) { _, newValue in
            viewModel.isPopoverPresented = newValue || showingOptions || showingSearch
        }

        Spacer()

        Group {
            if layoutDirection == .rightToLeft {
                prevButton
                nextButton
            } else {
                nextButton
                prevButton
            }
        }

        Spacer()

        Button(action: {
            showingSearch = true
        }) {
            Image(systemName: "magnifyingglass")
        }
        .accessibilityLabel(String(localized: "Search"))
        .help(String(localized: "Search"))

        if viewModel.hasActiveSearchHighlight {
            Button(action: {
                viewModel.clearSearchHighlight()
            }) {
                Image(systemName: "xmark.circle")
            }
            .accessibilityIdentifier("reader.clear_search_highlight_button")
            .accessibilityLabel(String(localized: "Clear Search Highlights"))
            .help(String(localized: "Clear Search Highlights"))
        }

        Menu {
            Button(action: {
                DispatchQueue.main.async {
                    showingOptions = true
                }
            }) {
                Label("View Options", systemImage: "textformat")
            }
            .accessibilityLabel(String(localized: "Text Options"))
            .help(String(localized: "Text Options"))

            Button(action: {
                if let onShowTableOfContents {
                    onShowTableOfContents()
                } else {
                    DispatchQueue.main.async {
                        showingTOC = true
                    }
                }
            }) {
                Label("Table of Contents", systemImage: "list.bullet")
            }
            .accessibilityLabel(
                tableOfContentsIsPresented
                    ? String(localized: "Close Table of Contents")
                    : String(localized: "Table of Contents")
            )
            .accessibilityIdentifier("reader-toc-toggle")
            .help(String(localized: "Table of Contents"))

            Button(action: {
                DispatchQueue.main.async {
                    showingAnnotationsList = true
                }
            }) {
                Label("Annotations", systemImage: "quote.closing")
            }
            .accessibilityLabel(String(localized: "Annotations"))
            .help(String(localized: "Annotations"))

            if !viewModel.otzariaAvailableUnitModes.isEmpty {
                Divider()

                Menu {
                    ForEach(viewModel.otzariaAvailableUnitModes) { option in
                        Button {
                            viewModel.setOtzariaUnitMode(option.mode)
                        } label: {
                            if option.mode == viewModel.otzariaUnitMode {
                                Label(option.title, systemImage: "checkmark")
                            } else {
                                Text(option.title)
                            }
                        }
                    }
                } label: {
                    Label("Display by", systemImage: "text.badge.checkmark")
                }
            }
        } label: {
            Label("More Reader Actions", systemImage: "ellipsis")
                .labelStyle(.iconOnly)
        }
        .accessibilityIdentifier("reader-more-menu")
        .popover(isPresented: $showingOptions) {
            ViewOptionsView(readerViewModel: viewModel)
                .frame(width: 300, height: 500)
                .presentationCompactAdaptation(.popover)
        }
        .onChange(of: showingOptions) { _, newValue in
            viewModel.isPopoverPresented = newValue || showingNavigation || showingSearch
        }
        .onChange(of: showingSearch) { _, newValue in
            viewModel.isPopoverPresented = newValue || showingNavigation || showingOptions
        }
        .sheet(isPresented: $showingSearch) {
            if let book = viewModel.currentBook {
                iOSBookSearchView(
                    book: book,
                    onSelect: { result, query in
                        viewModel.didSelectSearch(result: result, query: query)
                        showingSearch = false
                    },
                    viewModel: viewModel.searchViewModel
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { onShowTableOfContents == nil && showingTOC },
            set: { showingTOC = $0 }
        )) {
            iOSTOCView(
                tocViewModel: viewModel.tocViewModel,
                selectedId: viewModel.tocViewModel.findNode(
                    forContentId: viewModel.currentContentId
                )?.id,
                onRetry: viewModel.currentBook.map { book in
                    { viewModel.loadTOC(book: book) }
                },
                onSelect: { id, title in
                    viewModel.didSelectTOCNode(id: id, title: title)
                    showingTOC = false
                }
            )
        }

    }

    private var nextButton: some View {
        Button(action: { viewModel.goToNextPage() }) {
            Image(systemName: "chevron.left")
        }
        .accessibilityLabel(String(localized: "Next Page"))
        .help(String(localized: "Next Page"))
        .keyboardShortcut(.leftArrow, modifiers: [])
    }

    private var prevButton: some View {
        Button(action: { viewModel.goToPrevPage() }) {
            Image(systemName: "chevron.right")
        }
        .accessibilityLabel(String(localized: "Previous Page"))
        .help(String(localized: "Previous Page"))
        .keyboardShortcut(.rightArrow, modifiers: [])
    }
}

#Preview {
    let mockBook = BooksData(
        id: 1,
        book: "Sahih al-Bukhari",
        archive: 0,
        muallif: 1
    )
    let mockViewModel = ReaderViewModel(book: mockBook)
    return iOSReaderBottomToolbarView(viewModel: mockViewModel, showingAnnotationsList: .constant(false))
}
