import Foundation

#if os(iOS)
extension ReaderViewModel {
    var canGoBackInOtzariaSourcesPanel: Bool {
        otzariaSourcesSelectedBookID != nil || otzariaSourcesSelectedGroupID != nil
    }

    func goBackInOtzariaSourcesPanel() {
        if otzariaSourcesSelectedBookID != nil {
            otzariaSourcesSelectedBookID = nil
            otzariaSourcesExpandedSourceIDs.removeAll()
        } else if otzariaSourcesSelectedGroupID != nil {
            otzariaSourcesSelectedGroupID = nil
            otzariaSourcesSelectedBookID = nil
            otzariaSourcesExpandedSourceIDs.removeAll()
        }
    }

    func resetOtzariaSourcesPanelNavigation() {
        otzariaSourcesSelectedGroupID = nil
        otzariaSourcesSelectedBookID = nil
        otzariaSourcesExpandedSourceIDs.removeAll()
    }

    func clearOtzariaLineSelectionForContentChange() {
        otzariaSourcesLoadTask?.cancel()
        otzariaSourcesLoadTask = nil
        readerInspectorVisible = false
        selectedSegmentLocator = nil
        otzariaSelectedLineAnchor = nil
        otzariaLinkedSources = []
        otzariaSourcesError = nil
        otzariaSourcesIsLoading = false
        readerState.selectedRange = nil
    }

    @MainActor
    func didTapReaderText(at characterIndex: Int) {
        if let mapping = backendRenderModel?.renderedSegment(at: characterIndex) {
            guard mapping.locator.backend == BackendCoordinator.shared.activeBackendID else { return }
            otzariaSourcesLoadTask?.cancel()
            otzariaSourcesLoadTask = nil
            if readerInspectorVisible,
               selectedSegmentLocator?.persistenceKey == mapping.locator.persistenceKey {
                closeReaderInspector()
                return
            }
            selectedSegmentLocator = mapping.locator
            otzariaSelectedLineAnchor = nil
            readerInspectorVisible = true
            otzariaSourcesIsLoading = false
            otzariaSourcesError = nil
            return
        }
        guard OtzariaBackendActivation.isActive else { return }
        guard let currentBook else {
            OtzariaFileLogger.shared.log("[ReaderViewModel] Otzaria tap ignored without currentBook characterIndex=\(characterIndex)")
            return
        }

        OtzariaFileLogger.shared.log("[ReaderViewModel] Otzaria text tapped characterIndex=\(characterIndex) bookId=\(currentBook.id) contentId=\(currentContentId)")

        if let anchor = OtzariaMaktabahBridge.shared.lineAnchor(
            bookId: currentBook.id,
            contentId: currentContentId,
            characterIndex: characterIndex
        ) {
            applyOtzariaLineAnchorTap(anchor)
        } else {
            otzariaSourcesLoadTask?.cancel()
            let bookId = currentBook.id
            let contentId = currentContentId
            otzariaSourcesLoadTask = Task { @MainActor [weak self] in
                guard let self else { return }
                guard let anchor = await OtzariaMaktabahBridge.shared.lineAnchorAsync(
                    bookId: bookId,
                    contentId: contentId,
                    characterIndex: characterIndex
                ) else {
                    OtzariaFileLogger.shared.log("[ReaderViewModel] Otzaria tap failed to resolve line bookId=\(bookId) contentId=\(contentId) characterIndex=\(characterIndex)")
                    return
                }
                guard !Task.isCancelled else { return }
                self.applyOtzariaLineAnchorTap(anchor)
            }
        }
    }

    @MainActor
    private func applyOtzariaLineAnchorTap(_ anchor: OtzariaLineAnchor) {
        let locator = TextLocator(
            backend: .otzaria,
            workKey: "book:\(anchor.bookId)",
            position: .legacyLine(anchor.lineIndex)
        )
        if readerInspectorVisible,
           selectedSegmentLocator?.persistenceKey == locator.persistenceKey {
            closeReaderInspector()
            return
        }

        otzariaSourcesLoadTask?.cancel()
        otzariaSourcesLoadTask = nil
        otzariaSelectedLineAnchor = anchor
        selectedSegmentLocator = locator
        readerInspectorVisible = true
        otzariaLinkedSources = []
        otzariaSourcesIsLoading = false
        otzariaSourcesError = nil

        OtzariaFileLogger.shared.log("[ReaderViewModel] Otzaria resolved lineId=\(anchor.id) lineIndex=\(anchor.lineIndex) heRef=\(anchor.heRef ?? "")")

        // The shared inspector owns metadata loading, retry and visible-snippet
        // hydration. A second eager fetch here decoded every commentary even
        // though no reader consumes otzariaLinkedSources anymore.
    }

    func closeReaderInspector() {
        otzariaSourcesLoadTask?.cancel()
        otzariaSourcesLoadTask = nil
        readerInspectorVisible = false
        selectedSegmentLocator = nil
        otzariaSelectedLineAnchor = nil
        otzariaLinkedSources = []
        otzariaSourcesIsLoading = false
        otzariaSourcesError = nil
        resetOtzariaSourcesPanelNavigation()
    }

    func resolveOtzariaLineAnchor(for selectedRange: NSRange) -> OtzariaLineAnchor? {
        guard OtzariaBackendActivation.isActive, let currentBook else { return nil }
        return OtzariaMaktabahBridge.shared.lineAnchor(
            bookId: currentBook.id,
            contentId: currentContentId,
            characterIndex: selectedRange.location
        )
    }
}
#endif

extension ReaderViewModel {
    var isOtzariaReaderEnabled: Bool {
        #if os(iOS)
        OtzariaBackendActivation.isActive
        #else
        false
        #endif
    }

    func otzariaCurrentReferencePage() -> String? {
        guard isOtzariaReaderEnabled, let currentHeRef, !currentHeRef.isEmpty else { return nil }
        return currentHeRef
    }

    func otzariaReaderLog(_ message: String) {
        #if os(iOS)
        guard isOtzariaReaderEnabled else { return }
        OtzariaFileLogger.shared.log("[ReaderViewModel] \(message)")
        #endif
    }

    func otzariaReaderElapsedMs(_ start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }
}
