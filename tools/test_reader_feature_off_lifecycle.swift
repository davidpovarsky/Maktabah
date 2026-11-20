import Foundation

// FLAG_SOURCE

@MainActor enum MaktabahApp { static var isIpad = true }
@MainActor enum Effects {
    static var sidecar: URL!
    static var stores = 0, restores = 0, attaches = 0, synchronizes = 0
    static func reset() { stores = 0; restores = 0; attaches = 0; synchronizes = 0 }
}
@MainActor final class iOSNavigationManager {
    func restoreSessionIfNeeded() { Effects.restores += 1 }
}
@MainActor struct StudyWorkspaceStore {
    static func forCurrentProcess() -> Self { Effects.stores += 1; return .init() }
}
@MainActor final class StudyWorkspaceNavigationAdapter {
    init(sceneID: String, store: StudyWorkspaceStore) {}
    func attach(_ manager: iOSNavigationManager) async {
        Effects.attaches += 1
        try! Data("unexpected attach write".utf8).write(to: Effects.sidecar)
    }
    func synchronize(_ manager: iOSNavigationManager) {
        Effects.synchronizes += 1
        try! Data("unexpected checkpoint write".utf8).write(to: Effects.sidecar)
    }
}
@MainActor final class MaktabahNativeWorkspaceOwner {
    var current: StudyWorkspaceNavigationAdapter?
    func replace(with value: StudyWorkspaceNavigationAdapter) throws { current = value }
}
@MainActor final class OriginalLifecycle {
    let manager = iOSNavigationManager()
    let workspaceOwner = MaktabahNativeWorkspaceOwner()
    var compactWorkspaceOwner: MaktabahNativeWorkspaceOwner?
    var sceneID = "actual-scene-owned-fixture"
    var workspace: StudyWorkspaceNavigationAdapter? {
        // WORKSPACE_SOURCE
    }
    var routingOwner: MaktabahNativeWorkspaceOwner? {
        // OWNER_SOURCE
    }
    func observesIPadScene() -> Bool {
        // OBSERVER_CONDITION
    }
    func task() async {
        // TASK_SOURCE
    }
    func tabsChanged() {
        // TABS_CALLBACK_SOURCE
    }
}

@main struct Run {
    @MainActor static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("otzaria-feature-off-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        Effects.sidecar = directory.appendingPathComponent("owned-sidecar.json")
        let defaults = UserDefaults.standard
        let originalArguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        defer {
            defaults.removeVolatileDomain(forName: UserDefaults.argumentDomain)
            defaults.setVolatileDomain(originalArguments, forName: UserDefaults.argumentDomain)
        }
        func flag(_ value: Bool?) {
            defaults.removeVolatileDomain(forName: UserDefaults.argumentDomain)
            defaults.setVolatileDomain(value.map { ["ChavrusaTextFaithfulReaderUIEnabled": $0] } ?? [:],
                                       forName: UserDefaults.argumentDomain)
        }
        var results: [[String: Any]] = []
        func require(_ name: String, _ pass: Bool) { results.append(["name": name, "passed": pass]) }
        @MainActor func fresh(enabled: Bool?, ipad: Bool = true, existing: Data? = nil) throws -> OriginalLifecycle {
            flag(enabled); MaktabahApp.isIpad = ipad; Effects.reset()
            if FileManager.default.fileExists(atPath: Effects.sidecar.path) { try FileManager.default.removeItem(at: Effects.sidecar) }
            if let existing { try existing.write(to: Effects.sidecar) }
            return OriginalLifecycle()
        }
        flag(nil); require("Unset flag preserves the original enabled default", ChavrusaTextReaderUI.isEnabled)
        flag(false); require("Explicit false is read from real Foundation UserDefaults", !ChavrusaTextReaderUI.isEnabled)
        flag(true); require("Explicit true is read from real Foundation UserDefaults", ChavrusaTextReaderUI.isEnabled)

        let disabled = try fresh(enabled: false)
        await disabled.task()
        require("Disabled iPad never constructs a store or attaches/restores", Effects.stores == 0 && Effects.attaches == 0 && Effects.restores == 0)
        require("Disabled fresh launch creates no owned sidecar", !FileManager.default.fileExists(atPath: Effects.sidecar.path))
        require("Disabled lifecycle exposes no routing workspace owner", disabled.routingOwner == nil)
        require("Disabled lifecycle mounts no iPad identity/checkpoint observers", !disabled.observesIPadScene())

        let original = Data("original workspace — שימור נתונים\n".utf8)
        let preserved = try fresh(enabled: false, existing: original)
        await preserved.task()
        require("Disabled startup leaves existing workspace bytes unchanged", try Data(contentsOf: Effects.sidecar) == original)

        let enabled = try fresh(enabled: true)
        await enabled.task()
        require("Enabled iPad creates and attaches exactly one original lifecycle owner", Effects.stores == 1 && Effects.restores == 1 && Effects.attaches == 1 && enabled.workspaceOwner.current != nil)
        require("Enabled lifecycle exposes that exact original owner", enabled.routingOwner === enabled.workspaceOwner)
        require("Enabled lifecycle retains scene/checkpoint observers", enabled.observesIPadScene())
        await enabled.task()
        require("Existing owner prevents duplicate restore/store/attach", Effects.stores == 1 && Effects.attaches == 1 && Effects.restores == 1)

        let empty = try fresh(enabled: true); empty.sceneID = ""
        await empty.task()
        require("Missing scene identity cannot create or attach a store", Effects.stores == 0 && Effects.attaches == 0)

        let phone = try fresh(enabled: true, ipad: false)
        phone.compactWorkspaceOwner = MaktabahNativeWorkspaceOwner()
        await phone.task()
        require("iPhone never creates a second iPad store", Effects.stores == 0 && Effects.attaches == 0)
        require("iPhone exposes only its existing compact owner", phone.routingOwner === phone.compactWorkspaceOwner)

        let retained = try fresh(enabled: false, existing: original)
        retained.workspaceOwner.current = StudyWorkspaceNavigationAdapter(sceneID: retained.sceneID, store: .init())
        retained.tabsChanged()
        let afterDisabledCallback = try Data(contentsOf: Effects.sidecar)
        require("Disabled callbacks cannot checkpoint a retained adapter", Effects.synchronizes == 0 && afterDisabledCallback == original)
        require("Disabled workspace getter does not expose a retained adapter", retained.workspace == nil)

        Effects.synchronizes = 0 // Independent positive control after the disabled callback.
        flag(true)
        retained.tabsChanged()
        let afterEnabledCallback = try Data(contentsOf: Effects.sidecar)
        require("Enabled callback still checkpoints the exact retained owner", Effects.synchronizes == 1 && afterEnabledCallback != original)

        let failed = results.filter { $0["passed"] as? Bool == false }.count
        let report: [String: Any] = ["tests": results.count, "passed": results.count - failed, "failed": failed,
                                     "cases": results, "native_ui_executed": 0]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    }
}
