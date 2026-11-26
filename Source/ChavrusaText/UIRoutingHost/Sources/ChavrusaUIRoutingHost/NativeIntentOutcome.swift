import Foundation
import OtzariaActionCore
import OtzariaUIRouting

public struct NativeIntentOutcome: Error, LocalizedError, Sendable, Equatable {
    public let status: ActionStatus
    public let code: String
    public var errorDescription: String? {
        switch status {
        case .uiQueued: NSLocalizedString("Maktabah is waiting for the destination to become visible.", comment: "System intent navigation outcome")
        case .requiresForeground: NSLocalizedString("Open Maktabah to continue navigation.", comment: "System intent navigation outcome")
        case .requiresBackendSwitch: NSLocalizedString("Select the requested library in Maktabah before continuing.", comment: "System intent navigation outcome")
        case .needsDisambiguation: NSLocalizedString("Choose the destination window in Maktabah.", comment: "System intent navigation outcome")
        case .requiresConfirmation: NSLocalizedString("Confirm this request in Maktabah.", comment: "System intent navigation outcome")
        case .staleState: NSLocalizedString("The destination changed. Choose it again.", comment: "System intent navigation outcome")
        case .notSupported: NSLocalizedString("This destination is not available in the selected library.", comment: "System intent navigation outcome")
        case .unavailable: NSLocalizedString("The destination is not ready. Try again in Maktabah.", comment: "System intent navigation outcome")
        case .cancelled: NSLocalizedString("Navigation was cancelled.", comment: "System intent navigation outcome")
        default: NSLocalizedString("Maktabah could not display this destination.", comment: "System intent navigation outcome")
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
