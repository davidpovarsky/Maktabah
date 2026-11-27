import SwiftUI

struct GlobalSearchToolbar: ToolbarContent {
    let session: UnifiedSearchSessionController
    let canSaveResults: Bool
    let onSaveResults: () -> Void
    let onSavedResults: () -> Void
    @State private var showsHelp = false

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if BackendCoordinator.shared.usesNativeMaktabahDataPath {
                Button(action: onSavedResults) { Label("תוצאות שמורות", systemImage: "bookmark") }
                    .accessibilityIdentifier("global-search-saved")
            }
            Menu {
                if canSaveResults && !session.resultsAreDirty && !session.isSearching {
                    Button("שמור תוצאות", systemImage: "square.and.arrow.down", action: onSaveResults)
                        .accessibilityIdentifier("global-search-save")
                }
                if BackendCoordinator.shared.usesNativeMaktabahDataPath {
                    Button("תוצאות שמורות", systemImage: "bookmark", action: onSavedResults)
                }
                if !session.isSefaria {
                    Button("נתוני חיפוש", systemImage: "internaldrive") { session.showsSearchDataSheet = true }
                        .accessibilityIdentifier("global-search-data")
                }
                Button("עזרה", systemImage: "questionmark.circle") { showsHelp = true }
                Button("אפס שאילתה ותוצאות", systemImage: "xmark.circle") {
                    session.clearResults()
                    session.query = ""
                }
                .accessibilityIdentifier("global-search-reset")
            } label: { Label("אפשרויות נוספות", systemImage: "ellipsis") }
            .accessibilityIdentifier("global-search-more")
            .sheet(isPresented: $showsHelp) { SearchHelpView(isSefaria: session.isSefaria) }
        }
    }
}
