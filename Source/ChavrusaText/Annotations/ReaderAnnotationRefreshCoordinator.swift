#if canImport(Combine)
import Combine
#endif
import Foundation

/// Coordinates annotation refresh cycles and revision tracking in ChavrusaText.
/// Fixes BUG-03 annotation visibility caching by providing an explicit, `@MainActor`-isolated
/// revision counter that invalidates `.equatable()` cached reader text views when highlights change.
@MainActor final class ReaderAnnotationRefreshCoordinator {
    static let shared = ReaderAnnotationRefreshCoordinator()

    #if canImport(Combine)
    @Published private(set) var revision: UInt64 = 0
    @Published private(set) var lastMutationTimestamp: Date = Date()
    @Published private(set) var lastErrorMessage: String? = nil
    #else
    private(set) var revision: UInt64 = 0
    private(set) var lastMutationTimestamp: Date = Date()
    private(set) var lastErrorMessage: String? = nil
    #endif

    init() {}

    /// Notify that an annotation was created, updated, or removed.
    /// Publishes a new revision to trigger redraw across equatable reader subviews.
    func notifyAnnotationMutated() {
        revision &+= 1
        lastMutationTimestamp = Date()
        lastErrorMessage = nil
    }

    /// Record an error during annotation creation or persistence.
    func recordError(_ error: Error) {
        lastErrorMessage = error.localizedDescription
    }

    /// Reset error state.
    func clearError() {
        lastErrorMessage = nil
    }
}

#if canImport(Combine)
extension ReaderAnnotationRefreshCoordinator: ObservableObject {}
#endif
