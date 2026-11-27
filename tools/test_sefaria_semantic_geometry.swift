// UIKit geometry/tree/hit-testing are EXPLICIT boundary inputs. The three
// original evidence methods and exact four target labels are compiled verbatim.
// This executable cannot establish UIKit/RN rendering or native acceptance.
struct UIEdgeInsets { var top: CGFloat = 0; var left: CGFloat = 0; var bottom: CGFloat = 0; var right: CGFloat = 0 }
extension CGRect {
    func inset(by value: UIEdgeInsets) -> CGRect {
        CGRect(x: minX + value.left, y: minY + value.top,
               width: width - value.left - value.right, height: height - value.top - value.bottom)
    }
}
@MainActor class UIView {
    weak var superview: UIView?
    var subviews: [UIView] = []
    var frame = CGRect(x: 0, y: 0, width: 100, height: 40)
    var bounds = CGRect(x: 0, y: 0, width: 100, height: 40)
    var isHidden = false; var alpha: CGFloat = 1; var clipsToBounds = false
    var isAccessibilityElement = false; var accessibilityLabel: String?
    var window: UIWindow? { self as? UIWindow ?? superview?.window }
    func addSubview(_ child: UIView) {
        child.superview?.subviews.removeAll { $0 === child }
        child.superview = self; subviews.append(child)
    }
    func isDescendant(of other: UIView) -> Bool {
        var current: UIView? = self
        while let item = current { if item === other { return true }; current = item.superview }
        return false
    }
    private var absoluteOrigin: CGPoint {
        var current: UIView? = self, x: CGFloat = 0, y: CGFloat = 0
        while let item = current, !(item is UIWindow) {
            x += item.frame.minX - item.bounds.minX; y += item.frame.minY - item.bounds.minY
            current = item.superview
        }
        return CGPoint(x: x, y: y)
    }
    func convert(_ rect: CGRect, to target: UIView) -> CGRect {
        let here = absoluteOrigin, there = target.absoluteOrigin
        return rect.offsetBy(dx: here.x - there.x, dy: here.y - there.y)
    }
}
@MainActor final class UILabel: UIView { var text: String? }
@MainActor final class UITextView: UIView { var text = "" }
@MainActor final class UIScrollView: UIView {
    var isDragging = false; var isDecelerating = false
    var adjustedContentInset = UIEdgeInsets()
}
@MainActor final class UIWindowScene {
    enum ActivationState { case foregroundActive, background }
    final class Session { var persistentIdentifier = "original-scene" }
    var session = Session(); var activationState = ActivationState.foregroundActive
}
@MainActor final class UIWindow: UIView {
    var isKeyWindow = true; var windowScene: UIWindowScene? = UIWindowScene()
    var rootViewController: UIViewController?
    var forcedHit: UIView?
    func hitTest(_ point: CGPoint, with event: Int?) -> UIView? {
        if let forcedHit { return forcedHit }
        func deepest(_ view: UIView) -> UIView? {
            guard !view.isHidden, view.alpha > 0.01,
                  view.convert(view.bounds, to: self).contains(point) else { return nil }
            for child in view.subviews.reversed() { if let hit = deepest(child) { return hit } }
            return view
        }
        return deepest(self)
    }
}
@MainActor class UIViewController {
    var viewIfLoaded: UIView?
    var view: UIView { viewIfLoaded! }
    var parent: UIViewController?
    var presentedViewController: UIViewController?
    var isBeingPresented = false; var isBeingDismissed = false
    var transitionCoordinator: Int?
}
// Host mount flags below are explicit original-lifecycle boundary inputs. They
// never manufacture an app acknowledgement, appearance callback or RN view.
@MainActor final class SefariaEmbeddedNativeSurfaceController: UIViewController {
    __ACTUAL_EVIDENCE_TYPES__
    let identity: SefariaEmbeddedSurfaceIdentity
    let token = UUID()
    var reactView: UIView?
    var appeared = true; var attached = true; var detached = false
    init(identity: SefariaEmbeddedSurfaceIdentity) { self.identity = identity }
    __ACTUAL_EVIDENCE_METHODS__
}
@MainActor private final class GeometryFixture {
    let window = UIWindow(), container = UIView(), original = UIView()
    let controller: SefariaEmbeddedNativeSurfaceController
    var labels: [UILabel] = []
    init(_ target: SefariaEmbeddedSemanticTarget = .library, language: String = "english") {
        controller = SefariaEmbeddedNativeSurfaceController(identity: .init(id: UUID(), mountID: UUID(), sceneID: "original-scene", epoch: 1))
        window.bounds = CGRect(x: 0, y: 0, width: 600, height: 800)
        window.frame = window.bounds
        container.frame = window.bounds; container.bounds = window.bounds
        original.frame = window.bounds; original.bounds = window.bounds
        window.addSubview(container); container.addSubview(original)
        controller.viewIfLoaded = container; controller.reactView = original
        window.rootViewController = controller
        for (index, text) in target.originalVisibleTexts(language: language)!.enumerated() {
            let label = UILabel(); label.text = text
            label.frame = CGRect(x: 20, y: 50 + 100 * index, width: 500, height: 60)
            label.bounds = CGRect(x: 0, y: 0, width: 500, height: 60)
            original.addSubview(label); labels.append(label)
        }
    }
    func visible(_ target: SefariaEmbeddedSemanticTarget = .library, _ language: String = "english") -> Bool {
        controller.semanticEvidence(target: target, language: language) != nil
    }
}
@main private struct SemanticGeometryControls {
    @MainActor static func main() throws {
        var results: [[String: Any]] = []
        func test(_ name: String, _ body: () -> Bool) { results.append(["name": name, "passed": body()]) }
        for target in SefariaEmbeddedSemanticTarget.allCases {
            for language in ["english", "hebrew"] {
                test("actual original \(target.rawValue) \(language) text and geometry") {
                    let f = GeometryFixture(target, language: language)
                    let result = f.controller.semanticEvidence(target: target, language: language)
                    return result?.hostToken == f.controller.token && result?.target == target
                        && result?.originalViews == f.labels.map(ObjectIdentifier.init)
                }
            }
        }
        test("original schedules title alone does not prove page") {
            let f = GeometryFixture(.learningSchedules); f.labels[1].text = "Library preview"
            return !f.visible(.learningSchedules)
        }
        test("original Topics loading does not prove topic table") {
            let f = GeometryFixture(.topics); f.labels[0].text = "Loading…"
            return !f.visible(.topics)
        }
        test("unknown language is not inferred") { !GeometryFixture().visible(.library, "unknown") }
        test("two original siblings with same title refuse ambiguity") {
            let f = GeometryFixture(), other = UILabel(); other.text = f.labels[0].text
            other.frame = f.labels[0].frame.offsetBy(dx: 0, dy: 100); other.bounds = f.labels[0].bounds
            f.original.addSubview(other); return !f.visible()
        }
        test("original AX wrapper plus its text child is one witness") {
            let f = GeometryFixture(), wrapper = UIView()
            wrapper.frame = f.labels[0].frame; wrapper.bounds = f.labels[0].bounds
            wrapper.isAccessibilityElement = true; wrapper.accessibilityLabel = f.labels[0].text
            f.original.addSubview(wrapper); wrapper.addSubview(f.labels[0]); f.labels[0].frame.origin = .zero
            return f.visible()
        }
        test("actual original AX text without UILabel is supported") {
            let f = GeometryFixture(); f.labels[0].text = nil
            f.labels[0].isAccessibilityElement = true; f.labels[0].accessibilityLabel = "Browse the Library"
            return f.visible()
        }
        test("hidden text refuses") { let f = GeometryFixture(); f.labels[0].isHidden = true; return !f.visible() }
        test("faded ancestor refuses") { let f = GeometryFixture(); f.original.alpha = 0.9; return !f.visible() }
        test("partially clipped original text refuses") {
            let f = GeometryFixture(); f.original.clipsToBounds = true
            f.labels[0].frame.origin.x = 580; return !f.visible()
        }
        test("original scroll safe-area clipping refuses") {
            let f = GeometryFixture(), scroll = UIScrollView()
            scroll.frame = f.original.frame; scroll.bounds = f.original.bounds
            scroll.adjustedContentInset.top = 100
            f.original.addSubview(scroll); scroll.addSubview(f.labels[0]); return !f.visible()
        }
        test("original scroll drag refuses") {
            let f = GeometryFixture(), scroll = UIScrollView(); scroll.frame = f.original.frame; scroll.bounds = f.original.bounds
            f.original.addSubview(scroll); scroll.addSubview(f.labels[0]); scroll.isDragging = true; return !f.visible()
        }
        test("original scroll deceleration refuses") {
            let f = GeometryFixture(), scroll = UIScrollView(); scroll.frame = f.original.frame; scroll.bounds = f.original.bounds
            f.original.addSubview(scroll); scroll.addSubview(f.labels[0]); scroll.isDecelerating = true; return !f.visible()
        }
        test("occluding sibling hit-test refuses") {
            let f = GeometryFixture(), cover = UIView(); f.container.addSubview(cover); f.window.forcedHit = cover
            return !f.visible()
        }
        test("actual original text child hit-test is allowed") {
            let f = GeometryFixture(), child = UIView(); f.labels[0].addSubview(child); f.window.forcedHit = child
            return f.visible()
        }
        test("wrong actual scene refuses") {
            let f = GeometryFixture(); f.window.windowScene!.session.persistentIdentifier = "other-scene"; return !f.visible()
        }
        test("background actual scene refuses") {
            let f = GeometryFixture(); f.window.windowScene!.activationState = .background; return !f.visible()
        }
        test("non-key window refuses") { let f = GeometryFixture(); f.window.isKeyWindow = false; return !f.visible() }
        test("unappeared host refuses") { let f = GeometryFixture(); f.controller.appeared = false; return !f.visible() }
        test("detached host refuses") { let f = GeometryFixture(); f.controller.detached = true; return !f.visible() }
        test("original presentation transition refuses") {
            let f = GeometryFixture(); f.controller.isBeingPresented = true; return !f.visible()
        }
        test("foreign top modal refuses") {
            let f = GeometryFixture(), modal = UIViewController(), view = UIView()
            modal.viewIfLoaded = view; f.window.addSubview(view); f.controller.presentedViewController = modal
            return !f.visible()
        }
        test("no exact original title refuses") { let f = GeometryFixture(); f.labels[0].text = "Other library"; return !f.visible() }
        test("zero area text refuses") { let f = GeometryFixture(); f.labels[0].bounds.size = .zero; return !f.visible() }
        test("bounded original subtree fails closed") {
            let f = GeometryFixture(); for _ in 0..<8192 { f.original.addSubview(UIView()) }; return !f.visible()
        }
        let failed = results.filter { $0["passed"] as? Bool != true }.count
        let data = try JSONSerialization.data(withJSONObject: ["scope": "Verbatim original evidence methods; explicit UIKit geometry/tree/hit-test boundary, native NOT_RUN",
            "passed": results.count - failed, "failed": failed, "results": results], options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self)); if failed > 0 { exit(1) }
    }
}
