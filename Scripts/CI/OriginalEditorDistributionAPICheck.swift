import Foundation
import UIKit
@_spi(OriginalEditorQualification) import AnytypeOriginalEditor

// Typechecked against the actual exported modules. This function is never run
// and supplies no account, Space, body seed or substitute editor implementation.
@MainActor
private func requireOriginalStageBAPI(
    source: AnytypeOriginalEditorQualificationSource,
    sourceIsCurrent: @escaping @MainActor (AnytypeOriginalEditorQualificationSource) -> Bool
) async throws {
    let session = try await AnytypeOriginalEditorModule.beginEditableAcceptance(
        source: source, sourceIsCurrent: sourceIsCurrent)
    let binding = session.binding
    let lifetime = AnytypeOriginalEditorSourceLifetime(binding: binding)
    let host = try await AnytypeOriginalEditorModule.openExistingEditor(
        binding: binding, sourceLifetime: lifetime, sourceIsCurrent: { $0 == binding })
    let _: UIViewController = try host.makeViewController()
    let capture = try await host.captureNativeSnapshot(maximumBodyBytes: 65_536)
    let _: AnytypeOriginalEditorBinding = try await session.prepareReopen(
        snapshot: capture.snapshot, currentSource: source, sourceIsCurrent: sourceIsCurrent)
    host.retire()
}
