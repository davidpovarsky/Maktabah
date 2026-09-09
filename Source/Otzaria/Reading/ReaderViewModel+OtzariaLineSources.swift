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

        guard let anchor = OtzariaMaktabahBridge.shared.lineAnchor(
            bookId: currentBook.id,
            contentId: currentContentId,
            characterIndex: characterIndex
        ) else {
            OtzariaFileLogger.shared.log("[ReaderViewModel] Otzaria tap failed to resolve line bookId=\(currentBook.id) contentId=\(currentContentId) characterIndex=\(characterIndex)")
            return
        }

        otzariaSelectedLineAnchor = anchor
        selectedSegmentLocator = TextLocator(
            backend: .otzaria,
            workKey: "book:\(anchor.bookId)",
            position: .legacyLine(anchor.lineIndex)
        )
        readerInspectorVisible = true
        otzariaSourcesIsLoading = true
        otzariaSourcesError = nil

        OtzariaFileLogger.shared.log("[ReaderViewModel] Otzaria resolved lineId=\(anchor.id) lineIndex=\(anchor.lineIndex) heRef=\(anchor.heRef ?? "")")

        let links = OtzariaMaktabahBridge.shared.getLinksForLine(anchor)
        otzariaLinkedSources = links
        otzariaSourcesIsLoading = false

        OtzariaFileLogger.shared.log("[ReaderViewModel] Otzaria links loaded lineId=\(anchor.id) count=\(links.count)")
    }

    func closeReaderInspector() {
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
