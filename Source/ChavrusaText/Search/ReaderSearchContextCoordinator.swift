//
//  ReaderSearchContextCoordinator.swift
//  Maktabah
//
//  Downstream-owned coordinator managing search highlight persistence and toolbar Clear 'X' visibility.
//

import Foundation

struct ReaderSearchContext: Equatable, Sendable {
    var query: String
    var highlightTerms: [String]?
    var focusLocator: TextLocator?
    var selectedSegmentLocator: TextLocator?
    var searchMode: LibrarySearchMode?
    var nearDistance: Int
    var eventID: UUID
    var isSearchOrigin: Bool

    init(
        query: String = "",
        highlightTerms: [String]? = nil,
        focusLocator: TextLocator? = nil,
        selectedSegmentLocator: TextLocator? = nil,
        searchMode: LibrarySearchMode? = nil,
        nearDistance: Int = 10,
        eventID: UUID = UUID(),
        isSearchOrigin: Bool = true
    ) {
        self.query = query
        self.highlightTerms = highlightTerms
        self.focusLocator = focusLocator
        self.selectedSegmentLocator = selectedSegmentLocator
        self.searchMode = searchMode
        self.nearDistance = nearDistance
        self.eventID = eventID
        self.isSearchOrigin = isSearchOrigin
    }
}

enum ReaderSearchContextCoordinator: Sendable {
    /// Determines whether the bottom toolbar Clear 'X' button should be visible.
    /// Returns true ONLY if there is active search provenance (query text or highlight terms).
    /// Ordinary user text selection, linked-source focus, and persistent annotations do NOT trigger the search clear button.
    static func hasActiveSearchHighlight(
        searchText: String,
        highlightTerms: [String]?,
        focusLocator: TextLocator?,
        selectedSegmentLocator: TextLocator?,
        isSearchOrigin: Bool = true
    ) -> Bool {
        guard isSearchOrigin else {
            return false // Ordinary linked-commentary or navigation focus with isSearchOrigin == false NEVER triggers search highlight
        }
        let hasQuery = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasTerms = !(highlightTerms?.isEmpty ?? true)

        // Active search highlight requires real search provenance (query text or highlight terms).
        // A focusLocator or selectedSegmentLocator alone represents ordinary navigation or linked-source focus.
        if hasQuery || hasTerms {
            return true
        }
        return false
    }

    /// Evaluates whether a scroll event should dismiss search highlights.
    /// Strict rule: Programmatic scrolls, layout adjustments, and rubber banding NEVER dismiss highlights.
    /// Only deliberate manual user dragging beyond the threshold may dismiss.
    static func shouldClearAfterScroll(
        startOffsetY: Double?,
        currentOffsetY: Double,
        viewportHeight: Double,
        isManualUserDrag: Bool,
        hasActiveHighlight: Bool
    ) -> Bool {
        guard hasActiveHighlight, isManualUserDrag, let startOffsetY else {
            return false
        }
        let delta = abs(currentOffsetY - startOffsetY)
        let threshold = max(96.0, viewportHeight * 0.20)
        return delta >= threshold
    }

    /// Clears transient search query, terms, and focus selections without modifying unrelated user selections or annotations.
    static func clearTransientSearchState(
        searchText: inout String,
        highlightTerms: inout [String]?,
        focusLocator: inout TextLocator?,
        selectedSegmentLocator: inout TextLocator?,
        searchMode: inout LibrarySearchMode?
    ) {
        searchText = ""
        highlightTerms = nil
        if let focus = focusLocator, selectedSegmentLocator == focus {
            selectedSegmentLocator = nil
        }
        focusLocator = nil
        searchMode = nil
    }
}
