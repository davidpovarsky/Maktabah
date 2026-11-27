import Foundation
import Observation
import OtzariaUIRouting
import ChavrusaUIRoutingHost

// Explicit Apple/app/Annotation boundaries. This executable never constructs a
// real UIKit window, runs Core execution, persists an Annotation, or receives a
// native receipt. The owner, component owner and source latches are actual code.
extension String { init(localized value: String) { self = value } }
@MainActor final class UIWindowScene {
    final class Session { var persistentIdentifier = "editor-scene" }
    let session = Session()
}
@MainActor final class UIWindow { let windowScene: UIWindowScene? = .init() }
@MainActor class UIView {
    var window: UIWindow?
    var visible = true
    var isUserInteractionEnabled = true
    var isFirstResponder = false
    var isTopSheet = true
    var onFocus: (() -> Void)?
    private(set) var focusCalls = 0
    init(_ window: UIWindow? = nil) { self.window = window }
    func becomeFirstResponder() -> Bool {
        focusCalls += 1; onFocus?(); isFirstResponder = true; return true
    }
}
@MainActor final class UITextView: UIView { var isEditable = true; var text: String? = "draft" }
@MainActor final class UITextField: UIView { var isEnabled = true; var text: String? = "one,two" }
@MainActor enum MaktabahNativeAnnotationEditorGeometry {
    static func ownsTopSheet(_ view: UIView, sceneID: UIStableID) -> Bool {
        view.isTopSheet && view.window?.windowScene?.session.persistentIdentifier == sceneID.rawValue
    }
}
@MainActor enum MaktabahNativeSavedResultsGeometry {
    static func isVisible(_ view: UIView, in sheet: UIView, window: UIWindow, sceneID: UIStableID) -> Bool {
        view.visible && sheet.visible && sheet.isTopSheet && view.window === window && sheet.window === window
            && window.windowScene?.session.persistentIdentifier == sceneID.rawValue
    }
}
struct Annotation: Equatable { var id: Int64? = 7; var note = "saved"; var tags = ["original"]; var revision = 3 }
enum BackendID { case otzaria, other }
@MainActor final class AnyCancellable {
    let cancel: () -> Void
    init(_ cancel: @escaping () -> Void) { self.cancel = cancel }
    isolated deinit { cancel() }
}
@MainActor final class OriginalBackendPublisher {
    var observers: [UUID: (Int) -> Void] = [:]
    func sink(_ body: @escaping (Int) -> Void) -> AnyCancellable {
        let id = UUID(); observers[id] = body
        return AnyCancellable { [weak self] in self?.observers.removeValue(forKey: id) }
    }
    func send() { for body in Array(observers.values) { body(1) } }
}
@Observable @MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    @ObservationIgnored let objectWillChange = OriginalBackendPublisher()
    var activeBackendID = BackendID.otzaria { willSet { objectWillChange.send() } }
    var generation: UInt64 = 0 { willSet { objectWillChange.send() } }
    var isTransitioning = false { willSet { objectWillChange.send() } }
}
@MainActor struct Binding<Value> {
    let read: () -> Value
    let write: (Value) -> Void
    init(get: @escaping () -> Value, set: @escaping (Value) -> Void) { read = get; write = set }
    var wrappedValue: Value { get { read() } nonmutating set { write(newValue) } }
}
@MainActor final class OriginalCell<Value> {
    var value: Value
    var beforeWrite: (() -> Void)?
    init(_ value: Value) { self.value = value }
    var binding: Binding<Value> { .init(get: { self.value }, set: { self.beforeWrite?(); self.value = $0 }) }
}
