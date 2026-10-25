//
//  Reader+Navigation.swift
//  Maktabah
//

import Foundation

extension ReaderViewModel {
    // MARK: - Navigation

    enum PageDirection {
        case next
        case prev
    }

    func navigateToPage(direction: PageDirection) -> BookContent? {
        guard let currentBook, let currentId = currentID else { return nil }

        let content: BookContent? = switch direction {
        case .next:
            bookConnection.getNextPage(from: currentBook, contentId: currentId)
        case .prev:
            bookConnection.getPrevPage(from: currentBook, contentId: currentId)
        }

        #if os(macOS)
        onNeedScrollToTop?()
        #endif

        return content
    }

    func goToNextPage() {
        let action = ReaderBackendPagingCoordinator.resolvePagingAction(
            direction: .next,
            isBackendBook: currentBook?.backendLocator != nil,
            currentLocator: backendSection?.locator ?? currentBook?.backendLocator,
            backendSectionNext: backendSection?.next,
            backendSectionPrevious: backendSection?.previous,
            navigationItems: navigationItems
        )
        switch action {
        case .loadBackendLocator(let locator, let scrollTarget):
            #if os(iOS)
            setPendingReaderScrollTarget(scrollTarget == .top ? .top : .bottom, for: locator)
            #endif
            loadBackendContent(locator)
        case .noOpBoundaryReached:
            return
        case .performLegacyFallback:
            guard let content = navigateToPage(direction: .next) else { return }
            updateContentState(with: content)
        }
    }

    func goToPrevPage() {
        let action = ReaderBackendPagingCoordinator.resolvePagingAction(
            direction: .previous,
            isBackendBook: currentBook?.backendLocator != nil,
            currentLocator: backendSection?.locator ?? currentBook?.backendLocator,
            backendSectionNext: backendSection?.next,
            backendSectionPrevious: backendSection?.previous,
            navigationItems: navigationItems
        )
        switch action {
        case .loadBackendLocator(let locator, let scrollTarget):
            #if os(iOS)
            setPendingReaderScrollTarget(scrollTarget == .top ? .top : .bottom, for: locator)
            #endif
            loadBackendContent(locator)
        case .noOpBoundaryReached:
            return
        case .performLegacyFallback:
            guard let content = navigateToPage(direction: .prev) else { return }
            updateContentState(with: content)
        }
    }

    func fetchContentById(_ contentId: Int) {
        guard let currentBook else { return }
        if let content = bookConnection.getContent(
            bkid: "\(currentBook.id)",
            contentId: contentId,
            quran: false
        ) {
            updateContentState(with: content)
        }
    }

    // MARK: - Navigation Limits

    func updateNavigationLimits() {
        guard currentBook?.backendLocator == nil else { return }
        guard let part = currentPart, let book = currentBook else { return }
        let bkid = String(book.id)

        Task.detached { [weak self] in
            guard let self else { return }
            let total = await self.bookConnection.getTotalParts(bkid: bkid)

            let juz = part < 1 ? 1 : part
            let minPg = await self.bookConnection.getMinPagesInPart(bkid: bkid, part: juz)
            let maxPg = await self.bookConnection.getPagesInPart(bkid: bkid, part: juz)

            await MainActor.run {
                self.totalParts = total
                self.minPageInPart = minPg
                self.maxPageInPart = maxPg
                #if os(macOS)
                self.onNavigationLimitsChanged?()
                #endif
            }
        }
    }

    func jumpToPart(_ part: Int) {
        guard let book = currentBook else { return }
        let bkid = String(book.id)
        Task.detached { [weak self] in
            guard let self else { return }
            let minPage = await self.bookConnection.getMinPagesInPart(bkid: bkid, part: part)
            guard let result = await self.bookConnection.getContent(
                bkid: bkid, part: part, page: minPage
            )
            else { return }

            await MainActor.run { [result] in
                self.updateContentState(with: result)
            }
        }
    }

    func jumpToPage(_ page: Int) {
        guard let book = currentBook else { return }
        let bkid = String(book.id)
        let part = currentPart ?? -1 <= 1 ? 1 : currentPart!
        Task.detached { [weak self] in
            guard let self else { return }
            guard let result = await self.bookConnection.getContent(
                bkid: bkid, part: part, page: page
            )
            else { return }

            await MainActor.run { [result] in
                self.updateContentState(with: result)
            }
        }
    }
}
