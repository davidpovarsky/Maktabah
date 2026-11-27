import Foundation

// The ORIGINAL Controller's fields/load/attach/detach/viewDidAppear methods
// below are extracted without rewriting their callback. Only UIKit's actual
// coordinator/host/domain objects are bounded substitutes here; no native claim.
@MainActor struct TransitionContext { let isCancelled: Bool }
@MainActor final class Transition {
    var callback: ((TransitionContext) -> Void)?
    var completions = 0
    func animate(alongsideTransition: ((TransitionContext) -> Void)?, completion: @escaping (TransitionContext) -> Void) { callback = completion }
    func finish(cancelled: Bool = false) {
        let original = callback; callback = nil
        if let original { completions += 1; original(.init(isCancelled: cancelled)) }
    }
}
@MainActor class UIViewController {
    var parent: UIViewController?
    var transitionCoordinator: Transition?
    var view: AnyObject?
    func loadView() {}
    func viewDidAppear(_ animated: Bool) {}
}
@MainActor final class iOSNavigationManager {}
@MainActor final class MaktabahNativeViewerParentHost {
    var publications = 0, disappearances = 0
    var onPublication: (() -> Void)?
    func attach(_ controller: MaktabahNativeViewerParentWitness.Controller, manager: iOSNavigationManager) {}
    func detach(_ controller: MaktabahNativeViewerParentWitness.Controller) {}
    func originalPresentationDidChange(_ controller: MaktabahNativeViewerParentWitness.Controller, disappeared: Bool = false) {
        publications += 1
        if disappeared { disappearances += 1 }
        onPublication?()
    }
}

@MainActor enum MaktabahNativeViewerParentWitness {
    @MainActor final class Controller: UIViewController {
        let identity = UUID()
        private weak var host: MaktabahNativeViewerParentHost?
        private weak var manager: iOSNavigationManager?
        private var appeared = false
        private var hadOriginalWindow = false
        private let marker = Marker()

        override func loadView() {
            view = marker
            marker.windowDidChange = { [weak self] in
                guard let self else { return }
                let attached = marker.window != nil
                let disappeared = hadOriginalWindow && !attached
                hadOriginalWindow = attached
                // A freshly allocated original container may receive an
                // initial nil-window callback before its first real mount.
                // That is neither appearance nor disappearance evidence.
                if attached || disappeared {
                    host?.originalPresentationDidChange(self, disappeared: disappeared)
                }
            }
        }
        func attach(host: MaktabahNativeViewerParentHost?, manager: iOSNavigationManager) {
            if self.host !== host || self.manager !== manager {
                self.host?.detach(self)
                self.host = host; self.manager = manager
            }
            host?.attach(self, manager: manager)
        }
        func detach() {
            appeared = false
            hadOriginalWindow = false
            host?.detach(self); host = nil; manager = nil
            marker.windowDidChange = nil
        }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            appeared = true
            host?.originalPresentationDidChange(self)
            // A real transition completion can be later than didAppear. Use
            // that original coordinator's completion, never elapsed time.
            var current: UIViewController? = self
            while let controller = current {
                if let transition = controller.transitionCoordinator {
                    transition.animate(alongsideTransition: nil) { [weak self] context in
                        guard let self else { return }
                        self.host?.originalPresentationDidChange(self, disappeared: context.isCancelled)
                    }
                    break
                }
                current = controller.parent
            }
        }
    }
    @MainActor private final class Marker { var window: AnyObject?; var windowDidChange: (@MainActor () -> Void)? }
}


@main struct CallbackControls {
    @MainActor static func main() {
        var rows: [[String: Any]] = []
        for mode in ["same_host", "new_host", "host_ABA", "new_manager", "detach_return", "replacement_during_appearance", "same_host_cancelled"] {
            let a = MaktabahNativeViewerParentHost(), b = MaktabahNativeViewerParentHost()
            let manager = iOSNavigationManager(), nextManager = iOSNavigationManager()
            let controller = MaktabahNativeViewerParentWitness.Controller(), transition = Transition()
            controller.transitionCoordinator = transition
            controller.attach(host: a, manager: manager)
            if mode == "replacement_during_appearance" {
                a.onPublication = { a.onPublication = nil; controller.attach(host: b, manager: manager) }
            }
            controller.viewDidAppear(false)
            switch mode {
            case "new_host": controller.attach(host: b, manager: manager)
            case "host_ABA": controller.attach(host: b, manager: manager); controller.attach(host: a, manager: manager)
            case "new_manager": controller.attach(host: a, manager: nextManager)
            case "detach_return": controller.detach(); controller.attach(host: a, manager: manager)
            default: break
            }
            let beforeA = a.publications, beforeB = b.publications
            transition.finish(cancelled: mode == "same_host_cancelled")
            let same = mode == "same_host" || mode == "same_host_cancelled"
            let passed = same ? (a.publications == beforeA + 1 && b.publications == beforeB && transition.completions == 1
                && a.disappearances == (mode == "same_host_cancelled" ? 1 : 0))
                : (a.publications == beforeA && b.publications == beforeB)
            rows.append(["name": mode, "pass": passed, "actual_stored_completion_invoked": transition.completions,
                         "old_host_delta": a.publications-beforeA, "new_host_delta": b.publications-beforeB])
        }
        let failures = rows.filter { !($0["pass"] as! Bool) }
        print(String(data: try! JSONSerialization.data(withJSONObject: ["rows": rows, "pass_count": rows.count-failures.count,
            "fail_count": failures.count, "boundary": "Actual Controller attachment and coordinator-completion source; explicit UIKit/host doubles; native NOT_RUN"], options: [.sortedKeys]), encoding: .utf8)!)
        if !failures.isEmpty { exit(1) }
    }
}
