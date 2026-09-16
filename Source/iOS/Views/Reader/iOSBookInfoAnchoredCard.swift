//
//  iOSBookInfoAnchoredCard.swift
//  Maktabah-iOS
//

import SwiftUI
import AnchoredPopup

/// Floating anchored inspection card for book metadata
struct iOSBookInfoCardView: View {
    let book: BooksData
    let popupId: String

    @State private var selectedSegment: BookInfoSegment = .bithoqoh
    @State private var fullBookInfo: BooksData?
    @State private var author: Muallif?
    @Environment(\.anchoredPopupDismiss) private var dismissPopup

    private var currentText: String {
        switch selectedSegment {
        case .bithoqoh:
            return fullBookInfo?.bithoqoh ?? book.bithoqoh
        case .author:
            let authorName = (author?.namaLengkap ?? "")
            let authorInfo = (author?.info ?? "")
            if authorName.isEmpty {
                return authorInfo
            } else if authorInfo.isEmpty {
                return authorName
            } else {
                return "\(authorName)\n\n\(authorInfo)"
            }
        case .info:
            return fullBookInfo?.info ?? book.info
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header: Title and Close button
            HStack(alignment: .center, spacing: 8) {
                Text(book.book)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .environment(\.layoutDirection, .rightToLeft)

                Spacer()

                Button {
                    if let dismissPopup {
                        dismissPopup()
                    } else {
                        AnchoredPopup.launchShrinkingAnimation(id: popupId)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close"))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Segmented Picker
            Picker("Book Info", selection: $selectedSegment) {
                ForEach(BookInfoSegment.allCases) { segment in
                    Text(segment.title).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            Divider()

            // Content
            if currentText.isEmpty {
                VStack {
                    Spacer()
                    Text(.noMetadata)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                AnchoredReadOnlyTextView(text: currentText)
            }
        }
        .frame(width: 340, height: 420)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.18), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear {
            loadBookInfo()
        }
    }

    private func loadBookInfo() {
        let dm = LibraryDataManager.shared
        author = DatabaseManager.shared.getAuthor(book.muallif)
        fullBookInfo = dm.getBook([book.id]).first ?? book

        dm.loadBookInfo(book.id) {
            if let updatedBook = dm.getBook([book.id]).first {
                fullBookInfo = updatedBook
            }
        }
    }
}

/// Lightweight read-only text view using TextKit for zero-lag Arabic text rendering
private struct AnchoredReadOnlyTextView: UIViewRepresentable {
    let text: String
    var font: UIFont = .arabicFont(size: 20)

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(
            top: 10, left: 14, bottom: 14, right: 14
        )
        textView.textAlignment = .right
        textView.font = font
        textView.textColor = .label
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
            uiView.font = font
            uiView.textAlignment = .right
            uiView.setContentOffset(.zero, animated: false)
        }
    }
}

// MARK: - View Extension & Toolbar Component

struct BookInfoToolbarAnchorButton: View {
    let book: BooksData

    var body: some View {
        Button(action: {
            AnchoredPopup.launchGrowingAnimation(id: "book_info_\(book.id)")
        }) {
            Label("BookInfo", systemImage: "info.circle")
        }
        .bookInfoAnchoredPopup(book: book)
        .accessibilityLabel(String(localized: "Book Information"))
        .help(String(localized: "Book Information"))
    }
}

extension View {
    /// Anchors an expanding book info popup to the receiver.
    func bookInfoAnchoredPopup(book: BooksData) -> some View {
        let popupId = "book_info_\(book.id)"
        return self
            .useAsPopupAnchor(id: popupId) {
                iOSBookInfoCardView(book: book, popupId: popupId)
            } customize: {
                $0.position(.anchorRelative(.bottomTrailing, keepInScreenBounds: true))
                    .openOnTap(false)
                    .closeOnTap(false)
                    .closeOnTapOutside(true)
                    .background(.blur(radius: 4))
            }
    }
}
