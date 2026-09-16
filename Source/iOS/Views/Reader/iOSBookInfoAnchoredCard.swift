//
//  iOSBookInfoAnchoredCard.swift
//  Maktabah-iOS
//

import SwiftUI
import UIKit
import AnchoredPopup

/// Floating anchored inspection card for book metadata
struct iOSBookInfoCardView: View {
    let book: BooksData
    var popupId: String? = nil

    @Environment(\.anchoredPopupDismiss) private var dismissPopup

    @State private var selectedSegment: BookInfoSegment = .bithoqoh
    @State private var fullBookInfo: BooksData?
    @State private var author: Muallif?

    private var availableWindowSize: CGSize {
        let bounds = currentWindowBounds
        if bounds.width > 0 && bounds.height > 0 {
            return bounds.size
        }
        return CGSize(width: 430, height: 430)
    }

    private var cardWidth: CGFloat {
        let availableWidth = availableWindowSize.width
        return min(430, max(260, availableWidth - 32))
    }

    private var cardHeight: CGFloat {
        let availableHeight = availableWindowSize.height
        let insets = currentSafeAreaInsets
        let verticalMargins = max(64, insets.top + insets.bottom + 24)
        return min(430, max(280, availableHeight - verticalMargins))
    }

    private var currentWindowBounds: CGRect {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first

        if let scene = activeScene {
            if let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
                return window.bounds
            }
            let bounds = scene.coordinateSpace.bounds
            if bounds.width > 0 && bounds.height > 0 {
                return bounds
            }
        }
        return .zero
    }

    private var currentSafeAreaInsets: UIEdgeInsets {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first

        if let scene = activeScene,
           let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
            return window.safeAreaInsets
        }
        return .zero
    }

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
            // Header: Title, Author and Material Circular Close button
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(book.book)
                        .font(.title2.bold())
                        .lineLimit(1)
                        .environment(\.layoutDirection, .rightToLeft)

                    Text(author?.namaLengkap.isEmpty == false ? author!.namaLengkap : String(localized: "Book Information"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .environment(\.layoutDirection, .rightToLeft)
                }

                Spacer(minLength: 8)

                Button {
                    dismissPopup?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 36, height: 36)
                        .background(
                            .thinMaterial,
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close"))
            }
            .padding(22)

            Divider()

            // Segmented Picker
            Picker("Book Info", selection: $selectedSegment) {
                ForEach(BookInfoSegment.allCases) { segment in
                    Text(segment.title).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            // Content: fills remaining height
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
        .frame(width: cardWidth, height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    Color.primary.opacity(0.08),
                    lineWidth: 1
                )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 28,
                style: .continuous
            )
        )
        .shadow(
            color: .black.opacity(0.18),
            radius: 30,
            y: 14
        )
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
            top: 8, left: 18, bottom: 18, right: 18
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
        Button {
            AnchoredPopup.launchGrowingAnimation(
                id: "book_info_\(book.id)"
            )
        } label: {
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
                iOSBookInfoCardView(
                    book: book,
                    popupId: popupId
                )
            } customize: {
                $0
                    .displayMode(.window)
                    .position(.auto)
                    .animation(
                        .spring(
                            response: 0.48,
                            dampingFraction: 0.78
                        )
                    )
                    .openOnTap(false)
                    .closeOnTap(false)
                    .closeOnTapOutside(true)
                    .background(.blur(radius: 8))
            }
    }
}
