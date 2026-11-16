#if os(iOS)
import Foundation
import OtzariaActionCore
import OtzariaUIRouting
import ChavrusaUIRoutingHost

/// Called once by the existing onOpenURL handler, before WidgetDeepLink.
/// Legacy URLs return false and retain the original implementation unchanged.
@MainActor
enum MaktabahNativeURLHandler {
    static func handle(_ url: URL, manager: iOSNavigationManager) -> Bool {
        #if DEBUG
        let scheme = "maktabah-debug"
        #else
        let scheme = "maktabah"
        #endif
        guard url.scheme == scheme, url.host == "action" else { return false }
        Task { @MainActor in
            do {
                guard let result = try await MaktabahNativeRoutingComposition.shared.open(url: url, manager: manager) else { return }
                try NativeIntentOutcome.requireVisibleAcknowledgement(result)
            } catch {
                // Fixed error category only; never export the incoming URL,
                // its private payload, or an arbitrary Error description.
                let category = (error as? UIRouteError)?.code ?? (error as? NativeIntentOutcome)?.code ?? "native_link_not_acknowledged"
                OtzariaFileLogger.shared.log("[NativeNavigationFailure] code=\(category)")
                let message = (error as? NativeIntentOutcome)?.errorDescription ?? "This link could not be displayed in the selected library and window."
                manager.alertMessage = .init(title: "Unable to open link", message: message)
            }
        }
        return true
    }
}
#endif
