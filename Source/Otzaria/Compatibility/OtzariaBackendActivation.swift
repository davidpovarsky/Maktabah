import Foundation

enum OtzariaBackendActivation {
    static var isActive: Bool {
        let selected = UserDefaults.standard.string(forKey: BackendCoordinator.selectionDefaultsKey)
            .flatMap(BackendID.init(rawValue:)) ?? .otzaria
        #if os(iOS)
        return selected == .otzaria && OtzariaMaktabahBridge.shared.isEnabled
        #else
        return false
        #endif
    }
}
