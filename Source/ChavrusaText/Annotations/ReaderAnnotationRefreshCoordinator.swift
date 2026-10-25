#if canImport(Combine)
import Combine
#endif
import Foundation

/// Coordinates annotation refresh cycles and revision tracking in ChavrusaText.
/// Fixes BUG-03 annotation visibility caching by providing an explicit, `@MainActor`-isolated
/// revision counter that invalidates `.equatable()` cached reader text views when highlights change.
@MainActor
public final class ReaderAnnotationRefreshCoordinator {
    public static let shared = ReaderAnnotationRefreshCoordinator()

    #if canImport(Combine)
    @Published public private(set) var revision: UInt64 = 0
    @Published public private(set) var lastMutationTimestamp: Date = Date()
    @Published public private(set) var lastErrorMessage: String? = nil
    #else
    public private(set) var revision: UInt64 = 0
    public private(set) var lastMutationTimestamp: Date = Date()
    public private(set) var lastErrorMessage: String? = nil
    #endif

    public init() {}

    /// Notify that an annotation was created, updated, or removed.
    /// Publishes a new revision to trigger redraw across equatable reader subviews.
    public func notifyAnnotationMutated() {
        revision &+= 1
        lastMutationTimestamp = Date()
        lastErrorMessage = nil
    }

    /// Record an error during annotation creation or persistence.
    public func recordError(_ error: Error) {
        lastErrorMessage = error.localizedDescription
    }

    /// Reset error state.
    public func clearError() {
        lastErrorMessage = nil
    }
}

#if canImport(Combine)
extension ReaderAnnotationRefreshCoordinator: ObservableObject {}
#endif
