import Foundation
import OtzariaActionCore
import OtzariaUIRouting

public struct NativeIntentOutcome: Error, LocalizedError, Sendable, Equatable {
    public let status: ActionStatus
    public let code: String
    public var errorDescription: String? {
        switch status {
        case .uiQueued: "Maktabah is waiting for the destination to become visible."
        case .requiresForeground: "Open Maktabah to continue navigation."
        case .requiresBackendSwitch: "Select the requested library in Maktabah before continuing."
        case .needsDisambiguation: "Choose the destination window in Maktabah."
        case .requiresConfirmation: "Confirm this request in Maktabah."
        case .staleState: "The destination changed. Choose it again."
        case .notSupported: "This destination is not available in the selected library."
        case .unavailable: "The destination is not ready. Try again in Maktabah."
        case .cancelled: "Navigation was cancelled."
        default: "Maktabah could not display this destination."
        }
    }
    public static func requireVisibleAcknowledgement(_ result: UISceneAcknowledgement) throws {
        let status: ActionStatus, code: String
        switch result {
        case .acknowledged: return
        case .queued: status = .uiQueued; code = "native_route_queued"
        case .requiresForeground: status = .requiresForeground; code = "exact_foreground_scene_required"
        case .requiresBackendSwitch: status = .requiresBackendSwitch; code = "backend_selection_required"
        case .needsDisambiguation: status = .needsDisambiguation; code = "scene_selection_required"
        case .notSupported(let failure): status = .notSupported; code = failure.code
        case .unavailable(let failure): status = .unavailable; code = failure.code
        case .staleState(let failure): status = .staleState; code = failure.code
        case .requiresConfirmation(let failure): status = .requiresConfirmation; code = failure.code
        case .cancelled: status = .cancelled; code = "native_route_cancelled"
        case .failed(let failure): status = .failed; code = failure.code
        }
        throw Self(status: status, code: code)
    }
}
