import Foundation

// Compiler-only adapter doubles. No production backend, defaults or DB is initialized.
enum FixtureBackendID: String { case otzaria, sefaria, sefariaEmbedded }
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    nonisolated static let selectionDefaultsKey = "HQ_UPDATES_COMPILER_ONLY"
    let activeBackendID = FixtureBackendID.otzaria
    let isTransitioning = false
    let generation: UInt64 = 0
}
enum AppConfig {
    static var mainDatabasePath: String? { nil }
    static var specialDatabasePath: String? { nil }
    static var archiveFilesPath: String? { nil }
    static func archiveDatabasePath(archiveId: Int) -> String? { nil }
    static func archiveFtsDatabasePath(archiveId: Int) -> String? { nil }
}
