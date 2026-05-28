//
//  iOSReaderBottomToolbarView.swift
//  Maktabah
//
//  Created by Ghoys Mawahib on 28/05/26.
//

import SwiftUI

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
        Button(
            viewModel.statusSubtitle,
            action: {
                showingNavigation.toggle()
            }
        )
        .popover(isPresented: $showingNavigation) {
            iOSReaderNavigationPopoverView(viewModel: viewModel)
        }

        Spacer()

        Button(action: {
            showingOptions = true
        }) {
            Image(systemName: "textformat")
        }
        .accessibilityLabel(String(localized: "Text Options"))
        .help(String(localized: "Text Options"))
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
        .accessibilityLabel(String(localized: "Table of Contents"))
        .help(String(localized: "Table of Contents"))

        Button(action: {
            showingAnnotationsList = true
        }) {
            Image(systemName: "quote.closing")
        }
        .accessibilityLabel(String(localized: "Annotations"))
        .help(String(localized: "Annotations"))

        if MaktabahApp.isIpad { Spacer() }

        Button(action: {
            showingSearch = true
        }) {
            Image(systemName: "magnifyingglass")
        }
        .accessibilityLabel(String(localized: "Search"))
        .help(String(localized: "Search"))
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

#Preview {
    let mockBook = BooksData(
        id: 1,
        book: "Sahih al-Bukhari",
        archive: 0,
        muallif: 1
    )
    let mockViewModel = iOSReaderViewModel(book: mockBook)
    return iOSReaderBottomToolbarView(viewModel: mockViewModel)
}
