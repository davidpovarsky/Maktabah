//
//  ReaderViewModel.swift
//  Maktabah
//
//  Created by Ghoys Mawahib on 18/06/26.
//

import Combine
import Foundation
import Observation
import OSLog
import SwiftUI
import Synchronization

@Observable
class ReaderViewModel: ViewModelBase {
    // MARK: - Shared State

    var currentBook: BooksData?
    var currentPage: Int?
    var currentPart: Int?
    var currentHeRef: String?
    var currentContentId: Int = 0
    var recordHistory: Bool = true

    var contentText: String = ""
    #if os(macOS)
    var contentPayload: ContentRenderPayload = .init(
        text: "", keepScrollPosition: false
    )

    /// macOS Annotations Support.
    var currentAnnotations: [Annotation] {
        guard let bkId = currentBook?.id else { return .init() }
        return annotationStore.loadAnnotations(
            bkId: bkId, contentId: currentContentId
        )
    }
    #else
    var currentAnnotations: [Annotation] = []
    #endif

    var state: ViewModelState = .idle
    var totalParts: Int = 0
    var minPageInPart: Int = 0
    var maxPageInPart: Int = 0

    // MARK: - Backend Navigation & Multi-Backend State

    var backendSection: LibraryTextSection?
    var currentDestination: LibraryReaderDestination?
    var searchText: String = ""
    var currentLocator: TextLocator? { readerState.currentLocator }
    var navigationItems: [LibraryNavigationItem] = []
    var backendRenderModel: LibraryReaderRenderModel?
    var selectedSegmentLocator: TextLocator?
    var otzariaSelectedLineAnchor: OtzariaLineAnchor?
    var otzariaLinkedSources: [OtzariaLinkedSource] = []
    var readerInspectorVisible: Bool = false
    var otzariaSourcesIsLoading: Bool = false
    var otzariaSourcesError: String?
    var otzariaSourcesSelectedGroupID: String?
    var otzariaSourcesSelectedBookID: String?
    var otzariaSourcesExpandedSourceIDs: Set<Int> = []
    var otzariaSourcesLoadTask: Task<Void, Never>?
    var backendLoadTask: Task<Void, Never>?
    let contentLoadCoordinator = ReaderContentLoadCoordinator()

    enum PendingReaderScrollTarget: Equatable {
        case top
        case bottom
    }

    var highlightTerms: [String]? = nil
    var searchHighlightFocusLocator: TextLocator?
    var pendingReaderScrollTarget: PendingReaderScrollTarget?
    var pendingReaderScrollTargetLocator: TextLocator?

    func setPendingReaderScrollTarget(_ target: PendingReaderScrollTarget?, for locator: TextLocator? = nil) {
        pendingReaderScrollTarget = target
        pendingReaderScrollTargetLocator = locator
    }

    func consumePendingReaderScrollTarget(for locator: TextLocator? = nil) -> PendingReaderScrollTarget? {
        guard let target = pendingReaderScrollTarget else { return nil }
        if let expected = pendingReaderScrollTargetLocator, let locator {
            guard expected == locator else { return nil }
        }
        pendingReaderScrollTarget = nil
        pendingReaderScrollTargetLocator = nil
        return target
    }

    var currentNavigationIndex: Int? {
        guard let sectionLocator = backendSection?.locator else { return nil }
        if let exact = navigationItems.firstIndex(where: { $0.locator == sectionLocator }) {
            return exact
        }
        if case .canonicalRef(let sectionRef) = sectionLocator.position {
            if let match = navigationItems.firstIndex(where: { item in
                if case .canonicalRef(let itemRef) = item.locator.position {
                    return SefariaRef.sectionMatches(sectionRef, itemRef)
                }
                return false
            }) {
                return match
            }
        }
        return nil
    }

    func navigateToNavigationItem(at index: Int) {
        guard index >= 0, index < navigationItems.count else { return }
        loadBackendContent(navigationItems[index].locator)
    }

    // MARK: - macOS-Only State

    #if os(macOS)
    var windowTitle: String = ""
    var windowSubtitle: String = ""

