import Foundation

/// Presentation only: never modifies a locator, selection, reading mode or database.
enum ReaderNavigationDisplayPolicy {
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
            guard usesSemanticLabel, let bookID = viewModel.currentBook?.id else { return }
            let key = requestKey
            let index = lineIndex
            let descriptor = await Task.detached(priority: .userInitiated) {
                OtzariaMaktabahBridge.shared.getReadingUnitDescriptor(bookId: bookID, containingLineIndex: index, mode: .chapter)
            }.value
            guard !Task.isCancelled, requestKey == key else { return }
            // A service fallback to paragraph/line is not evidence of a canonical section.
            resolved = .init(key: key, title: descriptor?.mode == .chapter ? descriptor?.title : nil)
        }
    }
}
#endif
