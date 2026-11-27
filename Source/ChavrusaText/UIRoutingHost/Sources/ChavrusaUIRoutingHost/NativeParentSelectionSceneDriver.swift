import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// Passive, non-Codable evidence from an actual original parent host. It is
/// not a grant or a scene receipt. The original driver must retain and freshly
/// validate the real host/window/activation behind these fixed identifiers.
public struct NativeOriginalParentObservation: Sendable, Equatable {
    public let requestID: UUID
    public let sceneID: UIStableID
    public let activationID: UUID
    public let witnessID: UUID
    public let presentationRevision: UInt64

    public init(requestID: UUID, sceneID: UIStableID, activationID: UUID,
                witnessID: UUID, presentationRevision: UInt64) {
        self.requestID = requestID; self.sceneID = sceneID; self.activationID = activationID
        self.witnessID = witnessID; self.presentationRevision = presentationRevision
    }
}

/// Opt-in only. Other native drivers retain their original one synchronous
/// apply. Selection is called by the original orchestrator after the one-use
/// terminal Core guard, NEVER by a layout callback or read-only render check.
@MainActor
public protocol NativeParentSelectionSceneDriver: NativeSceneDriver {
    func originalParentSelectionKind(for command: UISceneCommand) throws -> UIOriginalParentSelectionKind?
    func applyOriginalParent(_ command: UISceneCommand) throws
    func waitUntilOriginalParentReady(_ command: UISceneCommand) async throws -> NativeOriginalParentObservation
    func validateOriginalParent(_ observation: NativeOriginalParentObservation, for command: UISceneCommand) throws
    func applyOriginalSelection(_ command: UISceneCommand) throws
}