    var onContentChanged: ((BookContent) -> Void)?
    var onNeedScrollToTop: (() -> Void)?
    var onError: ((Error) -> Void)?
    var onWindowTitleChanged: ((String, String) -> Void)?
    var onPayloadChanged: ((ContentRenderPayload) -> Void)?
    var onNavigationLimitsChanged: (() -> Void)?
    #endif

    // MARK: - iOS-Only State

    #if os(iOS)
    static let kfgqpc = Font.custom(ArabicFont.kfgqpcUthmanTahaNaskh.rawValue, size: 16)
    static let kfgqpcTitle = Font.custom(ArabicFont.kfgqpcUthmanTahaNaskh.rawValue, size: 18)
    static let kfgqpcList = Font.custom(ArabicFont.kfgqpcUthmanTahaNaskh.rawValue, size: 20)

    var searchEvent: ReaderHighlightEvent?
    var annotationEvent: ReaderAnnotationEvent?
    var targetAnnotation: Annotation?
    var searchMode: SearchMode?
    var nearDistance: Int = UserDefaults.standard.searchNearDistance {
        didSet {
            UserDefaults.standard.searchNearDistance = nearDistance
        }
    }

    var searchViewModel = SearchViewModel()
    var bookAnnotationsViewModel = BookAnnotationsViewModel()
    var readerState: ReaderState = .init()
    @ObservationIgnored
    var needsScrollRestore: Bool = false
    @ObservationIgnored
    var fetchScrollPosition: (() -> CGPoint?)?
    @ObservationIgnored
    var fetchSelectedRange: (() -> NSRange?)?
    var isPopoverPresented: Bool = false
    #endif

    // MARK: - Computed Properties

    @ObservationIgnored
    lazy var tocViewModel: BookTOCViewModel = .init(connFactory: { [weak self] in
        guard let self else { return BookConnection() }
        return bookConnectionMutex.withLock { $0 }
    })

    @ObservationIgnored
    var bookConnection: BookConnection {
        bookConnectionMutex.withLock { $0 }
    }

    var showHarakat: Bool {
        TextViewState.shared.showHarakat
    }

    var statusSubtitle: String {
        if let otzariaReference = otzariaCurrentReferencePage() {
            return otzariaReference
        }
        if let section = backendSection {
            return LibraryPresentationPolicy.reference(displayRef: section.displayRef, heRef: section.heRef)
        }
        if let currentBook, currentBook.backendLocator != nil {
            return currentBook.book
        }
        if let currentPage {
            let page = LibraryPresentationPolicy.localizedNumber(currentPage)
            if let currentPart, currentPart != -1 {
                let part = LibraryPresentationPolicy.localizedNumber(currentPart)
                return "\(String(localized: "Page")) \(page) · \(String(localized: "Part")) \(part)"
            } else {
                return "\(String(localized: "Page")) \(page)"
            }
        } else {
            return String(localized: "Page")
        }
    }

    var diacriticsText: String {
        currentBookContent?.nash ?? ""
    }

    var currentBookContent: BookContent? {
        guard let bkId = currentBook?.id else { return nil }
        return BookPageCache.shared.get(bookId: bkId, contentId: currentContentId)
    }

    // MARK: - Dependencies

    let bookConnectionMutex = Mutex(BookConnection())
    let historyVM: HistoryViewModel = .shared
    let annotationStore: AnnotationStore = .shared
    let annotationCoordinator: AnnotationCoordinator = .init()
    @ObservationIgnored var annotationCancellable: AnyCancellable?

    // MARK: - Private Properties

    var _currentID: Int?

    var currentID: Int? {
        get { _currentID }
        set { _currentID = newValue }
    }

    // MARK: - Initialization

    init(book: BooksData? = nil) {
        super.init()
        if let book {
            currentBook = book
            #if os(iOS)
            bookAnnotationsViewModel.bookId = book.id
            #endif
        }
        setupNotificationObservers()
    }

    // MARK: - Override

