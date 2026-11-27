import Foundation
import OtzariaUIRouting

@MainActor final class EditorSceneFixture {
    let editor = EditorFixture()
    let session = MaktabahNativeSceneSession()
    var blocked = true
    init() {
        session.annotationEditorControls=editor.owner
        attach()
    }
    func attach() {
        session.observeAnnotationPresentation(owner: editor.listOwner) { [unowned self] in self.blocked }
    }
    func publish(_ value: Bool) {
        session.originalAnnotationPresentationWillChange(owner: editor.listOwner)
        blocked=value
    }
    func capture() throws -> @MainActor () throws -> Void { try session.fixtureCaptureEditor(editor.listOwner) }
}
@main struct EditorSceneControlRunner {
    @MainActor static func main() throws {
        let cases: [(String, @MainActor () throws -> Void)] = [
            ("exact warm editor uses original root fence with no focus or data effect", {
                let f=EditorSceneFixture();let proof=try f.capture();try proof()
                try expect(f.editor.body.focusCalls == 0 && f.editor.scrolls == 0, "read-only retained root")
            }),
            ("existing History no-argument entry still refuses editor modal", {
                let f=EditorSceneFixture()
                try refuses({ _=try f.session.captureHistoryReaderWindow() }, "old entry must not borrow editor allowance")
            }),
            ("existing History no-argument entry still allows absent modal", {
                let s=MaktabahNativeSceneSession();let proof=try s.captureHistoryReaderWindow();try proof()
            }),
            ("warm editor cannot borrow a foreign original List owner", {
                let f=EditorSceneFixture()
                try refuses({ _=try f.session.fixtureCaptureEditor(UUID()) }, "wrong source owner")
            }),
            ("wrong original modal publisher does not retire exact editor", {
                let f=EditorSceneFixture();let proof=try f.capture()
                f.session.originalAnnotationPresentationWillChange(owner:UUID());try proof()
            }),
            ("equal original modal publication retires before original callback", {
                let f=EditorSceneFixture();let proof=try f.capture();var retiredBeforeCallback=false
                f.session.fixtureEntryCallback { retiredBeforeCallback=(try? proof()) == nil }
                f.publish(true);try expect(retiredBeforeCallback, "actual original callback saw stale proof")
                try refuses(proof,"equal publication cannot rearm")
            }),
            ("original owner A B A cannot revive warm editor", {
                let f=EditorSceneFixture();let proof=try f.capture()
                f.session.observeAnnotationPresentation(owner:UUID()){true};f.attach()
                try refuses(proof,"owner ABA")
            }),
            ("blocker callback publication cannot return a current owner", {
                let f=EditorSceneFixture();let proof=try f.capture();var armed=true
                f.session.observeAnnotationPresentation(owner:f.editor.listOwner) {
                    if armed {armed=false;f.publish(true)};return true
                }
                try refuses(proof,"blocker callback reentry")
            }),
            ("editor getter callback publication cannot restore same values", {
                let f=EditorSceneFixture();let proof=try f.capture()
                f.editor.onSnapshot={f.editor.onSnapshot=nil;f.publish(true)}
                try refuses(proof,"actual editor snapshot callback")
            }),
            ("modal source is retained before original window capture", {
                let f=EditorSceneFixture();f.session.onWindowRetain={f.publish(false);f.publish(true)}
                try refuses({_ = try f.capture()},"original window callback ABA")
            }),
            ("modal source is rechecked after final original window callback", {
                let f=EditorSceneFixture();let proof=try f.capture();var armed=true
                f.session.originalWindow.onValidate={if armed {armed=false;f.publish(true)}}
                try refuses(proof,"late original window callback")
            }),
            ("editor source preserves original root mode and mapping restrictions", {
                let f=EditorSceneFixture();let proof=try f.capture()
                f.session.bindings.rootPublications?.selectionRevision=1
                f.session.bindings.selectedTab.wrappedValue = .viewer
                f.session.bindings.selectedTab.wrappedValue = .annotations
                f.session.bindings.rootPublications?.selectionRevision=2
                try refuses(proof,"root selection ABA")
            }),
            ("original Search modal ABA remains foreign to editor", {
                let f=EditorSceneFixture();let search=UUID()
                f.session.observeSearchPresentation(owner:search){false};let proof=try f.capture()
                f.session.originalSearchPresentationWillChange(owner:search)
                f.session.originalSearchPresentationWillChange(owner:search)
                try refuses(proof,"foreign Search publication")
            }),
            ("original Workspace publication is one-way across equal final values", {
                let f=EditorSceneFixture();let proof=try f.capture();f.session.fixtureWorkspaceABA()
                try refuses(proof,"foreign Workspace observation")
            }),
            ("annotation modal revision exhaustion stays unavailable", {
                let f=EditorSceneFixture();f.session.fixtureRevision(.max);let proof=try f.capture()
                f.publish(true);f.attach()
                try expect(f.session.fixtureCurrentRevision == nil, "terminal exhausted counter")
                try refuses(proof,"no revival after exhaustion")
                try refuses({_ = try f.capture()},"no new capture after exhaustion")
            }),
            ("actual original onCreated equal field callback retires before forwarding", {
                let f=EditorFixture();try f.retain(.body)
                var hook=ActualOriginalEditorCreated(nativeControls:f.attachment,viewID:f.viewID)
                hook.editorTextView=f.body;var rejectedBeforeForwarding=false
                hook.onNativeTextView={field in
                    rejectedBeforeForwarding = field === f.body && (try? f.owner.validateSource(requestID:f.request)) == nil
                }
                hook.created()(f.body)
                try expect(rejectedBeforeForwarding && hook.editorTextView === f.body,"equal original field assignment must invalidate first")
            }),
            ("default nil original onCreated assignment and forwarding stay unchanged", {
                let f=EditorFixture();var calls=0
                var hook=ActualOriginalEditorCreated(nativeControls:nil,viewID:f.viewID)
                hook.onNativeTextView={field in if field === f.body { calls += 1 } }
                hook.created()(f.body)
                try expect(calls == 1 && hook.editorTextView === f.body,"default original callback")
            })
        ]
        let selected=ProcessInfo.processInfo.environment["EDITOR_CONTROL_FILTER"]
        var passed=0,failed=0
        for (name,body) in cases where selected == nil || name == selected {
            do { try body();passed += 1;print("PASS \(name)") }
            catch { failed += 1;print("FAIL \(name): \(error)") }
        }
        print("RESULT passed=\(passed) failed=\(failed) scope=actual-Session-window-modal-caller-and-onCreated-with-explicit-app-boundaries")
        if failed != 0 { throw ControlFailure.expected("\(failed) source controls failed") }
    }
}
