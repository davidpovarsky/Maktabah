import Foundation
import AnytypeOriginalEditor

// Public compiler probes only. These functions are never executed by admission;
// the original Maktabah UI journey must separately demonstrate native behavior.
@MainActor
private func requireOriginalMiniAppsLaunchAPI(
    session: AnytypeOriginalEditorLocalAnnotationSession
) async throws {
    let _: Bool = session.canContinueEditing
    try session.setMiniAppsAction(title: "MiniApps") { result in
        let _: Result<AnytypeOriginalEditorMiniAppsContext, Error> = result
    }
    let context = try await session.captureMiniAppsContext()
    let _: String = context.documentText
    let _: String? = context.selectedText
    let _: Int? = context.selectionLocation
    let _: Int? = context.selectionLength
    let _: Int? = context.documentSelectionLocation
    let _: String? = context.selectedBlockText
    let _: [String] = context.blockIDs
    let _: String? = context.sceneID
    let files: [AnytypeOriginalEditorMiniAppsFile] =
        try await session.exportMiniAppsFiles(context: context, maximumBytes: 8 * 1_048_576)
    for file in files {
        let _: String = file.blockID
        let _: Data = file.attachment.data
        let _: String = file.attachment.name
        let _: String = file.attachment.typeIdentifier
    }
    let bytes = try JSONEncoder().encode(context)
    let _: AnytypeOriginalEditorMiniAppsContext =
        try JSONDecoder().decode(AnytypeOriginalEditorMiniAppsContext.self, from: bytes)
    let launch: AnytypeOriginalEditorMiniAppsLaunch =
        try await session.captureMiniAppsLaunch(context: context, maximumBodyBytes: 65_536)
    let _: AnytypeOriginalEditorMiniAppsContext = launch.context
    let _: AnytypeOriginalEditorLocalAnnotationCapture = launch.capture
}

@MainActor
private func requireOriginalMiniAppsReturnAPI(
    session: AnytypeOriginalEditorLocalAnnotationSession,
    durableContext: AnytypeOriginalEditorMiniAppsContext,
    requestID: UUID,
    text: String
) async throws {
    let restored: AnytypeOriginalEditorMiniAppsContext =
        try await session.restoreMiniAppsContext(durableContext)
    let _: [AnytypeOriginalEditorMiniAppsAction] = [.insert, .replaceSelection, .replaceDocument]
    let _: AnytypeOriginalEditorMiniAppsError = .nativeBodyChanged
    let capture: AnytypeOriginalEditorLocalAnnotationCapture =
        try await session.applyMiniAppsResult(
            requestID: requestID, context: restored, action: .insert,
            text: text, maximumBodyBytes: 65_536)
    let _: AnytypeOriginalEditorSnapshotCapture = capture.nativeCapture
    let _: String = capture.textPreview
}

// A compile-only file boundary probe. Native upload, byte readback, canonical
// save and replay must still pass the original application acceptance journey.
@MainActor
private func requireOriginalMiniAppsFilesAPI(
    session: AnytypeOriginalEditorLocalAnnotationSession,
    context: AnytypeOriginalEditorMiniAppsContext,
    requestID: UUID,
    bytes: Data
) async throws {
    let attachment = try AnytypeOriginalEditorMiniAppsAttachment(
        data: bytes, name: "miniapps-result.txt", typeIdentifier: "public.plain-text")
    let _: AnytypeOriginalEditorLocalAnnotationCapture =
        try await session.applyMiniAppsResult(requestID: requestID, context: context,
            action: .insert, text: "", attachments: [attachment], maximumBodyBytes: 65_536)
}
