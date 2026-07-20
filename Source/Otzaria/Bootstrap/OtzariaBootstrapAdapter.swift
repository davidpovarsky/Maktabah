import Foundation

@MainActor
enum OtzariaBootstrapAdapter {
    static func restoreForAppLaunch() throws -> Bool {
        try OtzariaMaktabahBridge.shared.restoreDatabaseIfPossible()
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
