import Foundation
import Observation
import OtzariaUIRouting
import ChavrusaUIRoutingHost

// Explicit original app-domain boundaries for the extracted Session source.
// The test does not construct a real UIKit scene/Store/Core grant.
enum EditorSceneMode { case annotations, viewer }
enum EditorSceneTab { case annotations, viewer
    var canonical: Self { self }
    var appMode: EditorSceneMode { self == .annotations ? .annotations : .viewer }
}
@MainActor final class EditorSceneValue<T> { var wrappedValue: T; init(_ value: T) { wrappedValue=value } }
@MainActor final class EditorSceneRoot { var selectionRevision: UInt64? = 0; var settingsRevision: UInt64? = 0 }
@Observable @MainActor final class EditorSceneReader { var isPopoverPresented = false; var readerInspectorVisible = false }
@Observable @MainActor final class EditorSceneManager {
    var openTabs: [Int] = []; var activeTabId: Int?; var selectedBook: Int?
    var selectedContentId: Int?; var currentMode = EditorSceneMode.annotations
    var selectedBookForInfo: Int?; var showingTabsList = false; var alertMessage: String?
    var activeReaderViewModel: EditorSceneReader?
    @ObservationIgnored var nativeModePresentationRevision: UInt64? = 0
    @ObservationIgnored var selectedBookPresentationRevision: UInt64? = 0
}
@MainActor final class EditorSceneBindings {
    let manager = EditorSceneManager(); let showSettings = EditorSceneValue(false)
    var rootPublications: EditorSceneRoot? = EditorSceneRoot()
    let selectedTab = EditorSceneValue(EditorSceneTab.annotations)
    var onReady: (() -> Void)?; var ready = true
    var isPresentationReady: Bool { onReady?(); return ready }
}
enum EditorCoverage { case liveNativeSetters }
enum EditorPhase { case available }
struct EditorMappingEvent { let phase = EditorPhase.available; let epoch: UInt64 = 1 }
@Observable @MainActor final class EditorMappingOwner { var event = EditorMappingEvent() }
struct EditorMapping {
    let coverage = EditorCoverage.liveNativeSetters; let scene = "editor-scene"
    let owner: ObjectIdentifier; let source: EditorMappingOwner
    let epoch: UInt64 = 1; let projection = 7
}
@Observable @MainActor final class EditorSceneWorkspace {
    var attached = true; var isSwitching = false
    let mappingOwnershipSource = EditorMappingOwner(); let manager: EditorSceneManager
    init(_ manager: EditorSceneManager) { self.manager=manager }
    func mappingOwnershipObservation() -> EditorMapping? { .init(owner:ObjectIdentifier(manager), source:mappingOwnershipSource) }
}
@MainActor final class EditorSceneWorkspaceSource {
    let workspace: EditorSceneWorkspace; var isAuthoritative = true
    init(_ manager: EditorSceneManager) { workspace=EditorSceneWorkspace(manager) }
    func read() throws -> EditorSceneWorkspace? { workspace }
}
@Observable @MainActor final class DonationManager { static let shared=DonationManager(); var showDonationSheet = false }
@MainActor final class EditorSceneWindow {
    var onValidate: (() -> Void)?; var valid = true
    func validate() throws -> Int {
        onValidate?(); guard valid else { throw ControlFailure.expected("explicit window boundary retired") }; return 1
    }
}
@Observable @MainActor final class EditorForeignPresentation {
    var originalStateRevision: UInt64? = 0; var presentationFacets = 0
    var isRequestedOrMounted = false
}
@MainActor final class EditorSceneCallback {
    var onCall: (() -> Void)?
    func retire() { onCall?() }
    func originalModalWillChange(owner: UUID) { onCall?() }
    func observeOriginalPresentation(owner: UUID) { onCall?() }
    func originalPresentationWillChange(owner: UUID) { onCall?() }
    func originalPresentationDidDisappear(owner: UUID) { onCall?() }
    func originalForeignStateWillChange() { onCall?() }
}
@MainActor final class EditorSceneNote { var current: Annotation?; var presentationActive = false }
@MainActor final class OriginalEditorStateStorage<T> { var value: T; init(_ value: T) { self.value=value } }
@MainActor @propertyWrapper struct OriginalEditorState<T> {
    let storage: OriginalEditorStateStorage<T>
    init(wrappedValue: T) { storage = .init(wrappedValue) }
    var wrappedValue: T { get { storage.value } nonmutating set { storage.value = newValue } }
}
