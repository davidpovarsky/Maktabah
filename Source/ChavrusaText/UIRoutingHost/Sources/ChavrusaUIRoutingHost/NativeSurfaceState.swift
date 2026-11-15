import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// Typed projection of existing view/model state. Constructed at the native
/// surface, independently of the incoming command. Absence stays absence.
public struct NativeSurfaceState: Sendable, Equatable {
    public let destination: UIDestinationID
    public let presentation: PresentationSpec
    public let content: ActionReaderDestination?
    public let state: UIStateSpec
    public let focus: FocusSpec?

    public init(destination: UIDestinationID, presentation: PresentationSpec, content: ActionReaderDestination?,
                state: UIStateSpec, focus: FocusSpec?) {
        self.destination = destination; self.presentation = presentation; self.content = content
        self.state = state; self.focus = focus
    }

    /// Request UUID and precondition fields are transport metadata. All native
    /// destination/presentation/content/state/focus fields come from this
    /// independently observed projection, never from a requested route echo.
    public func observedRoute(for command: UISceneCommand, backend: ActionBackendSnapshot) -> RouteSpec {
        let metadata = command.route.route
        return RouteSpec(version: metadata.version, requestId: metadata.requestId, destination: destination,
                         backend: backend.backend, content: content, presentation: presentation, state: state, focus: focus,
                         scene: metadata.scene, expectedBackendSnapshot: metadata.expectedBackendSnapshot)
    }
}
