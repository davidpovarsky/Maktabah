import Foundation

@MainActor final class OriginalStateBoundary {
    // Domain fixture for the original Bool. Calls the actual original Session
    // pre-mutation callback before every publication, including equal writes.
    let session: MaktabahNativeSceneSession; let owner: UUID; var blocked = false
    init(_ session: MaktabahNativeSceneSession, owner: UUID = UUID()) { self.session = session; self.owner = owner }
    func attach() { session.observeSearchPresentation(owner: owner) { [weak self] in self?.blocked ?? true } }
    func publish(_ value: Bool) { session.originalSearchPresentationWillChange(owner: owner); blocked = value }
}
@main struct Controls {
    @MainActor static func main() {
        var passed = 0; var failed = 0
        func check(_ name: String, _ body: () throws -> Bool) {
            do { if try body() { passed += 1; print("PASS \(name)") } else { failed += 1; print("FAIL \(name)") } }
            catch { failed += 1; print("FAIL \(name): \(error)") }
        }
        func rejects(_ body: () throws -> Void) -> Bool { do { try body(); return false } catch { return true } }
        check("actual caller allows stable absent Search owner") {
            let s=MaktabahNativeSceneSession(); let p=try s.captureHistoryReaderWindow(); try p(); return true
        }
        check("actual caller allows stable original Search owner") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach()
            let p=try s.captureHistoryReaderWindow(); try p(); return true
        }
        check("same-owner original observation preserves a stable proof") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach()
            let p=try s.captureHistoryReaderWindow(); let before=s.fixtureRevision; state.attach(); try p()
            return before == s.fixtureRevision
        }
        check("wrong owner State notification does not revoke exact owner") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach()
            let p=try s.captureHistoryReaderWindow(); s.originalSearchPresentationWillChange(owner:UUID()); try p(); return true
        }
        check("wrong owner disappearance does not remove exact owner") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach()
            let p=try s.captureHistoryReaderWindow(); s.removeSearchPresentation(owner:UUID()); try p()
            return s.fixtureOwner == state.owner
        }
        check("actual will callback detects original Saved open-close ABA") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach()
            let p=try s.captureHistoryReaderWindow(); state.publish(true); state.publish(false); return rejects(p)
        }
        check("actual will callback detects equal original State publication") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach()
            let p=try s.captureHistoryReaderWindow(); state.publish(false); return rejects(p)
        }
        check("actual observe callback detects owner A-B-A") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach()
            let p=try s.captureHistoryReaderWindow(); s.observeSearchPresentation(owner:UUID()){false}; state.attach(); return rejects(p)
        }
        check("actual disappearance and same-owner return remain retired") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach()
            let p=try s.captureHistoryReaderWindow(); s.removeSearchPresentation(owner:state.owner); state.attach(); return rejects(p)
        }
        check("actual caller rejects already blocked original presentation") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach(); state.publish(true)
            return rejects { _=try s.captureHistoryReaderWindow() }
        }
        check("blocker callback cannot publish equal State then return false") {
            let s=MaktabahNativeSceneSession(); let owner=UUID(); var armed=false
            s.observeSearchPresentation(owner:owner) { if armed { armed=false; s.originalSearchPresentationWillChange(owner:owner) }; return false }
            let p=try s.captureHistoryReaderWindow(); armed=true; return rejects(p)
        }
        check("blocker callback cannot replace owner A-B-A then return false") {
            let s=MaktabahNativeSceneSession(); let owner=UUID(); var armed=false
            s.observeSearchPresentation(owner:owner) { if armed { armed=false; s.observeSearchPresentation(owner:UUID()){false}; s.observeSearchPresentation(owner:owner){false} }; return false }
            let p=try s.captureHistoryReaderWindow(); armed=true; return rejects(p)
        }
        check("will metadata is revoked before original entry callback") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach(); let p=try s.captureHistoryReaderWindow()
            var rejected=false; s.fixtureOnEntry { if $0 == "will" { rejected=rejects(p) } }; state.publish(false); return rejected
        }
        check("owner replacement is revoked before original retirement callback") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach(); let p=try s.captureHistoryReaderWindow()
            var rejected=false; s.fixtureOnRetire { rejected=rejects(p) }; s.observeSearchPresentation(owner:UUID()){false}; return rejected
        }
        check("disappearance is revoked before original retirement callback") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach(); let p=try s.captureHistoryReaderWindow()
            var rejected=false; s.fixtureOnRetire { rejected=rejects(p) }; s.removeSearchPresentation(owner:state.owner); return rejected
        }
        check("full original unmount revokes before its FIRST retirement callback") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach(); let p=try s.captureHistoryReaderWindow()
            var rejected=false; s.fixtureOnRetire { rejected=rejects(p) }; s.unmount(); return rejected && rejects(p)
        }
        check("publication exhaustion is terminal across later original callbacks") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach(); s.fixtureSeedRevision(UInt64.max)
            let p=try s.captureHistoryReaderWindow(); state.publish(false); state.attach(); s.removeSearchPresentation(owner:state.owner); state.attach()
            return s.fixtureRevision == nil && rejects(p) && rejects { _=try s.captureHistoryReaderWindow() }
        }
        check("actual caller retains Search history BEFORE window capture callback") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach()
            s.fixtureOnWindowRetain { state.publish(true); state.publish(false) }
            return rejects { _=try s.captureHistoryReaderWindow() }
        }
        check("actual caller rechecks Search AFTER final window callback") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach(); let p=try s.captureHistoryReaderWindow()
            var armed=true; s.fixtureOnWindowValidate { if armed { armed=false; state.publish(false) } }; return rejects(p)
        }
        check("actual caller rechecks Search AFTER original readiness callback") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach(); let p=try s.captureHistoryReaderWindow()
            var armed=true; s.fixtureOnReadiness { if armed { armed=false; state.publish(false) } }; return rejects(p)
        }
        check("original callback order remains unchanged after metadata publication") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach(); var events:[String]=[]
            s.fixtureOnEntry { events.append("entry."+$0) }; s.fixtureOnRetire { events.append("continuation.retire") }
            s.fixtureOnCatalog { events.append("catalog."+$0) }; s.fixtureOnHistory { events.append("history."+$0) }
            state.publish(false)
            return events == ["entry.will","continuation.retire","catalog.retire","history.foreignWill"]
        }
        print("RESULT passed=\(passed) failed=\(failed)")
        if failed > 0 { exit(1) }
    }
}

