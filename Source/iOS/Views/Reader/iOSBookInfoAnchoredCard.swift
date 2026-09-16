//
//  iOSBookInfoAnchoredCard.swift
//  Maktabah-iOS
//

import SwiftUI
import UIKit

/// Card view for book metadata presentation in native popover
struct iOSBookInfoCardView: View {
    let book: BooksData

    @Environment(\.dismiss) private var dismiss

    @State private var selectedSegment: BookInfoSegment = .bithoqoh
    @State private var fullBookInfo: BooksData?
    @State private var author: Muallif?

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
                    dismiss()
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
        .frame(
            idealWidth: 430,
            maxWidth: 430,
            idealHeight: 430,
            maxHeight: 430
        )
        .presentationBackground(.regularMaterial)
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