    override func migrateBookId(from oldId: Int, to newId: Int) {
        guard currentBook?.backendLocator == nil else { return }
        guard let current = currentBook, current.id == oldId else { return }
        guard let newBookData = LibraryDataManager.shared.booksById[newId] else { return }

        currentBook = newBookData
        BookPageCache.shared.remove(bookId: oldId)
        BookPageCache.shared.remove(bookId: newId)
        BookConnection.invalidateTOC(for: oldId)
        BookConnection.invalidateTOC(for: newId)
        BookConnection.totalPartsCache.removeObject(forKey: NSString(string: String(oldId)))
        BookConnection.totalPartsCache.removeObject(forKey: NSString(string: String(newId)))

        do {
            try bookConnection.connect(archive: newBookData.archive)
        } catch {
            Logger.reader.error("Failed to reconnect after migrateBookId: \(error.localizedDescription, privacy: .public)")
        }

        loadTOC(book: newBookData)

        if let content = bookConnection.getContent(bkid: String(newId), contentId: currentContentId) {
            updateContentState(with: content)
        } else {
            getFirstBookContent(for: newBookData)
        }
    }

    // MARK: - Private: Core Update

    func updateContentState(with content: BookContent) {
        let previousContentId = currentContentId
        contentText = content.nash
        #if os(macOS)
        contentPayload = ContentRenderPayload(bookId: currentBook?.id, text: content.nash, content: content, keepScrollPosition: false)
        onPayloadChanged?(contentPayload)
        #endif
        currentPart = content.part
        currentPage = content.page
        currentHeRef = content.heRef
        currentID = content.id
        currentContentId = content.id

        if recordHistory, let locator = content.backendLocator, let title = currentBook?.book {
            Task { try? await QualifiedLocatorStore.shared.record(locator, title: title) }
        } else if recordHistory, let bookId = currentBook?.id {
            historyVM.updateLastContentId(content.id, for: bookId)
        }

        loadAnnotations()

        #if os(macOS)
        onContentChanged?(content)
        updateWindowTitle(
            book: currentBook, page: currentPage, part: currentPart
        )
        onNavigationLimitsChanged?()
        #endif

        #if os(iOS)
        if currentBook?.backendLocator == nil,
           let searchEvent,
           let eventContentId = searchEvent.contentId,
           eventContentId != content.id {
            self.searchEvent = nil
        }
        if let annotationEvent, annotationEvent.annotation.contentId != content.id {
            self.annotationEvent = nil
        }
        // Sync to state
        readerState.currentBook = currentBook
        readerState.currentID = content.id
        readerState.currentPart = content.part
        readerState.currentPage = content.page
        readerState.currentLocator = content.backendLocator ?? backendSection?.locator ?? currentBook?.backendLocator
        // Clear saved scroll/selection so it scrolls to top on page change
        readerState.scrollPosition = nil
        readerState.selectedRange = nil
        if previousContentId != content.id {
            clearOtzariaLineSelectionForContentChange()
        }
        updateNavigationLimits()
        #endif
    }

    #if os(iOS)
    var availableReaderTextModes: [LibraryReaderTextMode] {
        backendRenderModel?.capabilities.availableModes ?? []
    }

    var currentReaderTextMode: LibraryReaderTextMode {
        backendRenderModel?.mode ?? TextViewState.shared.readerTextMode
    }

    var selectedSegmentRange: NSRange? {
        if let visualRange = backendRenderModel?.renderedSegment(for: selectedSegmentLocator)?.visualRange {
            return visualRange
        }
        return otzariaSelectedLineAnchor?.range
    }

    var usesNaturalReaderTextDirection: Bool {
        guard let model = backendRenderModel else { return currentBook?.isMultiLanguage ?? false }
        switch model.mode {
        case .both:
            return true
        case .source:
            return model.capabilities.sourceDirection != .rightToLeft
        case .translation:
            return model.capabilities.translationDirection != .rightToLeft
        }
    }

    @MainActor
    func setReaderTextMode(_ mode: LibraryReaderTextMode) {
        TextViewState.shared.setReaderTextMode(mode)
        guard let section = backendSection else { return }
        let renderModel = MaktabahBackendAdapter.renderModel(from: section, preferredMode: mode)
        backendRenderModel = renderModel
        selectedSegmentLocator = nil
        let content = MaktabahBackendAdapter.content(from: section, renderModel: renderModel)
        if let bookID = currentBook?.id { BookPageCache.shared.set(bookId: bookID, content: content) }
        updateContentState(with: content)
    }
    #endif
}
