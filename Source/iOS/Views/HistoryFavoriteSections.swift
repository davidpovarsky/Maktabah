//
//  HistoryFavoriteSections.swift
//  Maktabah-iOS
//
//  Reusable section components untuk Favorites dan History,
//  dipakai bersama oleh iPadLayout (sidebar) dan iOSHistoryView.
//

import SwiftUI

// MARK: - HistorySection

/// Section "History" dengan horizontal grid.
/// Tambahkan ke dalam `List` / `ThemeList` yang sudah ada.
struct HistorySection: View {
    let books: [BooksData]
    @ObservedObject var viewModel: HistoryViewModel

    var body: some View {
        Section(header: Text("History")) {
            HistoryHorizontalGrid(books: books, viewModel: viewModel)
                .padding(.top, 12)
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }
}

// MARK: - FavoritesSection

/// Section "Favorite" dengan tap-to-open.
/// Tambahkan ke dalam `List` / `ThemeList` yang sudah ada.
struct FavoritesSection: View {
    let books: [BooksData]
    @ObservedObject var viewModel: HistoryViewModel
    let onOpen: (BooksData) -> Void

    var body: some View {
        Section(header: Text("Favorites")) {
            ForEach(books, id: \.id) { book in
                BookCard(
                    book: book,
                    cardHeight: 50,
                    isFavorite: viewModel.isFavorite(book.id),
                    viewModel: viewModel, historySection: false
                ) {
                    onOpen(book)
                }
                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
    }
}

// MARK: - HistoryEmptyState

/// Placeholder saat tidak ada history maupun favorit.
struct HistoryEmptyState: View {
    let searchText: String

    var body: some View {
        if !searchText.isEmpty {
            Text("No results found for \"\(searchText)\"")
                .foregroundColor(.secondary)
        } else {
            Text("No recent history")
                .foregroundColor(.secondary)
        }
    }
}
