import Foundation
import UIKit
import AnytypeOriginalEditor

// Compile the public app integration against each actual Release distribution.
// No qualification SPI, account creation, editor execution or runtime credit.
@MainActor
private func requireOriginalProductionAPI(
    binding: AnytypeOriginalEditorBinding,
    snapshot: AnytypeOriginalEditorSnapshot
) async throws {
    let exact = try AnytypeOriginalEditorBinding(
        accountID: binding.accountID, spaceID: binding.spaceID, objectID: binding.objectID,
        hostProfileID: binding.hostProfileID, annotationUUID: binding.annotationUUID,
        expectedRevision: binding.expectedRevision, sourceWitnessSHA256: binding.sourceWitnessSHA256)
    let lifetime = AnytypeOriginalEditorSourceLifetime(binding: exact)
    let host = try await AnytypeOriginalEditorModule.openExistingEditor(
        binding: exact, sourceLifetime: lifetime, sourceIsCurrent: { $0 == exact })
    let _: UIViewController = try host.makeViewController()
    let capture = try await host.captureNativeSnapshot(maximumBodyBytes: 65_536)
    let _ = try AnytypeOriginalEditorSnapshot(bodyBytes: capture.snapshot.bodyBytes, maximumBodyBytes: 65_536)
    let _ = snapshot.provenance.matchesCaptureBinding(exact)
    host.retire()
    lifetime.retire()
}
