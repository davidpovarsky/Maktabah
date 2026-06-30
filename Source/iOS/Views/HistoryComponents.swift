//
//  FavoriteComponents.swift
//  Maktabah-iOS
//

import SwiftUI

// MARK: - Favorite Card

struct BookCard: View {
    let book: BooksData
    let cardHeight: CGFloat
    let isFavorite: Bool
    @ObservedObject var viewModel: HistoryViewModel
    let historySection: Bool
    let action: () -> Void

    @State private var showPopover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(book.book)
                    .font(ReaderViewModel.kfgqpcList)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if !historySection {
                    Spacer()
                }

                Button(action: {
                    viewModel.toggleFavorite(book.id)
                }) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundColor(isFavorite ? .yellow : .gray)
                }
                .accessibilityLabel(isFavorite ? String(localized: "Remove Favorite") : String(localized: "Add Favorite"))
                .help(isFavorite ? String(localized: "Remove Favorite") : String(localized: "Add Favorite"))
                .buttonStyle(.plain)
            }
            .environment(\.layoutDirection, .rightToLeft)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(height: cardHeight)
            .clipShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.5) {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                showPopover = true
            }
            .popover(isPresented: $showPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                Button(role: .destructive) {
                    showPopover = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        viewModel.removeHistory(for: book.id)
                    }
                } label: {
                    Label("Remove from History", systemImage: "clock.badge.xmark")
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .presentationCompactAdaptation(.popover)
            }
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.appCellBackground)
                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color(.secondarySystemFill), lineWidth: 0.3)
            )
        }
        .padding(
            .horizontal, MaktabahApp.isIpad ? 0 : historySection ? 0 : 2
        )
        .buttonStyle(.plain)
    }
}

extension BooksData {
    convenience init(id: Int, book: String) {
        self.init(id: id, book: book, archive: 1, muallif: 1)
    }
}

#Preview {
    let mockBooks = [
        BooksData(id: 1, book: "صحيح البخاري (Sahih Al-Bukhari)"),
        BooksData(id: 2, book: "صحيح مسلم (Sahih Muslim)"),
        BooksData(id: 3, book: "سنن التِّرْمِذِي (Sunan At-Tirmidhi)"),
        BooksData(id: 4, book: "سنen أَبِي دَاوُدَ (Sunan Abi Dawud)"),
        BooksData(id: 5, book: "موطأ الإمام مالك (Al-Muwatta)"),
        BooksData(id: 6, book: "رياض الصالحين (Riyad As-Salihin)"),
        BooksData(id: 7, book: "تفسير الجلالين (Tafsir Al-Jalalayn)"),
        BooksData(id: 8, book: "العقيدة الواسطية (Al-Aqidah Al-Wasitiyyah)"),
        BooksData(id: 9, book: "بلوغ المرام (Bulugh Al-Maram)")
    ]

    let mockViewModel = HistoryViewModel.shared
    let mockNavManager = iOSNavigationManager()

    NavigationStack {
        VStack(alignment: .leading) {
            Text("Kitab Favorit")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            ForEach(mockBooks, id: \.id) { book in
                BookCard(
                    book: book,
                    cardHeight: 50,
                    isFavorite: mockViewModel.isFavorite(book.id),
                    viewModel: mockViewModel,
                    historySection: true
                ) {}
            }

            Spacer()
        }
        .background(Color(.systemGroupedBackground))
        .environment(mockNavManager)
    }
}
