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
            // Check ordered navigation items if available
            if let currentLocator, !navigationItems.isEmpty {
                if let currentIndex = navigationItems.firstIndex(where: { $0.locator == currentLocator }),
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
            // Check ordered navigation items if available
            if let currentLocator, !navigationItems.isEmpty {
                if let currentIndex = navigationItems.firstIndex(where: { $0.locator == currentLocator }),
                   currentIndex > 0 {
                    return .loadBackendLocator(navigationItems[currentIndex - 1].locator, scrollTarget: .bottom)
                }
            }
            // Start of book boundary: safe no-op. Do NOT fall back to legacy or wrap around.
            return .noOpBoundaryReached
        }
    }
}
