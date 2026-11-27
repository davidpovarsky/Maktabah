import Foundation
import Observation
import OtzariaActionCore
import OtzariaUIRouting

// EXPLICIT UI / DOMAIN BOUNDARY. No UIKit, SwiftUI, scene appearance, focus,
// gesture, TextKit or native receipt is simulated as successful here. The
// actual binding, original workspace owner, actual source latch and original
// route DTOs compile over these small storage/context interfaces.
struct BoundaryTransaction {}
struct Binding<Value> {
    private let get: @MainActor () -> Value
    private let set: @MainActor (Value, BoundaryTransaction) -> Void
    @MainActor init(get: @escaping @MainActor () -> Value,
                    set: @escaping @MainActor (Value, BoundaryTransaction) -> Void) { self.get = get; self.set = set }
    @MainActor var wrappedValue: Value { get { get() } nonmutating set { set(newValue, .init()) } }
    func transaction(_ value: BoundaryTransaction) -> Self { self }
}
enum iOSTab { case viewer, history, search }
@MainActor enum MaktabahApp { static var isIpad = true }
@MainActor @Observable final class DonationManager {
    static let shared = DonationManager()
    var showDonationSheet = false
}
@MainActor @Observable final class BoundaryOverview { var blocksRouting = false }
@MainActor final class ReaderSidebarPageCoordinator { let overview = BoundaryOverview() }
enum ActionAppIdentityBridge {
    static func actionBackend(_ value: BackendID) -> ActionBackendID { ActionBackendID(rawValue: value.rawValue)! }
}
@MainActor struct MaktabahNativeSceneBindings {
    let manager: iOSNavigationManager
    let selectedTab: Binding<iOSTab>
    let showSettings: Binding<Bool>
    let sidebar: ReaderSidebarPageCoordinator?
    let rootPublications: MaktabahNativeRootPublicationSource?
}
@MainActor enum MaktabahNativeSceneProjection {
    // ACTUAL_SURFACE_ENUM
}

// ACTUAL_ROOT_PUBLICATION_SOURCE

@MainActor final class GroupBindingFixture {
    let fixture: GroupFixture
    let owner = MaktabahNativeWorkspaceOwner()
    let root = MaktabahNativeRootPublicationSource()
    let sidebar = ReaderSidebarPageCoordinator()
    var tab = iOSTab.viewer
    var settings = false
    var externallyReady = true
    var leaseValid = true
    var originalEffects = 0
    var bindings: MaktabahNativeSceneBindings {
        .init(manager: fixture.manager,
            selectedTab: root.selectionBinding(Binding(get: { [self] in tab }, set: { [self] value, _ in tab = value })),
            showSettings: root.settingsBinding(Binding(get: { [self] in settings }, set: { [self] value, _ in settings = value })),
            sidebar: sidebar, rootPublications: root)
    }
    lazy var source = MaktabahNativeWorkspaceProjectionSource(owner: owner, legacyWorkspace: nil)
    init(empty: Bool = false, warm: Bool = true, profile: Bool = false, foreign: Bool = false,
         qualified: Bool = true, phone: Bool = false, sameGroup: Bool = false) throws {
        MaktabahApp.isIpad = !phone
        DonationManager.shared.showDonationSheet = false
        fixture = try GroupFixture(empty: empty, warm: warm, profile: profile, foreign: foreign,
                                   qualified: qualified, sameGroup: sameGroup)
        try owner.replace(with: fixture.workspace)
    }
    func catalog() throws -> [NativeWorkspaceSelectionIntentService.Selection] {
        try MaktabahNativeWorkspaceSelectionBinding.catalog(sceneID: UIStableID(rawValue: fixture.scene)!,
            manager: fixture.manager, source: source, windowTitle: "Original source-control window")
    }
    func retain(profile: Bool = false) throws -> MaktabahNativeWorkspaceSelectionBinding {
        let kind = profile ? NativeWorkspaceSelectionIntentService.Kind.profile : .group
        let matches = try catalog().filter { $0.kind == kind && $0.groupID == fixture.g2 }
        guard matches.count == 1, let target = matches.first else { throw ControlFailure.expected("fixture target unavailable") }
        return try MaktabahNativeWorkspaceSelectionBinding(requestID: UUID(), target: target,
            bindings: bindings, source: source,
            foreignReady: { [weak self] in
                guard let self else { return false }
                return externallyReady && !settings && !fixture.manager.showingTabsList
                    && fixture.manager.selectedBookForInfo == nil && !DonationManager.shared.showDonationSheet
                    && !sidebar.overview.blocksRouting
            }, readForeignPresentations: {})
    }
    func prepare(_ binding: MaktabahNativeWorkspaceSelectionBinding) async throws {
        try binding.reserve()
        try await binding.prepare { [self] in
            guard leaseValid else { throw ControlFailure.expected("original bounded lifetime expired") }
        }
    }
    func apply(_ binding: MaktabahNativeWorkspaceSelectionBinding) throws {
        try binding.begin { [self] in
            guard leaseValid else { throw ControlFailure.expected("original canonical lifetime expired") }
        }
        try binding.apply()
        originalEffects += 1
    }
    func originalProjection() -> NativeSurfaceState {
        let manager = fixture.manager
        let current = manager.openTabs.first { $0.id == manager.activeTabId }
        let state = UIStateSpec(workspaceID: fixture.workspace.selection.flatMap { UIStableID(rawValue: $0.groupID.uuidString) },
                                profileID: fixture.workspace.selection.flatMap { UIStableID(rawValue: $0.profileID.uuidString) })
        guard let current else {
            return .init(destination: UIDestinationID(rawValue: MaktabahApp.isIpad ? "native.reader.empty" : "native.library")!,
                         presentation: .init(kind: .currentTab), content: nil, state: state, focus: nil)
        }
        let locator = current.book.backendLocator!
        return .init(destination: UIDestinationID(rawValue: "native.reader")!,
            presentation: .init(kind: .currentTab, tabID: UIStableID(rawValue: current.id.uuidString)),
            content: .init(sectionLocator: .init(backend: ActionAppIdentityBridge.actionBackend(locator.backend),
                workKey: locator.workKey, position: .legacyLine(523)), focusLocator: nil, presentationMode: .sameTab),
            state: state, focus: nil)
    }
}
