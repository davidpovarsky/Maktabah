import Foundation

@MainActor
enum OtzariaBootstrapAdapter {
    static var isReadyForAppLaunch: Bool {
        OtzariaMaktabahBridge.shared.isEnabled
    }

    static var shouldSetupTarjamahConnection: Bool {
        !OtzariaMaktabahBridge.shared.isEnabled
    }

    static var shouldCheckCoreDatabaseUpdate: Bool {
        !OtzariaMaktabahBridge.shared.isEnabled
    }

    static func installDatabase(from url: URL) throws {
        try OtzariaMaktabahBridge.shared.installDatabase(from: url)
    }
}
