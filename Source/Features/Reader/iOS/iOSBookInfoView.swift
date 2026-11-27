//
//  iOSBookInfoView.swift
//  Maktabah-iOS
//
//  Created by Ghoys Mawahib on 04/05/26.
//

import SwiftUI

enum BookInfoSegment: Int, CaseIterable, Identifiable {
    case bithoqoh = 0
    case author = 1
    case info = 2

    var id: Int { rawValue }

    var title: String {
        return switch self {
        case .bithoqoh: .init(localized: "بطاقة الكتاب")
        case .author: .init(localized: "عن المصنف")
        case .info:  .init(localized: "عن الكتاب")
        }
    }
}

struct iOSBookInfoView: View {
    let book: BooksData
    @State private var workMetadata: LibraryWorkMetadata?
    @State private var unifiedSegment: UnifiedBookInfoSegment = .details
    @State private var selectedSegment: BookInfoSegment = .bithoqoh
    @State private var fullBookInfo: BooksData?
    @State private var author: Muallif?
    @State private var bookInfoTask: Task<Void, Never>?
    @State private var bookInfoLoadID: UUID?
    @Environment(\.dismiss) private var dismiss

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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isUnified {
                    Picker(String(localized: .Library.bookInfo), selection: $unifiedSegment) {
                        ForEach(UnifiedBookInfoSegment.allCases) { segment in
                            Text(segment.title).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                } else {
                    Picker(String(localized: .Library.bookInfo), selection: $selectedSegment) {
                        ForEach(BookInfoSegment.allCases) { segment in
                            Text(segment.title).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }

                if currentText.isEmpty {
                    VStack {
                        Spacer()
                        Group {
                            if isUnified {
                                Text("No additional information")
                            } else {
                                Text(.noMetadata)
                            }
                        }
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ReadOnlyTextView(
                        text: currentText,
                        font: isUnified ? .systemFont(ofSize: 17) : .arabicFont(size: 22)
                    )
                }
            }
            .navigationTitle(isUnified
                ? workMetadata.map { LibraryPresentationPolicy.workTitle(title: $0.title, heTitle: $0.heTitle) } ?? book.book
                : String(localized: .Library.bookInfo))
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadBookInfo()
            }
            .onChange(of: ObjectIdentifier(book)) { _, _ in
                loadBookInfo()
            }
            .onDisappear {
                cancelBookInfoLoad()
            }
        }
        .themeTint()
    }

    private func cancelBookInfoLoad() {
        // Retire this exact presentation before cancelling its original task.
        bookInfoLoadID = nil
        let previous = bookInfoTask
        bookInfoTask = nil
        previous?.cancel()
    }

    private func loadBookInfo() {
        cancelBookInfoLoad()
        let loadID = UUID()
        bookInfoLoadID = loadID
        let sourceBook = book
        let sourceLocator = book.backendLocator
        let sourceBackend = BackendCoordinator.shared.activeBackendID
        let sourceGeneration = BackendCoordinator.shared.generation
        let workKey = book.backendLocator?.workKey ?? "book:\(book.id)"
        let isCurrent: @MainActor () -> Bool = {
            bookInfoLoadID == loadID && !Task.isCancelled
                && book === sourceBook && book.backendLocator == sourceLocator
                && BackendCoordinator.shared.activeBackendID == sourceBackend
                && BackendCoordinator.shared.generation == sourceGeneration
        }
        bookInfoTask = Task {
            guard isCurrent() else { return }
            if let meta = try? await BackendCoordinator.shared.workMetadata(for: workKey) {
                await MainActor.run {
                    guard isCurrent() else { return }
                    self.workMetadata = meta
                }
                return
            }
            // The original provider may finish with a stale/cancelled error.
            // Such a result cannot fall through into another backend's DB.
            guard isCurrent() else { return }
            if book.backendLocator == nil {
                await MainActor.run {
                    guard isCurrent() else { return }
                    let dm = LibraryDataManager.shared
                    let loadedAuthor = DatabaseManager.shared.getAuthor(book.muallif)
                    guard isCurrent() else { return }
                    author = loadedAuthor
                    guard isCurrent() else { return }
                    let loadedBook = dm.getBook([book.id]).first ?? book
                    guard isCurrent() else { return }
                    fullBookInfo = loadedBook
                    guard isCurrent() else { return }

                    dm.loadBookInfo(book.id) {
                        guard isCurrent() else { return nil }
                        if let updatedBook = dm.getBook([book.id]).first {
                            guard isCurrent() else { return nil }
                            fullBookInfo = updatedBook
                        }
                        return ()
                    }
                }
            }
        }
    }
}

/// Lightweight read-only text view using TextKit for zero-lag text rendering
private struct ReadOnlyTextView: UIViewRepresentable {
    let text: String
    var font: UIFont = .systemFont(ofSize: 17)

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(
            top: 12, left: 16, bottom: 16, right: 16
        )
        textView.textAlignment = .natural
        textView.adjustsFontForContentSizeCategory = true
        textView.font = UIFontMetrics(forTextStyle: .body).scaledFont(
            for: font, compatibleWith: textView.traitCollection
        )
        textView.textColor = .label
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // The original text view keeps its scroll position when only the
        // font/category changes. UIKit scales the same original base font.
        uiView.font = UIFontMetrics(forTextStyle: .body).scaledFont(
            for: font, compatibleWith: uiView.traitCollection
        )
        uiView.textAlignment = .natural
        if uiView.text != text {
            uiView.text = text
            uiView.setContentOffset(.zero, animated: false)
        }
    }
}
