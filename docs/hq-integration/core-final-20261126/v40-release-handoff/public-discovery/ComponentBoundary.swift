import Foundation

enum AppConfig { static let appSupportDir: URL? = nil }
@MainActor final class OtzariaMaktabahBridge {
    static let shared = OtzariaMaktabahBridge()
    var isEnabled: Bool { false }
    func installDatabase(from url: URL) throws { fatalError("Application bridge not part of component test") }
    func activateManagedDatabase(at url: URL) throws { fatalError("Application bridge not part of component test") }
    func restoreDatabaseIfPossible() throws -> Bool { fatalError("Application bridge not part of component test") }
    func resetConnection() { fatalError("Application bridge not part of component test") }
}
@MainActor final class OtzariaTantivySearchRepository {
    static let shared = OtzariaTantivySearchRepository()
    func closeAllEngines() { fatalError("Search not part of component test") }
}
