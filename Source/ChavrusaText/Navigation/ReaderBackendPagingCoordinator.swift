//
//  ReaderBackendPagingCoordinator.swift
//  Maktabah
//
//  Downstream-owned paging coordinator that ensures backend-aware navigation
//  for Sefaria and Otzaria works reliably on both pull-to-navigate and bottom toolbar buttons.
//

import Foundation

enum ReaderPagingDirection: Sendable {
    case next
    case previous
}

enum ReaderPagingAction: Equatable, Sendable {
    case loadBackendLocator(TextLocator, scrollTarget: ReaderScrollTarget)
    case performLegacyFallback
    case noOpBoundaryReached
}

enum ReaderScrollTarget: Equatable, Sendable {
    case top
    case bottom
}

enum ReaderBackendPagingCoordinator: Sendable {
    /// Finds the index of the active reading unit within the ordered navigation items.
    /// Handles exact equality, Sefaria hierarchical refs, and Otzaria line anchors.
    static func findCurrentIndex(
        currentLocator: TextLocator,
        in navigationItems: [LibraryNavigationItem]
    ) -> Int? {
        guard !navigationItems.isEmpty else { return nil }

        // 1. Exact locator match
        if let exact = navigationItems.firstIndex(where: { $0.locator == currentLocator }) {
            return exact
        }

        switch currentLocator.backend {
        case .sefaria:
            // 2. Sefaria canonical ref match
            guard case .canonicalRef(let currentRef) = currentLocator.position else { return nil }
            return navigationItems.firstIndex(where: { item in
                guard item.locator.backend == .sefaria,
                      item.locator.workKey == currentLocator.workKey,
                      case .canonicalRef(let itemRef) = item.locator.position else {
                    return false
                }
                return SefariaRef.sectionMatches(currentRef, itemRef) ||
                       SefariaRef.sectionAncestors(of: currentRef).contains(SefariaRef.canonicalInput(itemRef))
            })

        case .otzaria:
            // 3. Otzaria line anchor match (closest heading at or before current line)
            guard case .legacyLine(let currentLine) = currentLocator.position else { return nil }
            var bestIdx: Int?
            var bestLine = -1
            for (idx, item) in navigationItems.enumerated() {
                guard item.locator.backend == .otzaria,
                      item.locator.workKey == currentLocator.workKey,
                      case .legacyLine(let itemLine) = item.locator.position else {
                    continue
                }
                if itemLine <= currentLine && itemLine > bestLine {
                    bestLine = itemLine
                    bestIdx = idx
                }
            }
            return bestIdx
        }
    }

    /// Determines the appropriate paging action for next/previous navigation.
    static func resolvePagingAction(
        direction: ReaderPagingDirection,
        isBackendBook: Bool,
        currentLocator: TextLocator?,
        backendSectionNext: TextLocator?,
        backendSectionPrevious: TextLocator?,
        navigationItems: [LibraryNavigationItem]
    ) -> ReaderPagingAction {
        guard isBackendBook else {
            return .performLegacyFallback
        }

        switch direction {
        case .next:
            if let nextLocator = backendSectionNext {
                return .loadBackendLocator(nextLocator, scrollTarget: .top)
            }
            if let currentLocator, !navigationItems.isEmpty {
                if let currentIndex = findCurrentIndex(currentLocator: currentLocator, in: navigationItems),
                   currentIndex + 1 < navigationItems.count {
                    return .loadBackendLocator(navigationItems[currentIndex + 1].locator, scrollTarget: .top)
                }
            }
            // End of book boundary: safe no-op. Do NOT fall back to legacy or jump to beginning.
            return .noOpBoundaryReached

        case .previous:
            if let prevLocator = backendSectionPrevious {
                return .loadBackendLocator(prevLocator, scrollTarget: .bottom)
            }
            if let currentLocator, !navigationItems.isEmpty {
                if let currentIndex = findCurrentIndex(currentLocator: currentLocator, in: navigationItems),
                   currentIndex > 0 {
                    return .loadBackendLocator(navigationItems[currentIndex - 1].locator, scrollTarget: .bottom)
                }
            }
            // Start of book boundary: safe no-op. Do NOT fall back to legacy or wrap around.
            return .noOpBoundaryReached
        }
    }
}
