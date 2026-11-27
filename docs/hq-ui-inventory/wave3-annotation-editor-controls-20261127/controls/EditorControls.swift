import Foundation
import OtzariaUIRouting
import ChavrusaUIRoutingHost

enum ControlFailure: Error { case expected(String) }
@MainActor func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
    if !value() { throw ControlFailure.expected(message) }
}
@MainActor func refuses(_ body: () throws -> Void, _ message: String) throws {
    var rejected = false; do { try body() } catch { rejected = true }
    try expect(rejected, message)
}
@MainActor final class EditorFixture {
    typealias Owner = MaktabahNativeAnnotationEditorControls
    let sceneID = UIStableID(rawValue: "editor-scene")!
    let request = UUID(), viewID = UUID(), listOwner = UUID(), hostToken = UUID()
    let window = UIWindow()
    let form: UIView, body: UITextView, tags: UITextField
    let bodyMarker: UIView, tagsMarker: UIView, styleMarker: UIView
    let bodyToken = UUID(), tagsToken = UUID(), styleToken = UUID()
    var owner: Owner!
    var annotation = Annotation(), note = "draft", tagText = "one,two", color = "yellow"
    var underline = false, initialized = true, allowed = true, blocked = false
    var parentCurrent = true, parentValid = true, windowValid = true, grantValid = true
    var scrolls = 0, tagsFocuses = 0, invalidations = 0
    var onParentCheck: (() -> Void)?, onWindowCheck: (() -> Void)?, onSnapshot: (() -> Void)?
    var onBodyRead: (() -> Void)?, onGrant: (() -> Void)?, onScroll: (() -> Void)?, onTagsFocus: (() -> Void)?
    init(registerTags: Bool = true) {
        form = UIView(window); body = UITextView(window); tags = UITextField(window)
        bodyMarker = UIView(window); tagsMarker = UIView(window); styleMarker = UIView(window)
        owner = Owner(sceneID: sceneID, retainWindow: { [unowned self] in
            MaktabahNativeWindowObservation(window: self.window) { [unowned self] actual in
                self.onWindowCheck?(); return self.windowValid && actual === self.window
            }
        }, retainParent: { [unowned self] actualOwner in
            guard actualOwner == self.listOwner else { throw ControlFailure.expected("wrong original List owner") }
            return { [unowned self] in
                self.onParentCheck?()
                guard self.parentValid else { throw ControlFailure.expected("foreign parent") }
            }
        })
        owner.install(changed: {}, invalidated: { [unowned self] in self.invalidations += 1 })
        owner.attach(access: access, token: hostToken, view: form)
        owner.componentOwner.attach(viewID: viewID, blocked: { [unowned self] in self.blocked },
            componentAvailable: { [unowned self] _ in self.allowed })
        owner.observeControl(viewID: viewID, anchor: .body, token: bodyToken, marker: bodyMarker, field: body)
        if registerTags { owner.observeControl(viewID: viewID, anchor: .tags, token: tagsToken, marker: tagsMarker, field: tags) }
        owner.observeControl(viewID: viewID, anchor: .style, token: styleToken, marker: styleMarker, field: styleMarker)
    }
    var attachment: Owner.Attachment { .init(controls: owner, listOwner: listOwner, parentCurrent: { [unowned self] in self.parentCurrent }) }
    var access: Owner.Access {
        .init(viewID: viewID, attachment: attachment, snapshot: { [unowned self] in
            self.onSnapshot?()
            return .init(annotation: self.annotation, note: self.note, nativeNote: self.body.text,
                tags: self.tagText, color: self.color, underline: self.underline, initialized: self.initialized,
                allowsPlainEditing: self.allowed, blocked: self.blocked)
        }, bodyTextView: { [unowned self] in self.onBodyRead?(); return self.body })
    }
    func retain(_ anchor: Owner.Anchor? = nil) throws {
        try owner.retainSource(requestID: request)
        if let anchor { try owner.componentOwner.retainSource(requestID: request, anchor: anchor.id) }
    }
    func begin(_ anchor: Owner.Anchor? = nil) throws {
        let validation: @MainActor () throws -> Void = { [unowned self] in
            self.onGrant?(); guard self.grantValid else { throw ControlFailure.expected("original admission retired") }
        }
        try owner.begin(requestID: request, validate: validation)
        if let anchor { try owner.componentOwner.begin(requestID: request, anchor: anchor.id, validate: validation) }
    }
    func apply(_ anchor: Owner.Anchor? = nil) throws {
        try owner.apply(requestID: request)
        if anchor != nil { try owner.componentOwner.apply(requestID: request) }
    }
    func render(_ anchor: Owner.Anchor, revision: UInt64 = 0) {
        owner.componentOwner.render(viewID: viewID, layoutRevision: revision) { [unowned self] id, _ in
            self.owner.reveal(anchor: id, viewID: self.viewID, scroll: { _ in self.scrolls += 1; self.onScroll?() },
                focusTags: { self.tagsFocuses += 1; self.onTagsFocus?(); self.tags.isFirstResponder = true })
        }
    }
    func run(_ anchor: Owner.Anchor) throws { try retain(anchor); try begin(anchor); try apply(anchor); render(anchor) }
    func hasFocus(_ anchor: Owner.Anchor) -> Bool { owner.componentOwner.actualFocus(in: sceneID)?.anchor == anchor.id }
    func publish() { owner.originalStateWillChange(viewID: viewID) }
    func finish(_ anchor: Owner.Anchor) throws {
        try owner.validateVisible(requestID: request)
        owner.componentOwner.finish(requestID: request, completed: true)
        owner.finish(requestID: request, completed: true)
        owner.componentOwner.releaseSource(requestID: request)
        owner.releaseSource(requestID: request)
    }
}

