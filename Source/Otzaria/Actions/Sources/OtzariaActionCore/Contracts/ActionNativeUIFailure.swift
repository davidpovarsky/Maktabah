import Foundation

/// Trusted native command ports can preserve a failure after an actual UI
/// effect. It carries no provider text and never promises safe automatic retry.
public struct ActionNativeUIFailure: Error, Sendable, Equatable {
    public let status: ActionStatus
    public let failure: ActionFailure
    public init(status: ActionStatus, failure: ActionFailure) {
        let statuses: Set<ActionStatus> = [.notSupported, .unavailable, .staleState, .cancelled, .failed, .requiresForeground, .requiresConfirmation]
        self.status = statuses.contains(status) ? status : .failed
        let codes: Set<String> = [
            "native_effect_uncertain", "native_ui_failed", "native_presentation_in_progress",
            "exact_note_selection_unavailable", "original_note_editor_not_visible", "native_search_results_unavailable",
            "native_dispatch_ledger_full", "native_scene_busy", "native_context_changed", "scene_lifetime_changed",
            "backend_generation_changed", "deadline_exceeded", "cancelled", "permission_denied"
        ]
        let code = codes.contains(failure.code) ? failure.code : "native_ui_failed"
        self.failure = .init(code: code, message: "Native action could not complete (\(code)).", retryable: false)
    }
}
