//
//  iOSBookInfoAnchoredCard.swift
//  Maktabah-iOS
//

import SwiftUI
import UIKit

enum UnifiedBookInfoSegment: Int, CaseIterable, Identifiable {
    case details = 0
    case description = 1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .details: "פרטים"
        case .description: "תיאור"
        }
    }
}

/// Card view for book metadata presentation in native popover
struct iOSBookInfoCardView: View {
    let book: BooksData

    @Environment(\.dismiss) private var dismiss

    @State private var workMetadata: LibraryWorkMetadata?
    @State private var unifiedSegment: UnifiedBookInfoSegment = .details
    @State private var selectedSegment: BookInfoSegment = .bithoqoh
    @State private var fullBookInfo: BooksData?
    @State private var author: Muallif?

    private var isUnified: Bool {
        workMetadata != nil || book.backendLocator != nil
    }

    private var currentText: String {
        if isUnified {
            guard let meta = workMetadata else { return "" }
            switch unifiedSegment {
            case .details:
                return meta.factualFields.map { "\($0.label): \($0.value)" }.joined(separator: "\n\n")
            case .description:
                return meta.description ?? ""
            }
        }
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

    private var displayTitle: String {
        workMetadata?.heTitle ?? workMetadata?.title ?? book.book
    }

    private var displaySubtitle: String {
        if let authors = workMetadata?.authors, !authors.isEmpty {
            return authors.joined(separator: ", ")
        }
        if let authorName = author?.namaLengkap, !authorName.isEmpty {
            return authorName
        }
        return isUnified ? "מידע על הספר" : String(localized: "Book Information")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header: Title, Author and Material Circular Close button
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayTitle)
                        .font(.title2.bold())
                        .lineLimit(1)
                        .environment(\.layoutDirection, .rightToLeft)

                    Text(displaySubtitle)
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
            if isUnified {
                Picker("Book Info", selection: $unifiedSegment) {
                    ForEach(UnifiedBookInfoSegment.allCases) { segment in
                        Text(segment.title).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            } else {
                Picker("Book Info", selection: $selectedSegment) {
                    ForEach(BookInfoSegment.allCases) { segment in
                        Text(segment.title).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }

            // Content: fills remaining height
            if currentText.isEmpty {
                VStack {
                    Spacer()
                    Text(isUnified ? "אין מידע נוסף" : .noMetadata)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                AnchoredReadOnlyTextView(
                    text: currentText,
                    font: isUnified ? .systemFont(ofSize: 17) : .arabicFont(size: 20)
                )
            }
        }
        .frame(
            idealWidth: 430,
            maxWidth: 430,
            idealHeight: 430,
            maxHeight: 430
        )
        .presentationBackground(Color.appBackground)
        .onAppear {
            loadBookInfo()
        }
    }

    private func loadBookInfo() {
        let workKey = book.backendLocator?.workKey ?? "book:\(book.id)"
        Task {
            if let meta = try? await BackendCoordinator.shared.workMetadata(for: workKey) {
                await MainActor.run {
                    self.workMetadata = meta
                }
                return
            }
            if book.backendLocator == nil {
                await MainActor.run {
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
        }
    }
}

/// Lightweight read-only text view using TextKit for zero-lag text rendering
private struct AnchoredReadOnlyTextView: UIViewRepresentable {
    let text: String
    var font: UIFont = .systemFont(ofSize: 17)

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
