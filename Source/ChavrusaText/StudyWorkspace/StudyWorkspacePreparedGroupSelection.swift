import Foundation

/// The original adapter's captured inputs and staged original Reader objects.
/// No permission, second workspace or replacement resolver lives in this type.
@MainActor
final class StudyWorkspacePreparedGroupSelection {
    let target: StudyTabGroup
    var requested: UUID?
    let desiredBackend: BackendID
    let documents: [ReaderDocumentTab]
    let retained: [iOSNavigationManager.ReaderTab]
    let previousTabs: [iOSNavigationManager.ReaderTab]
    let previousActive: UUID?
    let previousBackend: BackendID
    let previousGroup: UUID?
    let previousGeneration: UInt64
    let previousSelection: StudySceneSelection?
    let restoringBackend: BackendID?
    let snapshot: StudyWorkspaceSnapshot
    var staged: [iOSNavigationManager.ReaderTab] = []
    var freshlyHydratedIDs: Set<UUID> = []

    init(target: StudyTabGroup, requested: UUID?, desiredBackend: BackendID,
         documents: [ReaderDocumentTab], retained: [iOSNavigationManager.ReaderTab],
         previousTabs: [iOSNavigationManager.ReaderTab], previousActive: UUID?,
         previousBackend: BackendID, previousGroup: UUID?, previousGeneration: UInt64,
         previousSelection: StudySceneSelection?, restoringBackend: BackendID?,
         snapshot: StudyWorkspaceSnapshot) {
        self.target = target; self.requested = requested; self.desiredBackend = desiredBackend
        self.documents = documents; self.retained = retained; self.previousTabs = previousTabs
        self.previousActive = previousActive; self.previousBackend = previousBackend
        self.previousGroup = previousGroup; self.previousGeneration = previousGeneration
        self.previousSelection = previousSelection; self.restoringBackend = restoringBackend
        self.snapshot = snapshot
    }
}
