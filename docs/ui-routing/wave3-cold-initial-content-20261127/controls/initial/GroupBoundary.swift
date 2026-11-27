import Foundation

// These are domain/Store/native shells for ONLY the actual Reader-source
// reservation class. Original transaction/setter authority was separately
// controlled in the immutable Group packet; this capsule claims none of it.
enum StudyWorkspaceError: Error { case invalidMembership, unavailableBook }
@MainActor final class iOSNavigationManager {
    struct ReaderTab {
        let id: UUID
        let book: BooksData
        let viewModel: ReaderViewModel
    }
}
@MainActor final class StudyWorkspaceGroupSelectionReservation {
    enum Phase { case prepared, publishing, committed }
    var phase: Phase = .prepared
    let backend: BackendID = .otzaria
}
@MainActor final class StudyWorkspaceGroupBackendObservation {}
@MainActor final class StudyWorkspacePreparedGroupSelection {
    struct Session {
        let backendLocator: TextLocator?
        let locator: TextLocator?
        let contentId: Int?
    }
    struct Document { let id: UUID; let session: Session }
    let staged: [iOSNavigationManager.ReaderTab]
    let documents: [Document]
    let previousGeneration: UInt64
    let requested: UUID?
    init(tab: iOSNavigationManager.ReaderTab, locator: TextLocator?, contentID: Int?) {
        staged = [tab]; documents = [.init(id: tab.id, session: .init(backendLocator: tab.book.backendLocator,
            locator: locator, contentId: contentID))]
        previousGeneration = BackendCoordinator.shared.generation; requested = tab.id
    }
}
