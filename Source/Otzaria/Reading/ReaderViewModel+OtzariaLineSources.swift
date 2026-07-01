import Foundation

#if os(iOS)
extension ReaderViewModel {
    func didTapOtzariaText(at characterIndex: Int) {
        guard OtzariaMaktabahBridge.shared.isEnabled else { return }
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
        otzariaSourcesInspectorVisible = true
        otzariaSourcesIsLoading = true
        otzariaSourcesError = nil

        OtzariaFileLogger.shared.log("[ReaderViewModel] Otzaria resolved lineId=\(anchor.id) lineIndex=\(anchor.lineIndex) heRef=\(anchor.heRef ?? "")")

        let links = OtzariaMaktabahBridge.shared.getLinksForLine(anchor)
        otzariaLinkedSources = links
        otzariaSourcesIsLoading = false

        OtzariaFileLogger.shared.log("[ReaderViewModel] Otzaria links loaded lineId=\(anchor.id) count=\(links.count)")
    }

    func closeOtzariaSourcesInspector() {
        otzariaSourcesInspectorVisible = false
    }

    func resolveOtzariaLineAnchor(for selectedRange: NSRange) -> OtzariaLineAnchor? {
        guard OtzariaMaktabahBridge.shared.isEnabled, let currentBook else { return nil }
        return OtzariaMaktabahBridge.shared.lineAnchor(
            bookId: currentBook.id,
            contentId: currentContentId,
            characterIndex: selectedRange.location
        )
    }
}
#endif
