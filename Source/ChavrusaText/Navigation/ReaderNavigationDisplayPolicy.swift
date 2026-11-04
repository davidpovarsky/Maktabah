import Foundation

/// Presentation only: never modifies a locator, selection, reading mode or database.
enum ReaderNavigationDisplayPolicy {
    struct Entry: Sendable {
        let id: Int
        let parentID: Int?
        let title: String
    }

    /// Follow actual database ancestry; a fixed TOC depth is not a daf/chapter.
    /// Leaf paragraphs are deliberately excluded unless explicitly selected.
    static func navigationUnitTitle(containing entryID: Int?, entries: [Entry]) -> String? {
        let byID = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let parents = Set(entries.compactMap(\.parentID))
        var chain: [Entry] = []
        var currentID = entryID
        var visited = Set<Int>()
        while let id = currentID, visited.insert(id).inserted, let entry = byID[id] {
            chain.append(entry)
            currentID = entry.parentID
        }
        // Prefer the nearest explicitly named canonical unit, including a leaf daf.
        if let namedUnit = chain.first(where: { isNamedNavigationUnit($0.title) }) { return namedUnit.title }
        // Other book-specific section names remain valid when they own child entries.
        // A root work title alone provides no evidence of a finer navigation unit.
        return chain.first(where: {
            $0.parentID != nil && parents.contains($0.id) && !$0.title.isEmpty && !isParagraphTitle($0.title)
        })?.title
    }

    private static func isParagraphTitle(_ title: String) -> Bool {
        title.range(of: #"^(?:פסק[הא]|paragraph|فقرة)(?:\s|$)"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func isNamedNavigationUnit(_ title: String) -> Bool {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        // These identify canonical names, never manufacture a label or convert an index.
        return title.range(of: #"^(?:דף|פרק|סימן|שער|חלק|עמוד|סעיף|chapter|section|daf|page|باب|فصل|جزء)(?:\s|$)"#,
                           options: [.regularExpression, .caseInsensitive]) != nil
            || title.range(of: #"^[א-ת׳״'\"]+[.:]$"#, options: .regularExpression) != nil
    }

    static func title(workTitle: String, navigationUnitTitle: String?, explicitSelectionRef: String?) -> String {
        if let selection = explicitSelectionRef?.trimmingCharacters(in: .whitespacesAndNewlines), !selection.isEmpty {
            return selection
        }
        guard let unit = navigationUnitTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !unit.isEmpty else { return workTitle }
        // Preserve punctuation exactly, including ':' for amud bet.
        return unit.hasPrefix(workTitle) ? unit : "\(workTitle), \(unit)"
    }
}

#if canImport(SwiftUI) && os(iOS)
import SwiftUI

struct ReaderNavigationDisplayLabel: View {
    let viewModel: ReaderViewModel
    var locator: TextLocator? = nil
    var fallback: String
    @State private var resolved: ResolvedTitle?

    private struct ResolvedTitle { let key: String; let title: String? }
    private var usesSemanticLabel: Bool {
        ChavrusaTextReaderUI.isEnabled && UIDevice.current.userInterfaceIdiom == .pad && viewModel.isOtzariaReaderEnabled
    }
    private var lineIndex: Int {
        if case .legacyLine(let index) = locator?.position { return index }
        return viewModel.currentContentId
    }
    private var requestKey: String { "\(viewModel.currentBook?.id ?? 0):\(lineIndex)" }
    private var explicitRef: String? {
        guard locator == nil,
              (viewModel.fetchSelectedRange?()?.length ?? viewModel.readerState.selectedRange?.length ?? 0) > 0
        else { return nil }
        return viewModel.otzariaSelectedLineAnchor?.heRef
    }
    var body: some View {
        Text(usesSemanticLabel ? ReaderNavigationDisplayPolicy.title(
            workTitle: viewModel.currentBook?.book ?? "",
            navigationUnitTitle: resolved?.key == requestKey ? resolved?.title : nil,
            explicitSelectionRef: explicitRef) : fallback)
        .task(id: requestKey) {
            guard usesSemanticLabel, let book = viewModel.currentBook else { return }
            let key = requestKey
            let index = lineIndex
            let title = await Task.detached(priority: .userInitiated) {
                let bridge = OtzariaMaktabahBridge.shared
                let descriptor = bridge.getReadingUnitDescriptor(bookId: book.id, containingLineIndex: index, mode: .paragraph)
                let entries = bridge.getTOCEntries(for: book).map {
                    ReaderNavigationDisplayPolicy.Entry(id: $0.entryId, parentID: $0.parentId, title: $0.bab)
                }
                return ReaderNavigationDisplayPolicy.navigationUnitTitle(containing: descriptor?.tocEntryId, entries: entries)
            }.value
            guard !Task.isCancelled, requestKey == key else { return }
            resolved = .init(key: key, title: title)
        }
    }
}
#endif