@main struct EditorControlRunner {
    @MainActor static func main() throws {
        let cases: [(String, @MainActor () throws -> Void)] = [
            ("body uses exact original input and one scroll/focus", {
                let f = EditorFixture(); try f.run(.body)
                try expect(f.hasFocus(.body) && f.body.focusCalls == 1 && f.scrolls == 1, "body actual focus")
                try expect(f.note == "draft" && f.body.text == "draft" && f.annotation == Annotation(), "draft untouched")
            }),
            ("tags uses original focus callback and actual first responder", {
                let f = EditorFixture(); try f.run(.tags)
                try expect(f.hasFocus(.tags) && f.tagsFocuses == 1 && f.scrolls == 1, "tags actual focus")
            }),
            ("style reveals without changing any draft field", {
                let f = EditorFixture(); try f.run(.style)
                try expect(f.hasFocus(.style) && f.body.focusCalls == 0 && f.tagsFocuses == 0 && f.scrolls == 1, "style only scroll")
                try expect(f.color == "yellow" && !f.underline && f.tagText == "one,two", "style untouched")
            }),
            ("original allowsPlainEditing refuses every component", {
                let f = EditorFixture(); f.allowed = false
                try expect(f.owner.isAvailable() && !f.owner.componentOwner.isAvailable(EditorFixture.Owner.Anchor.body.id), "plain gate")
                try f.retain(); try refuses({ try f.owner.componentOwner.retainSource(requestID: f.request, anchor: EditorFixture.Owner.Anchor.tags.id) }, "disabled tags")
                try expect(f.body.focusCalls == 0 && f.tagsFocuses == 0, "no disabled effect")
            }),
            ("lazy target first real attachment after apply", {
                let f = EditorFixture(registerTags: false); try f.retain(.tags); try f.begin(.tags); try f.apply(.tags); f.render(.tags)
                try expect(!f.hasFocus(.tags) && f.tagsFocuses == 0, "no allocation receipt")
                f.owner.observeControl(viewID: f.viewID, anchor: .tags, token: f.tagsToken, marker: f.tagsMarker, field: f.tags)
                f.render(.tags, revision: 1)
                try expect(f.hasFocus(.tags) && f.tagsFocuses == 1 && f.scrolls == 1, "one owned layout continuation")
            }),
            ("a pre-apply lazy attachment cannot join retained source", {
                let f = EditorFixture(registerTags: false); try f.retain(.tags)
                f.owner.observeControl(viewID: f.viewID, anchor: .tags, token: f.tagsToken, marker: f.tagsMarker, field: f.tags)
                try refuses({ try f.begin(.tags) }, "pre-apply replacement refused")
            }),
            ("equal original setter publication retires source", {
                let f = EditorFixture(); try f.retain(.body); f.publish()
                try refuses({ try f.begin(.body) }, "equal write retained")
            }),
            ("draft A B A does not revive a reference", {
                let f = EditorFixture(); try f.retain(.body)
                f.publish(); f.note = "B"; f.publish(); f.note = "draft"
                try refuses({ try f.begin(.body) }, "draft ABA retained")
            }),
            ("actual wrapped original Binding publishes before setter", {
                let f = EditorFixture(); try f.retain(.body)
                let original = OriginalCell("draft")
                let originalSheet = ActualOriginalEditorSetter(nativeControls: f.attachment, nativeEditorViewID: f.viewID)
                var rejectedBeforeWrite = false
                original.beforeWrite = { rejectedBeforeWrite = (try? f.owner.validateSource(requestID: f.request)) == nil }
                originalSheet.nativeEditorBinding(original.binding).wrappedValue = "draft"
                try expect(rejectedBeforeWrite && original.value == "draft", "hook must precede equal original write")
            }),
            ("default nil leaves the original Binding operation unchanged", {
                let original = OriginalCell("old"); var calls = 0; original.beforeWrite = { calls += 1 }
                ActualOriginalEditorSetter(nativeControls: nil, nativeEditorViewID: UUID()).nativeEditorBinding(original.binding).wrappedValue = "new"
                try expect(calls == 1 && original.value == "new", "nil original behavior")
            }),
            ("original host A B A permanently retires pending source", {
                let f = EditorFixture(); try f.retain(.body)
                f.owner.detach(viewID: f.viewID, token: f.hostToken, view: f.form)
                f.owner.attach(access: f.access, token: f.hostToken, view: f.form)
                try refuses({ try f.begin(.body) }, "host ABA")
            }),
            ("closed backend publication detects equal lifecycle", {
                let f = EditorFixture(); try f.retain(.body)
                BackendCoordinator.shared.objectWillChange.send()
                try refuses({ try f.begin(.body) }, "backend publication")
            }),
            ("release from captured parent callback stops apply", {
                let f = EditorFixture(); try f.retain(.body); try f.begin(.body)
                f.onParentCheck = { f.onParentCheck = nil; f.owner.releaseSource(requestID: f.request) }
                try refuses({ try f.apply(.body) }, "release before effect")
                try expect(f.scrolls == 0 && f.body.focusCalls == 0, "zero effects after release")
            }),
            ("release during original scroll prevents later focus", {
                let f = EditorFixture(); f.onScroll = { f.owner.releaseSource(requestID: f.request) }; try f.run(.body)
                try expect(f.scrolls == 1 && f.body.focusCalls == 0 && !f.hasFocus(.body), "no focus after scroll callback release")
            }),
            ("release during actual focus preserves effect but refuses ACK", {
                let f = EditorFixture(); f.onTagsFocus = { f.owner.releaseSource(requestID: f.request) }; try f.run(.tags)
                try expect(f.tagsFocuses == 1 && !f.hasFocus(.tags), "focus happened but no ACK")
            }),
            ("recursive original apply consumes no second effect", {
                let f = EditorFixture(); try f.retain(.body); try f.begin(.body); var nestedRejected = false
                f.onGrant = { f.onGrant = nil; do { try f.owner.apply(requestID: f.request) } catch { nestedRejected = true } }
                try f.apply(.body); f.render(.body)
                try expect(nestedRejected && f.hasFocus(.body) && f.body.focusCalls == 1, "single original focus")
            }),
            ("recursive render from scroll performs no duplicate effect", {
                let f = EditorFixture(); f.onScroll = { f.render(.body, revision: 5) }; try f.run(.body)
                try expect(f.scrolls == 1 && f.body.focusCalls == 1 && f.hasFocus(.body), "no recursive scroll/focus")
            }),
            ("target UIKit identity replacement cannot inherit source", {
                let f = EditorFixture(); try f.retain(.tags); try f.begin(.tags); try f.apply(.tags)
                let replacement = UITextField(f.window)
                f.owner.observeControl(viewID: f.viewID, anchor: .tags, token: f.tagsToken, marker: f.tagsMarker, field: replacement)
                f.render(.tags)
                try expect(!f.hasFocus(.tags) && f.tagsFocuses == 0, "replacement source")
            }),
            ("marker detach reattach cannot revive target", {
                let f = EditorFixture(); try f.run(.body)
                f.owner.removeControl(viewID: f.viewID, anchor: .body, token: f.bodyToken)
                f.owner.observeControl(viewID: f.viewID, anchor: .body, token: f.bodyToken, marker: f.bodyMarker, field: f.body)
                try expect(!f.hasFocus(.body), "marker ABA")
            }),
            ("successful completion survives normal release until edit", {
                let f = EditorFixture(); try f.run(.body); try f.finish(.body)
                try expect(f.hasFocus(.body), "completed exact source retained")
                f.publish(); try expect(!f.hasFocus(.body), "completion retired by original edit")
            }),
            ("late snapshot getter release cannot pass source validation", {
                let f = EditorFixture(); try f.retain()
                f.onSnapshot = { f.onSnapshot = nil; f.owner.releaseSource(requestID: f.request) }
                try refuses({ try f.owner.validateSource(requestID: f.request) }, "snapshot callback released source")
            }),
            ("last original window callback release cannot pass source validation", {
                let f = EditorFixture(); try f.retain(); var count = 0
                f.onWindowCheck = { count += 1; if count == 3 { f.owner.releaseSource(requestID: f.request) } }
                try refuses({ try f.owner.validateSource(requestID: f.request) }, "last window callback released source")
            }),
            ("current admission rechecked after field getter before focus", {
                let f = EditorFixture(); try f.retain(.body); try f.begin(.body); try f.apply(.body)
                f.onBodyRead = { f.grantValid = false }
                f.render(.body)
                try expect(f.body.focusCalls == 0 && !f.hasFocus(.body), "no focus under revoked admission")
            }),
            ("model focus alone cannot acknowledge invisible input", {
                let f = EditorFixture(); f.tags.visible = false; try f.run(.tags)
                try expect(f.tagsFocuses == 0 && !f.hasFocus(.tags), "actual input geometry required")
                f.tags.visible = true; f.render(.tags, revision: 1)
                try expect(f.hasFocus(.tags) && f.scrolls == 1, "actual later layout only")
            }),
            ("unmounted original editor cannot be reused", {
                let f = EditorFixture(); try f.retain(.style); f.owner.unmount()
                try refuses({ try f.begin(.style) }, "unmounted request")
                try expect(!f.owner.isAvailable(), "no replacement editor")
            })
        ]
        let selected = ProcessInfo.processInfo.environment["EDITOR_CONTROL_FILTER"]
        var passed = 0, failed = 0
        for (name, body) in cases where selected == nil || name == selected {
            do { try body(); passed += 1; print("PASS \(name)") }
            catch { failed += 1; print("FAIL \(name): \(error)") }
        }
        print("RESULT passed=\(passed) failed=\(failed) scope=actual-owner-and-original-binding-source-with-explicit-Apple-app-boundaries")
        if failed != 0 { throw ControlFailure.expected("\(failed) source controls failed") }
    }
}
