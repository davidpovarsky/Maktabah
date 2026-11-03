//
//  ExpandableLibrarySearchCoordinator.swift
//  Maktabah
//
//  Downstream-owned state machine for the Safari-style expanding center library search capsule (Plan B).
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation
import Observation

/// Represents the expansion lifecycle of the center library search capsule in the viewer toolbar.
public enum ExpandableSearchPhase: String, Codable, Equatable, Sendable {
    case collapsed
    case expanding
    case expanded
    case dismissing

    public var isExpandedOrExpanding: Bool {
        self == .expanding || self == .expanded
    }
}

/// Lightweight book suggestion item surfaced inside the expanded command-palette overlay.
public struct LibraryQuickSearchItem: Identifiable, Equatable, Sendable {
    public let id: Int
    public let title: String
    public let categoryName: String
    public let info: String

    public init(id: Int, title: String, categoryName: String, info: String = "") {
        self.id = id
        self.title = title
        self.categoryName = categoryName
        self.info = info
    }
}

/// Coordinates the expanding center library search field in the viewer toolbar and binds directly
/// to `LibraryViewModel.searchQuery`.
@MainActor
@Observable
public final class ExpandableLibrarySearchCoordinator {
    public private(set) var phase: ExpandableSearchPhase = .collapsed
    public var searchText: String = ""
    public var isFieldFocused: Bool = false
    public var highlightedItemIndex: Int = 0

    /// Compact width when collapsed in the center toolbar group.
    public static let collapsedCapsuleWidth: CGFloat = 240
    /// Expanded width when active in the center toolbar group.
    public static let expandedCapsuleWidth: CGFloat = 440

    public init(initialQuery: String = "") {
        self.searchText = initialQuery
    }

    public var targetCapsuleWidth: CGFloat {
        phase.isExpandedOrExpanding ? Self.expandedCapsuleWidth : Self.collapsedCapsuleWidth
    }

    // MARK: - State Transitions

    /// Transitions the search capsule from `.collapsed` to `.expanded` and requests keyboard focus.
    public func expand() {
        guard !phase.isExpandedOrExpanding else {
            isFieldFocused = true
            return
        }
        phase = .expanding
        isFieldFocused = true
        highlightedItemIndex = 0
        phase = .expanded
    }

    /// Updates the query and synchronizes it with `LibraryViewModel` when provided.
    public func updateQuery(_ query: String, syncingTo libraryViewModel: LibraryViewModel? = nil) {
        searchText = query
        highlightedItemIndex = 0
        if !query.isEmpty, phase == .collapsed {
            phase = .expanded
        }
        if let libraryViewModel, libraryViewModel.searchQuery != query {
            libraryViewModel.performSearch(query)
        }
    }

    /// Clears the current query without collapsing if the user is still focused, or collapses if already empty.
    public func clearOrDismiss(syncingTo libraryViewModel: LibraryViewModel? = nil) {
        if !searchText.isEmpty {
            updateQuery("", syncingTo: libraryViewModel)
        } else {
            dismiss(syncingTo: libraryViewModel, clearQuery: false)
        }
    }

    /// Collapses the capsule and resigns keyboard focus (e.g., on Escape, Return, or outside tap).
    public func dismiss(syncingTo libraryViewModel: LibraryViewModel? = nil, clearQuery: Bool = false) {
        phase = .dismissing
        isFieldFocused = false
        if clearQuery {
            searchText = ""
            libraryViewModel?.performSearch("")
        }
        phase = .collapsed
    }

    // MARK: - Results Extraction from LibraryViewModel

    /// Extracts matching books from `LibraryViewModel.displayedCategories` for quick inline selection.
    public func matchingBooks(in libraryViewModel: LibraryViewModel, limit: Int = 25) -> [ (category: CategoryData, book: BooksData) ] {
        var results: [(category: CategoryData, book: BooksData)] = []
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        func collect(from category: CategoryData) {
            guard results.count < limit else { return }
            for child in category.children {
                guard results.count < limit else { return }
                if let book = child as? BooksData {
                    if query.isEmpty || book.title.localizedCaseInsensitiveContains(query) || category.name.localizedCaseInsensitiveContains(query) {
                        results.append((category, book))
                    }
                } else if let subcategory = child as? CategoryData {
                    collect(from: subcategory)
                }
            }
        }

        let categories = libraryViewModel.displayedCategories.isEmpty
            ? libraryViewModel.rootCategories
            : libraryViewModel.displayedCategories

        for category in categories {
            collect(from: category)
            if results.count >= limit { break }
        }
        return results
    }
}
