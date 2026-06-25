import Foundation

@MainActor
final class OtzariaAppContainer: ObservableObject {
    @Published private(set) var repositories: OtzariaAppRepositories?
    @Published private(set) var databaseURL: URL?
    @Published private(set) var databaseToken = UUID()
    @Published var databaseError: String?
    @Published var isOpeningDatabase = false

    private let bookmarkStore = OtzariaSecurityScopedBookmarkStore()
    private var connection: OtzariaSQLiteConnection?
    private var scopedAccess: OtzariaSecurityScopedAccess?

    deinit {
        connection?.close()
        scopedAccess?.stop()
    }

    func restoreDatabaseIfPossible() async {
        guard repositories == nil else { return }
        do {
            guard let restored = try bookmarkStore.restore() else { return }
            await openDatabase(at: restored.url, shouldSaveBookmark: false, scopedAccess: restored.access)
        } catch {
            databaseError = error.localizedDescription
        }
    }

    func openPickedDatabase(at url: URL) async {
        await openDatabase(at: url, shouldSaveBookmark: true, scopedAccess: nil)
    }

    func forgetDatabase() {
        connection?.close()
        connection = nil
        scopedAccess?.stop()
        scopedAccess = nil
        repositories = nil
        databaseURL = nil
        databaseError = nil
        bookmarkStore.forget()
        databaseToken = UUID()
    }

    private func openDatabase(at url: URL, shouldSaveBookmark: Bool, scopedAccess existingAccess: OtzariaSecurityScopedAccess?) async {
        isOpeningDatabase = true
        databaseError = nil
        defer { isOpeningDatabase = false }

        connection?.close()
        connection = nil
        scopedAccess?.stop()
        scopedAccess = nil
        repositories = nil

        do {
            let access = try existingAccess ?? OtzariaSecurityScopedAccess.start(for: url)
            if shouldSaveBookmark {
                try bookmarkStore.save(url: url)
            }

            let newConnection = try OtzariaSQLiteConnection.openReadOnly(url: url)
            try await newConnection.read { db in
                try OtzariaSchemaValidator.validate(db)
            }

            let newRepositories = OtzariaAppRepositories(
                library: OtzariaSQLiteLibraryRepository(database: newConnection),
                bookText: OtzariaSQLiteBookTextRepository(database: newConnection),
                sources: OtzariaSQLiteSourceRepository(database: newConnection)
            )

            scopedAccess = access
            connection = newConnection
            repositories = newRepositories
            databaseURL = url
            databaseToken = UUID()
        } catch {
            databaseError = error.localizedDescription
        }
    }
}

struct OtzariaAppRepositories {
    let library: any OtzariaLibraryRepository
    let bookText: any OtzariaBookTextRepository
    let sources: any OtzariaSourceRepository
}
