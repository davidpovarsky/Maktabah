import Foundation

/// Caller-supplied proposal and exact source identity. The original UI owner
/// must prove any supplied selection against its original rendered source.
public struct ActionNoteDraftRequest: Sendable, Equatable {
    public let locator: ActionTextRef
    public let selectedText: String?
    public let proposedText: String?
    public init(locator: ActionTextRef, selectedText: String? = nil, proposedText: String? = nil) {
        self.locator = locator; self.selectedText = selectedText; self.proposedText = proposedText
    }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.locator == rhs.locator && exact(lhs.selectedText, rhs.selectedText) && exact(lhs.proposedText, rhs.proposedText)
    }
    private static func exact(_ lhs: String?, _ rhs: String?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): true
        case (.some(let left), .some(let right)): left.utf8.elementsEqual(right.utf8)
        default: false
        }
    }
}

public struct ActionPrepareNoteDraftCommand: Sendable, Equatable {
    public let draft: ActionNoteDraftRequest
    public let sceneID: String
    public let invocation: ActionPortInvocation
    public let navigationAuthorization: ActionNavigationPreparation?
    public init(draft: ActionNoteDraftRequest, sceneID: String, invocation: ActionPortInvocation,
                navigationAuthorization: ActionNavigationPreparation? = nil) {
        self.draft = draft; self.sceneID = sceneID; self.invocation = invocation
        self.navigationAuthorization = navigationAuthorization
    }
}

public struct ActionNoteDraftReceipt: Sendable, Equatable {
    public let requestId: UUID
    public let snapshot: ActionBackendSnapshot
    public let sceneID: String
    public let draft: ActionNoteDraftRequest
    public let isUnsaved: Bool
    public init(requestId: UUID, snapshot: ActionBackendSnapshot, sceneID: String,
                draft: ActionNoteDraftRequest, isUnsaved: Bool) {
        self.requestId = requestId; self.snapshot = snapshot; self.sceneID = sceneID
        self.draft = draft; self.isUnsaved = isUnsaved
    }
}

public enum ActionNoteDraftAcknowledgement: Sendable, Equatable {
    case acknowledged(ActionNoteDraftReceipt), queued(handle: String), requiresForeground
}

/// Opt-in adapter to the original note editor; it must not persist a draft.
/// Preparation retains original selection/source ownership before Core mints
/// its one-use grant. The scene owner releases it after the full Core result.
public protocol ActionNoteDraftUICommandSink: ActionUICommandSink {
    @MainActor func canPrepareNoteDraft(in sceneID: String) -> Bool
    @MainActor func prepareNoteDraft(_ draft: ActionNoteDraftRequest, context: ActionExecutionContext,
                                    invocation: ActionPortInvocation) async throws
    @MainActor func presentNoteDraft(_ command: ActionPrepareNoteDraftCommand) async throws -> ActionNoteDraftAcknowledgement
    /// Synchronous native/source observation after Core's final authority read.
    @MainActor func validateNoteDraftCompletion(_ receipt: ActionNoteDraftReceipt, invocation: ActionPortInvocation) throws
}


/// Pure validation of an ORIGINAL renderer-owned selection. This helper does
/// not discover a range, infer a locator or grant permission to read content.
public enum ActionNoteDraftSelection {
    public static func validate(_ request: ActionNoteDraftRequest, observedLocator: ActionTextRef,
                                sourceText: String, originalRange: NSRange) throws -> String {
        guard observedLocator == request.locator else { throw ActionPortError.staleState }
        let sourceLength = sourceText.utf16.count
        guard originalRange.location != NSNotFound, originalRange.location >= 0, originalRange.length > 0,
              originalRange.location <= sourceLength, originalRange.length <= sourceLength - originalRange.location,
              originalRange.length <= 20_000, let range = Range(originalRange, in: sourceText) else {
            throw ActionPortError.notSupported
        }
        // Foundation may produce a String range for the interior of a UTF-16
        // surrogate pair on Apple platforms. Prove both original code-unit
        // endpoints are exact scalar boundaries before slicing the source.
        let sourceUTF16 = sourceText.utf16
        let lowerUTF16 = sourceUTF16.index(sourceUTF16.startIndex, offsetBy: originalRange.location)
        let upperUTF16 = sourceUTF16.index(lowerUTF16, offsetBy: originalRange.length)
        guard lowerUTF16.samePosition(in: sourceText.unicodeScalars) != nil,
              upperUTF16.samePosition(in: sourceText.unicodeScalars) != nil else {
            throw ActionPortError.notSupported
        }
        let snippet = String(sourceText[range])
        guard snippet.unicodeScalars.count <= 10_000 else { throw ActionPortError.notSupported }
        if let selected = request.selectedText, !selected.utf8.elementsEqual(snippet.utf8) {
            throw ActionPortError.staleState
        }
        return snippet
    }
}
