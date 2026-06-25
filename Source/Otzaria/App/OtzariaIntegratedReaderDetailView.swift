import SwiftUI

struct OtzariaIntegratedReaderDetailView: View {
    let book: OtzariaBook?

    @EnvironmentObject private var app: OtzariaAppContainer
    @EnvironmentObject private var navigation: OtzariaIntegratedNavigationState

    init(book: OtzariaBook? = nil) {
        self.book = book
    }

    var body: some View {
        detailContent
            .inspector(isPresented: Binding(
                get: { navigation.isSourcesInspectorPresented },
                set: { navigation.isSourcesInspectorPresented = $0 }
            )) {
                OtzariaSourcesView(viewModel: navigation.sourcesViewModel)
            }
    }

    @ViewBuilder
    private var detailContent: some View {
        if app.isOpeningDatabase {
            OtzariaLoadingStateView(title: "פותח מסד נתונים")
        } else if let error = app.databaseError, app.repositories == nil {
            OtzariaErrorStateView(title: "שגיאה בפתיחת המסד", message: error)
        } else if let currentBook, let repositories = app.repositories {
            OtzariaReaderView(
                book: currentBook,
                repository: repositories.bookText,
                selectedLineID: Binding(
                    get: { navigation.selectedLineID },
                    set: { navigation.selectedLineID = $0 }
                )
            ) { line in
                navigation.selectLine(line, repository: repositories.sources)
            }
            .id("\(currentBook.id)-\(navigation.readerToken)")
        } else if app.repositories == nil {
            OtzariaDatabaseRequiredView {
                // The DB picker lives in the library column/tab.
            }
        } else {
            OtzariaReaderPlaceholderView()
        }
    }

    private var currentBook: OtzariaBook? {
        book ?? navigation.selectedBook
    }
}
