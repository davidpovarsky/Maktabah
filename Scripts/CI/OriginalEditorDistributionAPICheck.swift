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

// Compile the new process-resume SPI against the actual distribution as well.
// Inputs belong to the existing persistence owner; this function is never run.
@MainActor
private func requireOriginalProcessResumeAPI(
    session: AnytypeOriginalEditorQualificationSession,
    host: AnytypeOriginalEditorHost,
    snapshot: AnytypeOriginalEditorSnapshot,
    source: AnytypeOriginalEditorQualificationSource,
    workspaceNamespace: UUID,
    legacyAnnotationID: Int64,
    payloadDigest: String,
    sourceIsCurrent: @escaping @MainActor (AnytypeOriginalEditorQualificationSource) -> Bool
) async throws {
    let context = try AnytypeOriginalEditorProcessResumeContext(
        workspaceNamespace: workspaceNamespace,
        legacyAnnotationID: legacyAnnotationID,
        payloadDigest: payloadDigest)
    let prepared = try await session.prepareProcessResume(
        host: host, snapshot: snapshot, currentSource: source,
        context: context, sourceIsCurrent: sourceIsCurrent)
    let _: UUID = prepared.runtimeNonce
    let _: String = prepared.accountID
    let _: String = prepared.spaceID
    let _: String = prepared.objectID
    let _: Int32 = prepared.preparedProcessID
    let _: Int32 = prepared.currentProcessID
    let _: Bool = prepared.credentialConsumed
    let resumed = try await AnytypeOriginalEditorModule.resumeEditableAcceptance(
        source: source, snapshot: snapshot, context: context,
        sourceIsCurrent: sourceIsCurrent)
    let _: AnytypeOriginalEditorProcessResumeReceipt? = resumed.processResumeReceipt
    let _: Bool = try await AnytypeOriginalEditorModule.cleanupOwnedProcessResumeCredential()
}

