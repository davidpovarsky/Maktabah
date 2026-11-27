import Foundation

@MainActor final class OriginalStateStorage { var blocked = false }
@MainActor struct OriginalStateBoundary {
    let session: MaktabahNativeSceneSession; let owner: UUID
    private let state = OriginalStateStorage()
    var blocked: Bool { get { state.blocked } nonmutating set { state.blocked = newValue } }
    var nativeRoutingSession: MaktabahNativeSceneSession? { session }
    var nativeRoutingOwner: UUID { owner }
    init(_ session:MaktabahNativeSceneSession,owner:UUID=UUID()){self.session=session;self.owner=owner}
    func attach(){let state=self.state; session.observeAnnotationPresentation(owner:owner){state.blocked}}
    func publish(_ value:Bool){let state=self.state; nativeModalBinding(Binding(get:{state.blocked},set:{state.blocked=$0})).wrappedValue=value}
private func nativeModalWillChange() {
        nativeRoutingSession?.originalAnnotationPresentationWillChange(owner: nativeRoutingOwner)
    }
private func nativeModalBinding<Value>(_ original: Binding<Value>) -> Binding<Value> {
        Binding(get: { original.wrappedValue }, set: { value in
            nativeModalWillChange(); original.wrappedValue = value
        })
    }
}
@main struct Controls {
    @MainActor static func main() {
        var passed = 0; var failed = 0
        func check(_ name: String, _ body: () throws -> Bool) {
            if CommandLine.arguments.count > 1 && !name.contains(CommandLine.arguments[1]) { return }
            do { if try body() { passed += 1; print("PASS \(name)") } else { failed += 1; print("FAIL \(name)") } }
            catch { failed += 1; print("FAIL \(name): \(error)") }
        }
        func rejects(_ body: () throws -> Void) -> Bool { do { try body(); return false } catch { return true } }
        check("actual caller allows stable absent Annotations owner") {
            let s=MaktabahNativeSceneSession(); let p=try s.captureHistoryReaderWindow(); try p(); return true
        }
        check("actual caller allows stable original Annotations owner") {
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
            let p=try s.captureHistoryReaderWindow(); s.originalAnnotationPresentationWillChange(owner:UUID()); try p(); return true
        }
        check("wrong owner disappearance does not remove exact owner") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach()
            let p=try s.captureHistoryReaderWindow(); s.removeAnnotationPresentation(owner:UUID()); try p()
            return s.fixtureOwner == state.owner
        }
        check("actual will callback detects original Annotations open-close ABA") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach()
            let p=try s.captureHistoryReaderWindow(); state.publish(true); state.publish(false); return rejects(p)
        }
        check("actual will callback detects equal original State publication") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach()
            let p=try s.captureHistoryReaderWindow(); state.publish(false); return rejects(p)
        }
        check("actual observe callback detects owner A-B-A") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach()
            let p=try s.captureHistoryReaderWindow(); s.observeAnnotationPresentation(owner:UUID()){false}; state.attach(); return rejects(p)
        }
        check("actual disappearance and same-owner return remain retired") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach()
            let p=try s.captureHistoryReaderWindow(); s.removeAnnotationPresentation(owner:state.owner); state.attach(); return rejects(p)
        }
        check("actual caller rejects already blocked original presentation") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach(); state.publish(true)
            return rejects { _=try s.captureHistoryReaderWindow() }
        }
        check("blocker callback cannot publish equal State then return false") {
            let s=MaktabahNativeSceneSession(); let owner=UUID(); var armed=false
            s.observeAnnotationPresentation(owner:owner) { if armed { armed=false; s.originalAnnotationPresentationWillChange(owner:owner) }; return false }
            let p=try s.captureHistoryReaderWindow(); armed=true; return rejects(p)
        }
        check("blocker callback cannot replace owner A-B-A then return false") {
            let s=MaktabahNativeSceneSession(); let owner=UUID(); var armed=false
            s.observeAnnotationPresentation(owner:owner) { if armed { armed=false; s.observeAnnotationPresentation(owner:UUID()){false}; s.observeAnnotationPresentation(owner:owner){false} }; return false }
            let p=try s.captureHistoryReaderWindow(); armed=true; return rejects(p)
        }
        check("will metadata is revoked before original entry callback") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach(); let p=try s.captureHistoryReaderWindow()
            var rejected=false; s.fixtureOnEntry { if $0 == "will" { rejected=rejects(p) } }; state.publish(false); return rejected
        }
        check("owner replacement is revoked before original retirement callback") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach(); let p=try s.captureHistoryReaderWindow()
            var rejected=false; s.fixtureOnRetire { rejected=rejects(p) }; s.observeAnnotationPresentation(owner:UUID()){false}; return rejected
        }
        check("disappearance is revoked before original retirement callback") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach(); let p=try s.captureHistoryReaderWindow()
            var rejected=false; s.fixtureOnRetire { rejected=rejects(p) }; s.removeAnnotationPresentation(owner:state.owner); return rejected
        }
        check("full original unmount revokes before its FIRST retirement callback") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach(); let p=try s.captureHistoryReaderWindow()
            var rejected=false; s.fixtureOnFirstUnmount { rejected=rejects(p) }; s.unmount(); return rejected && rejects(p)
        }
        check("publication exhaustion is terminal across later original callbacks") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach(); s.fixtureSeedRevision(UInt64.max)
            let p=try s.captureHistoryReaderWindow(); state.publish(false); state.attach(); s.removeAnnotationPresentation(owner:state.owner); state.attach()
            return s.fixtureRevision == nil && rejects(p) && rejects { _=try s.captureHistoryReaderWindow() }
        }
        check("actual caller retains Annotations history BEFORE window capture callback") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach()
            s.fixtureOnWindowRetain { state.publish(true); state.publish(false) }
            return rejects { _=try s.captureHistoryReaderWindow() }
        }
        check("actual caller rechecks Annotations AFTER final window callback") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach(); let p=try s.captureHistoryReaderWindow()
            var armed=true; s.fixtureOnWindowValidate { if armed { armed=false; state.publish(false) } }; return rejects(p)
        }
        check("actual caller rechecks Annotations AFTER original readiness callback") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach(); let p=try s.captureHistoryReaderWindow()
            var armed=true; s.fixtureOnReadiness { if armed { armed=false; state.publish(false) } }; return rejects(p)
        }
        check("closed RN latch invalidates before original modal callback") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach()
            let proof=NativeComponentSourceObservation(publications:[s.originalAnnotationPresentationPublication]) {}
            var rejected=false; s.fixtureOnEntry { _ in rejected = !proof.claimIfCurrent { true } }
            state.publish(false); return rejected
        }
        check("closed RN latch registration precedes reentrant initial getter") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach()
            let proof=NativeComponentSourceObservation(publications:[s.originalAnnotationPresentationPublication]) { state.publish(false) }
            return rejects { try proof.validate() }
        }
        check("blocked original disappearance preserves its actual modal owner") {
            let s=MaktabahNativeSceneSession(); let state=OriginalStateBoundary(s); state.attach(); state.publish(true)
            s.removeAnnotationPresentation(owner:state.owner)
            return s.fixtureOwner == state.owner && rejects { _=try s.captureHistoryReaderWindow() }
        }
        check("removal blocker callback cannot clear a replacement owner") {
            let s=MaktabahNativeSceneSession(); let first=UUID(), second=UUID(); var armed=false
            s.observeAnnotationPresentation(owner:first) { if armed { armed=false; s.observeAnnotationPresentation(owner:second){false} }; return false }
            armed=true; s.removeAnnotationPresentation(owner:first)
            return s.fixtureOwner == second
        }
        print("RESULT passed=\(passed) failed=\(failed)")
        if failed > 0 { exit(1) }
    }
}

