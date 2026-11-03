//
//  ReaderLibraryCommandPaletteHost.swift
//  Maktabah
//
//  Downstream-owned Safari-style expanding glass search capsule and inline library command palette shell (Plan B).
//

#if os(iOS)
import SwiftUI

/// Center toolbar search capsule that expands smoothly on tap/focus using `GelatinMotionOnly`
/// and drives `LibraryViewModel.searchQuery` directly while offering quick inline book selection.
struct ReaderLibraryCommandPaletteHost: View {
    @Environment(iOSNavigationManager.self) private var navigationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Bindable var coordinator: ExpandableLibrarySearchCoordinator
    var libraryViewModel: LibraryViewModel
    var sidebarCoordinator: ReaderSidebarStateCoordinator?
    var onSelectBook: ((BooksData) -> Void)?

    @FocusState private var textFieldFocused: Bool
    @State private var isPressed: Bool = false

    var body: some View {
        let isExpanded = coordinator.phase.isExpandedOrExpanding

        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isExpanded ? Color.accentColor : Color.secondary)

            if isExpanded {
                TextField("חיפוש ספר או מסכת בספרייה...", text: Binding(
                    get: { coordinator.searchText },
                    set: { newValue in
                        coordinator.updateQuery(newValue, syncingTo: libraryViewModel)
                    }
                ))
                .textFieldStyle(.plain)
                .font(.subheadline)
                .focused($textFieldFocused)
                .submitLabel(.search)
                .onSubmit {
                    openFirstMatchingBookIfAvailable()
                }
                .onKeyPress(.escape) {
                    withAnimation(springAnimation) {
                        coordinator.dismiss(syncingTo: libraryViewModel, clearQuery: false)
                    }
                    return .handled
                }

                if !coordinator.searchText.isEmpty {
                    Button {
                        withAnimation(springAnimation) {
                            coordinator.updateQuery("", syncingTo: libraryViewModel)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 28, minHeight: 28)
                    .accessibilityLabel("נקה חיפוש ספרייה")
                }

                Button {
                    withAnimation(springAnimation) {
                        coordinator.dismiss(syncingTo: libraryViewModel, clearQuery: false)
                    }
                } label: {
                    Text("סיום")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.quaternary.opacity(0.6), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("סגור חיפוש ספרייה")
            } else {
                Button {
                    withAnimation(springAnimation) {
                        coordinator.expand()
                        sidebarCoordinator?.showLibrary()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(coordinator.searchText.isEmpty ? "חיפוש בספרייה..." : coordinator.searchText)
                            .font(.subheadline)
                            .foregroundStyle(coordinator.searchText.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text("⌘K")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("חיפוש ספרים בספרייה")
            }
        }
        .padding(.horizontal, 12)
        .frame(width: coordinator.targetCapsuleWidth, height: 36)
        .background(
            Capsule(style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(
                            isExpanded ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.1),
                            lineWidth: isExpanded ? 1.2 : 0.7
                        )
                )
        )
        .gelatinMotionOnly(isPressed: isPressed)
        .popover(
            isPresented: Binding(
                get: { isExpanded && !coordinator.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                set: { presented in
                    if !presented {
                        coordinator.dismiss(syncingTo: libraryViewModel, clearQuery: false)
                    }
                }
            ),
            arrowEdge: .top
        ) {
            quickResultsPopoverContent
                .frame(width: 420, height: 320)
        }
        .onChange(of: coordinator.isFieldFocused) { _, focused in
            textFieldFocused = focused
        }
        .onChange(of: textFieldFocused) { _, focused in
            if focused && !coordinator.phase.isExpandedOrExpanding {
                withAnimation(springAnimation) {
                    coordinator.expand()
                }
            }
        }
        .onChange(of: libraryViewModel.searchQuery) { _, externalQuery in
            if coordinator.searchText != externalQuery {
                coordinator.searchText = externalQuery
            }
        }
    }

    // MARK: - Quick Results Popover

    @ViewBuilder
    private var quickResultsPopoverContent: some View {
        let matches = coordinator.matchingBooks(in: libraryViewModel, limit: 25)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("תוצאות מהירות בספרייה", systemImage: "books.vertical")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("הצג בעץ הספרייה") {
                    sidebarCoordinator?.showLibrary()
                    coordinator.dismiss(syncingTo: libraryViewModel, clearQuery: false)
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if matches.isEmpty {
                ContentUnavailableView.search(text: coordinator.searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(matches.enumerated()), id: \.element.book.id) { _, item in
                            Button {
                                selectBook(item.book)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "book.closed")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.accentColor)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.book.title)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text(item.category.name)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "arrow.up.left")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(6)
                }
            }
        }
    }

    private func openFirstMatchingBookIfAvailable() {
        let matches = coordinator.matchingBooks(in: libraryViewModel, limit: 1)
        if let first = matches.first {
            selectBook(first.book)
        } else {
            sidebarCoordinator?.showLibrary()
        }
    }

    private func selectBook(_ book: BooksData) {
        if let onSelectBook {
            onSelectBook(book)
        } else {
            libraryViewModel.selectBook(book, using: navigationManager)
        }
        withAnimation(springAnimation) {
            coordinator.dismiss(syncingTo: libraryViewModel, clearQuery: false)
        }
    }

    private var springAnimation: Animation {
        reduceMotion
            ? .linear(duration: 0.01)
            : .interpolatingSpring(stiffness: 320, damping: 26)
    }
}
#endif
