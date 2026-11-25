import Foundation
import UIKit
import AnytypeOriginalEditor

// Additive public-only compiler check for the exact reviewed local lifecycle.
// The function is never invoked by this gate and grants no native UI acceptance.
@MainActor
private func requireOriginalLocalAnnotationAPI(
    appGroup: String, source: AnytypeOriginalEditorLocalAnnotationSource,
    snapshot: AnytypeOriginalEditorSnapshot?, text: String
) async throws {
    let exact = try AnytypeOriginalEditorLocalAnnotationSource(
        hostProfileID: source.hostProfileID, annotationUUID: source.annotationUUID,
        expectedRevision: source.expectedRevision, sourceWitnessSHA256: source.sourceWitnessSHA256,
        payloadSHA256: source.payloadSHA256)
    let lifetime = AnytypeOriginalEditorLocalAnnotationSourceLifetime(source: exact)
    let _: AnytypeOriginalEditorLocalAnnotationSource = lifetime.source
    let _: Bool = lifetime.isCurrent
    let body: AnytypeOriginalEditorLocalAnnotationBody = snapshot.map {
        .nativeSnapshot($0)
    } ?? .plainText(text)
    let session = try await AnytypeOriginalEditorModule.openLocalAnnotation(
        appGroup: appGroup, sourceLifetime: lifetime, body: body,
        sourceIsCurrent: { $0 == exact })
    defer { session.retire(); lifetime.retire() }
    let _: AnytypeOriginalEditorBinding = session.binding
    let _: UIViewController = try session.makeViewController()
    let capture: AnytypeOriginalEditorLocalAnnotationCapture =
        try await session.captureNativeSnapshot(maximumBodyBytes: 65_536)
    let _: AnytypeOriginalEditorSnapshotCapture = capture.nativeCapture
    let _: String = capture.textPreview
    let _: AnytypeOriginalEditorLocalAnnotationError = .retiredSource
}
