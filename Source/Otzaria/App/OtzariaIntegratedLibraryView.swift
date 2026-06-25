import SwiftUI
import UniformTypeIdentifiers

struct OtzariaIntegratedLibraryView: View {
    let pushReaderOnSelection: Bool

    @EnvironmentObject private var app: OtzariaAppContainer
    @EnvironmentObject private var navigation: OtzariaIntegratedNavigationState

    @StateObject private var viewModel = OtzariaLibraryViewModel()
    @State private var showDatabaseImporter = false
    @State private var showReaderSettings = false

    private static let dbType = UTType(filenameExtension: "db") ?? .data
    private static let sqliteType = UTType(filenameExtension: "sqlite") ?? .data

    init(pushReaderOnSelection: Bool = false) {
        self.pushReaderOnSelection = pushReaderOnSelection
    }

    var body: some View {
        content
            .fileImporter(
                isPresented: $showDatabaseImporter,
                allowedContentTypes: [Self.dbType, Self.sqliteType, .data],
                allowsMultipleSelection: false,
                onCompletion: handleDatabaseImport
            )
            .sheet(isPresented: $showReaderSettings) {
                NavigationStack {
                    OtzariaReaderSettingsView()
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("בחר DB", systemImage: "externaldrive") {
                        showDatabaseImporter = true
                    }
                    .accessibilityLabel("בחר מסד נתונים")

                    Button("הגדרות קריאה", systemImage: "textformat.size") {
                        showReaderSettings = true
                    }
                    .accessibilityLabel("הגדרות קריאה")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("שכח DB", systemImage: "trash", role: .destructive) {
                            navigation.clearBook()
                            app.forgetDatabase()
                        }
                        .disabled(app.repositories == nil && app.databaseURL == nil)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("אפשרויות אוצריא")
                }
            }
            .task {
                await app.restoreDatabaseIfPossible()
            }
            .task(id: app.databaseToken) {
                await viewModel.load(using: app.repositories?.library)
            }
    }

    @ViewBuilder
    private var content: some View {
        let selectedBook = Binding<OtzariaBook?>(
            get: { navigation.selectedBook },
            set: { newValue in
                if let newValue {
                    navigation.openBook(newValue)
                } else {
                    navigation.clearBook()
                }
            }
        )

        if pushReaderOnSelection {
            OtzariaLibraryView(
                viewModel: viewModel,
                selectedBook: selectedBook,
                showDatabaseImporter: $showDatabaseImporter
            )
            .navigationDestination(item: selectedBook) { book in
                OtzariaIntegratedReaderDetailView(book: book)
            }
        } else {
            OtzariaLibraryView(
                viewModel: viewModel,
                selectedBook: selectedBook,
                showDatabaseImporter: $showDatabaseImporter
            )
        }
    }

    private func handleDatabaseImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            navigation.clearBook()
            Task {
                await app.openPickedDatabase(at: url)
                await viewModel.load(using: app.repositories?.library)
            }
        case .failure(let error):
            app.databaseError = error.localizedDescription
        }
    }
}
