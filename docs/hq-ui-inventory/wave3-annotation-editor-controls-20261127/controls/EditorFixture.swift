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

