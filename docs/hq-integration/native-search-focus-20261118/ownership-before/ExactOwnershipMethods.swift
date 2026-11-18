import Foundation

// Deliberately explicit boundary doubles. These tests execute the exact four
// original app ownership methods; no UIKit drawing, responder, scene directory
// or Core permission implementation is replaced in the app itself.
@MainActor final class UISearchTextField {}
@MainActor final class PresentationBoundary {
    var revocations = 0
    func revoke() { revocations += 1 }
}
@MainActor final class NativeFieldOwnerBoundary {
    weak var nativeSearchField: UISearchTextField?
    var retainedSearchField: UISearchTextField?
    var searchFieldUpdateScheduled = false
    var searchFieldRevision: UInt64 = 0
    var directoryRevision: UInt64 = 0
    let presentation = PresentationBoundary()
    func nativeStateChanged() throws { directoryRevision += 1 }

        func attachSearchField(_ field: UISearchTextField) {
        guard nativeSearchField !== field else { return }
        if retainedSearchField != nil { presentation.revoke() }
        nativeSearchField = field
        searchFieldStateDidChange(field)
    }

    func detachSearchField(_ field: UISearchTextField) {
        guard nativeSearchField === field else { return }
        if retainedSearchField === field { presentation.revoke() }
        nativeSearchField = nil
        scheduleSearchFieldObservation()
    }

    func searchFieldStateDidChange(_ field: UISearchTextField) {
        guard nativeSearchField === field else { return }
        scheduleSearchFieldObservation()
    }

    private func scheduleSearchFieldObservation() {
        // UIKit attachment can happen inside updateUIView. Publish the graph
        // invalidation on the next MainActor turn, but always re-read UIKit
        // synchronously when validating or completing the original command.
        guard !searchFieldUpdateScheduled else { return }
        searchFieldUpdateScheduled = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            searchFieldUpdateScheduled = false
            searchFieldRevision &+= 1
            try? nativeStateChanged()
        }
    }


}

@main struct NativeSearchFieldOwnerAcceptance {
    @MainActor static func main() async {
        var checks: [(String, Bool)] = []
        let owner = NativeFieldOwnerBoundary(), a = UISearchTextField(), b = UISearchTextField()
        owner.attachSearchField(a)
        checks.append(("attach_revokes_before_return", owner.directoryRevision == 1))
        let attached = owner.directoryRevision
        owner.attachSearchField(a)
        checks.append(("same_owner_update_is_passive", owner.directoryRevision == attached))
        owner.detachSearchField(b)
        checks.append(("foreign_detach_is_passive", owner.directoryRevision == attached))
        owner.attachSearchField(b); owner.attachSearchField(a)
        checks.append(("aba_is_visible_before_swiftui_turn", owner.directoryRevision == attached + 2))
        owner.searchFieldStateDidChange(b)
        checks.append(("foreign_callback_is_passive", owner.directoryRevision == attached + 2))
        let beforeChange = owner.directoryRevision
        owner.searchFieldStateDidChange(a)
        checks.append(("current_native_callback_revokes_before_return", owner.directoryRevision == beforeChange + 1))
        owner.retainedSearchField = a
        let beforeReplace = owner.directoryRevision
        owner.attachSearchField(b)
        checks.append(("retained_owner_replacement_revokes_immediately", owner.presentation.revocations == 1 && owner.directoryRevision == beforeReplace + 1))
        owner.retainedSearchField = b
        let beforeDetach = owner.directoryRevision
        owner.detachSearchField(b)
        checks.append(("retained_owner_detach_revokes_immediately", owner.presentation.revocations == 2 && owner.directoryRevision == beforeDetach + 1 && owner.nativeSearchField == nil))
        let afterSynchronous = owner.directoryRevision
        // Await only after the race assertions. MainActor callbacks are the real
        // language runtime; this is not a scripted "next tick" implementation.
        while owner.searchFieldUpdateScheduled { await Task.yield() }
        checks.append(("swiftui_graph_refresh_does_not_defer_or_repeat_authority", owner.directoryRevision == afterSynchronous && owner.searchFieldRevision == 1))
        for (name, passed) in checks { print("\(passed ? "PASS" : "FAIL") \(name)") }
        print("TOTAL \(checks.count) PASS \(checks.filter(\.1).count) FAIL \(checks.filter { !$0.1 }.count)")
        if checks.contains(where: { !$0.1 }) { exit(1) }
    }
}
