import Foundation
import OtzariaActionCore

/// A trusted native-driver choice, never decoded from URL/public UI state.
/// Each consumer retains its ORIGINAL source before the first await. This
/// metadata carries no permission and is never decoded from a public payload.
public enum UIOriginalParentSelectionKind: Sendable, Equatable {
    case readerTab
    /// Nil is the exact prepared original empty group, never a generic root.
    /// The native owner must prove that its staged readers and selected tab
    /// are empty before it can offer this finite continuation.
    case workspaceSelection(profileID: UIStableID, workspaceID: UIStableID, activeTabID: UIStableID?)
}

/// One immutable command and its one-use terminal Core capability. Parent
/// evidence is deliberately not a UISceneReceipt and cannot acknowledge this
/// command. Only the original final surface can produce that receipt.
@MainActor
public final class UIOriginalParentSelectionContinuation: Sendable {
    public let command: UISceneCommand
    public let kind: UIOriginalParentSelectionKind
    private let authorization: ActionNavigationContinuation
    private var claimed = false
    private var retired = false

    init(command: UISceneCommand, kind: UIOriginalParentSelectionKind,
         authorization: ActionNavigationContinuation) {
        self.command = command; self.kind = kind; self.authorization = authorization
    }

    /// The native orchestrator supplies its actual directory observation after
    /// validating the retained original parent's fresh UIKit proof. The initial
    /// revision is never rewritten: it remains the final receipt's basedOn.
    public func authorizeSelection(current: UISceneSnapshot) throws {
        guard !claimed, !retired else {
            throw UIRouteError(.staleState, "original_parent_selection_consumed")
        }
        claimed = true
        do {
            guard current.sceneID == command.scene.sceneID,
                  current.backendSnapshot == command.invocation.snapshot,
                  current.revision > command.scene.revision else {
                throw UIRouteError(.staleState, "original_parent_scene_changed")
            }
            try authorization.authorizeSelection(invocation: command.invocation,
                                                   sceneID: command.scene.sceneID.rawValue)
        } catch {
            retire()
            throw error
        }
    }

    public func retire() {
        guard !retired else { return }
        retired = true; authorization.retire()
    }
}
