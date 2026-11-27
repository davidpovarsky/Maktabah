import OtzariaUIRouting

/// Issued by the ORIGINAL root window source before any await. Its closure
/// re-reads that source's exact UIView/UIWindow identity and monotonic lifetime
/// revision, plus the scene's original source-object attachment revision.
/// It is neither a cached presentation admission nor a navigation grant.
@MainActor
final class MaktabahNativeWindowObservation {
    private weak var window: UIWindow?
    private let validateOriginalOwner: @MainActor (UIWindow) -> Bool

    init(window: UIWindow, validateOriginalOwner: @escaping @MainActor (UIWindow) -> Bool) {
        self.window = window; self.validateOriginalOwner = validateOriginalOwner
    }

    func validate() throws -> UIWindow {
        guard let window, validateOriginalOwner(window), self.window === window else {
            throw UIRouteError(.staleState, "native_original_window_changed")
        }
        return window
    }
}
