//
//  ReaderSidebarStateCoordinator.swift
//  Maktabah
//
//  Downstream-owned state coordinator for the Craft-style 2-screen sidebar pager (Plan A)
//  and width-driven Inspector presentation policy (Plan D).
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation
import Observation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Represents the two pages of the Craft-style reader sidebar on iPad.
enum ReaderSidebarPage: String, CaseIterable, Identifiable, Codable, Sendable {
    case library
    case toc

    var id: String { rawValue }

    var hebrewTitle: String {
        switch self {
        case .library: return "ספרייה"
        case .toc: return "תוכן עניינים"
        }
    }

    var englishTitle: String {
        switch self {
        case .library: return "Library"
        case .toc: return "Table of Contents"
        }
    }

    var systemImage: String {
        switch self {
        case .library: return "books.vertical"
        case .toc: return "list.bullet.indent"
        }
    }

    func localizedTitle(prefersHebrew: Bool = true) -> String {
        prefersHebrew ? hebrewTitle : englishTitle
    }
}

/// Per-window coordinator managing the 2-column `NavigationSplitView` sidebar visibility,
/// active sidebar page (`.library` vs `.toc`), and available detail width for Plan D Inspector layout.
@MainActor
@Observable
final class ReaderSidebarStateCoordinator {
    /// Minimum detail reader width required to present the Inspector as a side-by-side trailing panel
    /// rather than a compact bottom `FloatingPanel`.
    static let minimumWideInspectorReaderWidth: CGFloat = 700

    var selectedPage: ReaderSidebarPage
    var sidebarVisible: Bool
    var availableReaderWidth: CGFloat
    var hasActiveReaderTab: Bool

    #if os(iOS)
    /// Two-way adapter for legacy 3-column `NavigationSplitView` visibility when `sidebarPagerEnabled == false`.
    /// When set by `iPadLayout`, actions like `showTOC()`, `showLibrary()`, and `closeSidebar()`
    /// directly drive `columnVisibility` and `preferredCompactColumn`.
    var onUpdateLegacySplitVisibility: ((NavigationSplitViewVisibility, NavigationSplitViewColumn?) -> Void)?
    #endif

    init(
        selectedPage: ReaderSidebarPage = .library,
        sidebarVisible: Bool = true,
        availableReaderWidth: CGFloat = 1024,
        hasActiveReaderTab: Bool = false
    ) {
        self.selectedPage = selectedPage
        self.sidebarVisible = sidebarVisible
        self.availableReaderWidth = availableReaderWidth
        self.hasActiveReaderTab = hasActiveReaderTab
    }

    // MARK: - Sidebar Page & Visibility Actions

    /// Opens the sidebar (if hidden) and switches directly to the Table of Contents page.
    func showTOC() {
        selectedPage = .toc
        sidebarVisible = true
        #if os(iOS)
        onUpdateLegacySplitVisibility?(.doubleColumn, .sidebar)
        #endif
    }

    /// Opens the sidebar (if hidden) and switches directly to the Library tree page.
    func showLibrary() {
        selectedPage = .library
        sidebarVisible = true
        #if os(iOS)
        onUpdateLegacySplitVisibility?(.all, .sidebar)
        #endif
    }

    /// Switches to the specified page without collapsing the sidebar.
    func selectPage(_ page: ReaderSidebarPage) {
        selectedPage = page
        if !sidebarVisible {
            sidebarVisible = true
        }
        #if os(iOS)
        let targetVisibility: NavigationSplitViewVisibility = (page == .toc) ? .doubleColumn : .all
        onUpdateLegacySplitVisibility?(targetVisibility, .sidebar)
        #endif
    }

    /// Toggles sidebar visibility while preserving `selectedPage`.
    func toggleSidebar() {
        sidebarVisible.toggle()
        #if os(iOS)
        if sidebarVisible {
            let targetVisibility: NavigationSplitViewVisibility = (selectedPage == .toc) ? .doubleColumn : .all
            onUpdateLegacySplitVisibility?(targetVisibility, .sidebar)
        } else {
            onUpdateLegacySplitVisibility?(.detailOnly, .detail)
        }
        #endif
    }

    /// Collapses the sidebar while preserving `selectedPage` for the next open.
    func closeSidebar() {
        sidebarVisible = false
        #if os(iOS)
        onUpdateLegacySplitVisibility?(.detailOnly, .detail)
        #endif
    }

    /// Updates active reader tab presence; if all tabs are closed while on `.toc`, keeps `.toc`
    /// with an empty-state placeholder or allows user to swipe back to `.library`.
    func updateActiveReaderTabPresence(_ hasActiveTab: Bool) {
        hasActiveReaderTab = hasActiveTab
    }

    // MARK: - Plan D Width-Driven Inspector Policy

    /// Determines whether the detail reader workspace has sufficient width to host the side-by-side
    /// `wideWorkspace` Inspector panel (`panelResizeHandle` + `inspectorPanel`) instead of the compact
    /// `FloatingPanel` bottom sheet.
    /// Does NOT depend on legacy 3-column `NavigationSplitViewVisibility.all`.
    func prefersWideInspectorPanel(horizontalSizeClassIsCompact: Bool = false) -> Bool {
        Self.prefersWideInspectorPanel(
            forReaderWidth: availableReaderWidth,
            horizontalSizeClassIsCompact: horizontalSizeClassIsCompact
        )
    }

    static func prefersWideInspectorPanel(
        forReaderWidth width: CGFloat,
        horizontalSizeClassIsCompact: Bool = false
    ) -> Bool {
        guard !horizontalSizeClassIsCompact else { return false }
        return width >= minimumWideInspectorReaderWidth
    }

    #if os(iOS)
    /// Maps `sidebarVisible` to/from SwiftUI's 2-column `NavigationSplitViewVisibility`.
    var splitViewVisibilityBinding: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { [weak self] in
                guard let self else { return .all }
                return self.sidebarVisible ? .all : .detailOnly
            },
            set: { [weak self] newValue in
                guard let self else { return }
                self.sidebarVisible = (newValue != .detailOnly)
            }
        )
    }
    #endif
}
