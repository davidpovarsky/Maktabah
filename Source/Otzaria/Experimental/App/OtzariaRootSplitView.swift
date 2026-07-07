import SwiftUI
import UniformTypeIdentifiers

struct OtzariaRootSplitView: View {
    @EnvironmentObject private var app: OtzariaAppContainer

    @StateObject private var libraryViewModel = OtzariaLibraryViewModel()
    @StateObject private var sourcesViewModel = OtzariaSourcesViewModel()

    @State private var selectedBook: OtzariaBook?
    @State private var selectedLineID: Int?
    @State private var showDatabaseImporter = false
    @State private var showSourcesInspector = false
    @State private var showReaderSettings = false

    private static let dbType = UTType(filenameExtension: "db") ?? .data
    private static let sqliteType = UTType(filenameExtension: "sqlite") ?? .data

    var body: some View {
        NavigationSplitView {
            OtzariaLibraryView(
                viewModel: libraryViewModel,
                selectedBook: $selectedBook,
                showDatabaseImporter: $showDatabaseImporter
            )
        } detail: {
            detailView
                .inspector(isPresented: $showSourcesInspector) {
                    OtzariaSourcesView(viewModel: sourcesViewModel)
                }
        }
        .navigationSplitViewStyle(.balanced)
        .fileImporter(
            isPresented: $showDatabaseImporter,
            allowedContentTypes: [Self.dbType, Self.sqliteType, .data],
            allowsMultipleSelection: false
        ) { result in
            handleDatabaseImport(result)
        }
        .sheet(isPresented: $showReaderSettings) {
            NavigationStack {
                OtzariaReaderSettingsView()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("בחר DB", systemImage: "externaldrive") {
                    showDatabaseImporter = true
                }

                Button("הגדרות", systemImage: "textformat.size") {
                    showReaderSettings = true
                }
            }

            ToolbarItemGroup(placement: .secondaryAction) {
                Button("שכח DB", systemImage: "trash", role: .destructive) {
                    selectedBook = nil
                    selectedLineID = nil
                    sourcesViewModel.reset()
                    showSourcesInspector = false
                    app.forgetDatabase()
                }
            }
        }
        .task {
            await app.restoreDatabaseIfPossible()
        }
        .task(id: app.databaseToken) {
            await libraryViewModel.load(using: app.repositories?.library)
        }
        .onChange(of: selectedBook) { _, _ in
            selectedLineID = nil
            sourcesViewModel.reset()
            showSourcesInspector = false
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    @ViewBuilder
    private var detailView: some View {
        if app.isOpeningDatabase {
            OtzariaLoadingStateView(title: "פותח מסד נתונים")
        } else if let error = app.databaseError {
            OtzariaErrorStateView(title: "שגיאה בפתיחת המסד", message: error)
        } else if let book = selectedBook, let repositories = app.repositories {
            OtzariaReaderView(
                book: book,
                repository: repositories.bookText,
                selectedLineID: $selectedLineID
            ) { line in
                showSourcesInspector = true
                Task {
                    await sourcesViewModel.load(line: line, repository: repositories.sources)
                }
            }
            .id(book.id)
        } else if app.repositories == nil {
            OtzariaDatabaseRequiredView {
                showDatabaseImporter = true
            }
        } else {
            OtzariaReaderPlaceholderView()
        }
    }

    private func handleDatabaseImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            selectedBook = nil
            selectedLineID = nil
            sourcesViewModel.reset()
            showSourcesInspector = false
            Task {
                await app.openPickedDatabase(at: url)
                await libraryViewModel.load(using: app.repositories?.library)
            }
        case .failure(let error):
            app.databaseError = error.localizedDescription
        }
    }
}
