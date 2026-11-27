import Foundation

// Explicit app/UIKit/store boundaries, held constant except the named callback
// under test. The extracted Session methods below are original source bytes.
enum UIRouteErrorCode { case unavailable, staleState }
struct UIRouteError: Error {
    let code: UIRouteErrorCode; let message: String
    init(_ code: UIRouteErrorCode, _ message: String) { self.code = code; self.message = message }
}
struct UIStableID { let rawValue: String }
enum Mode { case viewer, search }
enum Tab { case viewer, search
    var canonical: Self { self }
    var appMode: Mode { self == .viewer ? .viewer : .search }
}
@MainActor final class MutableValue<Value> { var wrappedValue: Value; init(_ value: Value) { wrappedValue = value } }
@MainActor final class RootPublications { var selectionRevision: UInt64? = 0; var settingsRevision: UInt64? = 0 }
@MainActor final class Reader { var isPopoverPresented = false; var readerInspectorVisible = false }
@MainActor final class Manager {
    var openTabs: [Int] = []; var activeTabId: Int?; var selectedBook: Int?
    var selectedContentId: Int?; var currentMode = Mode.viewer
    var selectedBookForInfo: Int?; var showingTabsList = false; var alertMessage: String?
    var activeReaderViewModel: Reader?; var nativeModePresentationRevision: UInt64? = 0
    var selectedBookPresentationRevision: UInt64? = 0
}
@MainActor final class Bindings {
    let manager = Manager(); let showSettings = MutableValue(false)
    var rootPublications: RootPublications? = RootPublications(); let selectedTab = MutableValue(Tab.viewer)
    var onReady: (() -> Void)?
    var isPresentationReady: Bool { onReady?(); return true }
}
enum Coverage { case liveNativeSetters }
enum Phase { case available }
struct MappingEvent { let phase = Phase.available; let epoch: UInt64 = 1 }
@MainActor final class MappingOwner { let event = MappingEvent() }
struct Mapping {
    let coverage = Coverage.liveNativeSetters; let scene: String; let owner: ObjectIdentifier
    let source: MappingOwner; let epoch: UInt64 = 1; let projection = 7
}
@MainActor final class Workspace {
    var attached = true; var isSwitching = false; let mappingOwnershipSource = MappingOwner()
    let manager: Manager
    init(_ manager: Manager) { self.manager = manager }
    func mappingOwnershipObservation() -> Mapping? {
        Mapping(scene: "scene", owner: ObjectIdentifier(manager), source: mappingOwnershipSource)
    }
}
@MainActor final class WorkspaceSource {
    let workspace: Workspace; var isAuthoritative = true
    init(_ manager: Manager) { workspace = Workspace(manager) }
    func read() throws -> Workspace? { workspace }
}
@MainActor final class DonationManager { static let shared = DonationManager(); var showDonationSheet = false }
@MainActor final class MaktabahNativeComponentSourceObservation {
    init(read: () -> Void) { read() }
    func validate() throws { } // Explicit constant original model/backend boundary.
}
@MainActor final class OriginalWindow {
    var onValidate: (() -> Void)?
    func validate() throws -> Int { onValidate?(); return 1 }
}
@MainActor final class CallbackOwner {
    var onCall: ((String) -> Void)?
    func retire() { onCall?("retire") }
    func unmount() { onCall?("unmount") }
    func release() { onCall?("release") }
    func revoke() { onCall?("revoke") }
    func invalidate() { onCall?("invalidate") }
    func retirePresentation() { onCall?("retirePresentation") }
    func detachNativeRoutingSession(_ session: AnyObject) { onCall?("detachNativeRoutingSession") }
    func observeOriginalPresentation(owner: UUID) { onCall?("observe") }
    func originalPresentationWillChange(owner: UUID) { onCall?("will") }
    func originalPresentationDidDisappear(owner: UUID) { onCall?("disappear") }
    func originalForeignStateWillChange() { onCall?("foreignWill") }
}
@MainActor final class Directory { func unmount(_ lease: Int) {} }

