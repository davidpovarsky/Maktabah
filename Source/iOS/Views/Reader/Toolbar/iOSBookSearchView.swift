//
//  iOSBookSearchView.swift
//  Maktabah
//
//  Created by Ghoys Mawahib on 28/05/26.
//

import SwiftUI

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
                            ProgressView(
                                value: Double(viewModel.completedRowsInTable),
                                total: Double(viewModel.totalRowsInTable)
                            )
                            .progressViewStyle(LinearProgressViewStyle())
                        } else {
                            ProgressView()
                        }
                    }
                    .padding(.horizontal)
                }

                Divider()

                // Results List
                SearchResultsListView(
                    results: viewModel.results,
                    showsBookTitle: false
                ) { item in
                    onSelect(item.bookId, viewModel.query)
                }
            }
            .navigationTitle("Search in \(book.book)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.selectedBookIds = [book.id]
            }
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
    let mockViewModel = iOSSearchViewModel()
    return iOSBookSearchView(
        book: mockBook,
        onSelect: { _, _ in },
        viewModel: mockViewModel
    )
}
