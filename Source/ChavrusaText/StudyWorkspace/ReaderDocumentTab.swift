//
//  ReaderDocumentTab.swift
//  Maktabah
//
//  Downstream-owned model for an independent document tab instance inside a StudyTabGroup.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

/// Represents an independent document tab in the ChavrusaText study workspace.
/// Each tab has its own unique `UUID` identity and reading state—even when the same book
/// is opened across different tab groups or multiple times within the same group.
public struct ReaderDocumentTab: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var backend: BackendID
    public var bookId: Int
    public var bookTitle: String?
    public var workKey: String?
    public var sectionLocator: TextLocator?
    public var focusLocator: TextLocator?
    public var contentId: Int?
    public var page: Int?
    public var part: Int?
    public var scrollPosition: CGPoint?
    public var selectedRange: NSRange?
    public var expandedNodeIDs: [Int]?
    public var sidebarScrollPosition: CGPoint?
    public var isSidebarCollapsed: Bool?
    public var searchText: String?
    public var searchModeRaw: Int?
    public var nearDistance: Int?
    public var highlightTerms: [String]?
    public var isDormantUnavailable: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        backend: BackendID = .otzaria,
        bookId: Int,
        bookTitle: String? = nil,
        workKey: String? = nil,
        sectionLocator: TextLocator? = nil,
        focusLocator: TextLocator? = nil,
        contentId: Int? = nil,
        page: Int? = nil,
        part: Int? = nil,
        scrollPosition: CGPoint? = nil,
        selectedRange: NSRange? = nil,
        expandedNodeIDs: [Int]? = nil,
        sidebarScrollPosition: CGPoint? = nil,
        isSidebarCollapsed: Bool? = nil,
        searchText: String? = nil,
        searchModeRaw: Int? = nil,
        nearDistance: Int? = nil,
        highlightTerms: [String]? = nil,
        isDormantUnavailable: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.backend = backend
        self.bookId = bookId
        self.bookTitle = bookTitle
        self.workKey = workKey ?? sectionLocator?.workKey ?? focusLocator?.workKey
        self.sectionLocator = sectionLocator
        self.focusLocator = focusLocator
        self.contentId = contentId
        self.page = page
        self.part = part
        self.scrollPosition = scrollPosition
        self.selectedRange = selectedRange
        self.expandedNodeIDs = expandedNodeIDs
        self.sidebarScrollPosition = sidebarScrollPosition
        self.isSidebarCollapsed = isSidebarCollapsed
        self.searchText = searchText
        self.searchModeRaw = searchModeRaw
        self.nearDistance = nearDistance
        self.highlightTerms = highlightTerms
        self.isDormantUnavailable = isDormantUnavailable
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Creates a `ReaderDocumentTab` from a legacy `iOSReaderTabSession`.
    init(from sessionTab: iOSReaderTabSession, fallbackBackend: BackendID = .otzaria, now: Date = Date()) {
        let resolvedBackend = sessionTab.locator?.backend
            ?? sessionTab.backendLocator?.backend
            ?? fallbackBackend
        let resolvedWorkKey = sessionTab.locator?.workKey
            ?? sessionTab.backendLocator?.workKey
            ?? (resolvedBackend == .otzaria ? "book:\(sessionTab.bookId)" : nil)

        self.init(
            id: sessionTab.id,
            backend: resolvedBackend,
            bookId: sessionTab.bookId,
            bookTitle: sessionTab.bookTitle,
            workKey: resolvedWorkKey,
            sectionLocator: sessionTab.locator ?? sessionTab.backendLocator,
            focusLocator: nil,
            contentId: sessionTab.contentId,
            page: sessionTab.page,
            part: sessionTab.part,
            scrollPosition: sessionTab.scrollPosition,
            selectedRange: sessionTab.selectedRange,
            expandedNodeIDs: sessionTab.expandedNodeIDs,
            sidebarScrollPosition: sessionTab.sidebarScrollPosition,
            isSidebarCollapsed: sessionTab.isSidebarCollapsed,
            searchText: sessionTab.searchText,
            searchModeRaw: sessionTab.searchModeRaw,
            nearDistance: sessionTab.nearDistance,
            highlightTerms: sessionTab.highlightTerms,
            isDormantUnavailable: false,
            createdAt: now,
            updatedAt: now
        )
    }

    /// Projects this document tab back to an `iOSReaderTabSession` for compatibility with `iOSNavigationManager`.
    func toLegacyTabSession() -> iOSReaderTabSession {
        let workLocator: TextLocator?
        if let workKey {
            let rootPos: TextPosition = (backend == .otzaria) ? .legacyLine(0) : .canonicalRef(workKey)
            workLocator = TextLocator(backend: backend, workKey: workKey, position: rootPos)
        } else {
            workLocator = sectionLocator
        }

        return iOSReaderTabSession(
            id: id,
            bookId: bookId,
            bookTitle: bookTitle,
            backendLocator: workLocator,
            contentId: contentId,
            locator: sectionLocator ?? focusLocator ?? workLocator,
            page: page,
            part: part,
            scrollPosition: scrollPosition,
            selectedRange: selectedRange,
            expandedNodeIDs: expandedNodeIDs,
            sidebarScrollPosition: sidebarScrollPosition,
            isSidebarCollapsed: isSidebarCollapsed,
            searchText: searchText,
            searchModeRaw: searchModeRaw,
            nearDistance: nearDistance,
            highlightTerms: highlightTerms
        )
    }

    /// Creates an independent duplicate of this tab with a fresh `UUID` while preserving its reading location.
    public func duplicated(newID: UUID = UUID(), now: Date = Date()) -> ReaderDocumentTab {
        var copy = self
        copy = ReaderDocumentTab(
            id: newID,
            backend: backend,
            bookId: bookId,
            bookTitle: bookTitle,
            workKey: workKey,
            sectionLocator: sectionLocator,
            focusLocator: focusLocator,
            contentId: contentId,
            page: page,
            part: part,
            scrollPosition: scrollPosition,
            selectedRange: selectedRange,
            expandedNodeIDs: expandedNodeIDs,
            sidebarScrollPosition: sidebarScrollPosition,
            isSidebarCollapsed: isSidebarCollapsed,
            searchText: searchText,
            searchModeRaw: searchModeRaw,
            nearDistance: nearDistance,
            highlightTerms: highlightTerms,
            isDormantUnavailable: isDormantUnavailable,
            createdAt: now,
            updatedAt: now
        )
        return copy
    }
}
