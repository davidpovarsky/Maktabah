import Foundation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

private struct FixtureFailure: Error { let reason: String }
@main struct NativeIntentMetadataAcceptance {
    @MainActor static func require(_ value: @autoclosure () -> Bool, _ message: String) throws {
        if !value() { throw FixtureFailure(reason: message) }
    }
    @MainActor static func main() async {
        var cases: [(String, @MainActor () async throws -> Void)] = []
        for backend in ActionBackendID.allCases {
            cases.append(("background_root_\(backend.rawValue)", {
                let c = try MaktabahNativeRoutingComposition(backendID: backend)
                let session = try c.mountFixture(foreground: false), q = try c.query()
                let roots = try await q.entities(for: [c.rootID(session)])
                try require(roots.map(\.id) == [c.rootID(session)], "Exact existing window must resolve")
                try require(c.backend.snapshotCalls == 0 && c.contexts.isEmpty && c.nativeEffectCalls == 0, "Metadata cannot issue live foreground authority")
            }))
            cases.append(("foreground_root_\(backend.rawValue)", {
                let c = try MaktabahNativeRoutingComposition(backendID: backend)
                let session = try c.mountFixture(foreground: true), q = try c.query()
                let roots = try await q.entities(for: [c.rootID(session)])
                try require(roots.map(\.id) == [c.rootID(session)], "Stable foreground identity must resolve")
                try require(c.contexts.isEmpty && c.nativeEffectCalls == 0, "No retained grant or native effect")
            }))
            cases.append(("root_identity_survives_background_transition_\(backend.rawValue)", {
                let c = try MaktabahNativeRoutingComposition(backendID: backend)
                let session = try c.mountFixture(foreground: true), q = try c.query()
                c.backend.onNextSnapshot = { try c.setForeground(false, session: session) }
                defer { c.backend.onNextSnapshot = nil }
                do {
                    let roots = try await q.entities(for: [c.rootID(session)])
                    try require(roots.map(\.id) == [c.rootID(session)], "Mounted window remains the same identity after backgrounding")
                } catch {
                    print("OBSERVED \(backend.rawValue) status=\((error as? UIRouteError)?.status.rawValue ?? "unknown") code=\((error as? UIRouteError)?.code ?? "unknown") mounted=\(session.mounted) foreground=\(session.foreground) prepareCalls=\(c.foregroundPreparationCalls) effectCalls=\(c.nativeEffectCalls)")
                    throw error
                }
                // The corrected synchronous metadata path has no async live-UI
                // observation at which to run the injected revocation. Exercise
                // the same original transition immediately after it instead.
                try require(c.backend.snapshotCalls == 0, "Window identity must not enter revocable live discovery")
                try c.setForeground(false, session: session)
                let afterBackground = try await q.entities(for: [c.rootID(session)])
                try require(!session.foreground && afterBackground.map(\.id) == [c.rootID(session)], "The exact existing identity survives the actual original foreground transition")
                try require(c.contexts.isEmpty && c.foregroundPreparationCalls == 0 && c.nativeEffectCalls == 0, "Identity resolution cannot navigate")
            }))
            cases.append(("root_identity_does_not_borrow_busy_ui_admission_\(backend.rawValue)", {
                let c = try MaktabahNativeRoutingComposition(backendID: backend)
                let session = try c.mountFixture(foreground: true), q = try c.query()
                let held = try c.holdOriginalContext(session)
                defer { c.releaseOriginalContext(held, session: session) }
                do {
                    let roots = try await q.entities(for: [c.rootID(session)])
                    try require(roots.map(\.id) == [c.rootID(session)], "An unrelated live UI reservation cannot hide an existing window identity")
                } catch {
                    try require(c.contexts[session.sceneID] == held, "Metadata failure cannot revoke the existing owner's context")
                    print("OBSERVED busy_\(backend.rawValue) status=\((error as? UIRouteError)?.status.rawValue ?? "unknown") code=\((error as? UIRouteError)?.code ?? "unknown") existingContextPreserved=true prepareCalls=\(c.foregroundPreparationCalls) effectCalls=\(c.nativeEffectCalls)")
                    throw error
                }
                try require(c.contexts[session.sceneID] == held && c.backend.snapshotCalls == 0, "Metadata must not borrow or release another operation's admission")
                try require(c.foregroundPreparationCalls == 0 && c.nativeEffectCalls == 0, "Identity metadata cannot request a foreground effect")
            }))
        }
        cases.append(("backend_change_still_refused", {
            let c = try MaktabahNativeRoutingComposition(), s = try c.mountFixture(foreground: true), q = try c.query()
            c.backend.onSynchronousRead = { count in
                if count == 2 { c.backend.value = .init(backend: .otzaria, generation: 2) }
            }
            defer { c.backend.onSynchronousRead = nil }
            do { _ = try await q.entities(for: [c.rootID(s)]); throw FixtureFailure(reason: "Changed source accepted") }
            catch is FixtureFailure { throw FixtureFailure(reason: "Changed source accepted") }
            catch { try require((error as? UIRouteError)?.status == .staleState, "Typed stale source refusal is retained") }
            try require(c.nativeEffectCalls == 0 && c.contexts.isEmpty, "No native effect or leaked context")
        }))
        cases.append(("cancelled_metadata_still_refused", {
            let c = try MaktabahNativeRoutingComposition(), s = try c.mountFixture(foreground: false), q = try c.query()
            let task = Task { @MainActor in try await q.entities(for: [c.rootID(s)]) }
            task.cancel()
            do { _ = try await task.value; throw FixtureFailure(reason: "Cancelled query accepted") }
            catch is CancellationError {}
            try require(c.backend.snapshotCalls == 0 && c.nativeEffectCalls == 0 && c.contexts.isEmpty, "Cancellation precedes optional discovery")
        }))
        cases.append(("two_background_windows_keep_exact_selected_identity", {
            let c = try MaktabahNativeRoutingComposition()
            let a = try c.mountFixture("scene.A", foreground: false), b = try c.mountFixture("scene.B", foreground: false)
            let q = try c.query()
            let all = try await q.suggestedEntities(), selected = try await q.entities(for: [c.rootID(b)])
            try require(Set(all.map(\.id)) == Set([c.rootID(a), c.rootID(b)]), "Existing identities remain distinct")
            try require(selected.map(\.id) == [c.rootID(b)], "No first-window substitution")
            try require(c.nativeEffectCalls == 0 && c.contexts.isEmpty, "No effect while resolving identities")
        }))
        var failed = 0
        for (name, body) in cases {
            do { try await body(); print("PASS \(name)") }
            catch { failed += 1; print("FAIL \(name) :: \(error)") }
        }
        print("TOTAL \(cases.count) FAILED \(failed) NATIVE_EXECUTED 0")
        if failed != 0 { exit(1) }
    }
}
