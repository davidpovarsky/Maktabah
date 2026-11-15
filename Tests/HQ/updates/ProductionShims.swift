import Foundation

// Compiler-only adapter doubles. No production backend, defaults or DB is initialized.
nonisolated(unsafe) var fixturePersistedBackend: String?
nonisolated(unsafe) var fixturePathReads = 0
final class UserDefaults: @unchecked Sendable {
    static let standard = UserDefaults()
    func string(forKey: String) -> String? { fixturePersistedBackend }
}
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    nonisolated static let selectionDefaultsKey = "HQ_UPDATES_COMPILER_ONLY"
    var activeBackendID = BackendID.otzaria
    var isTransitioning = false
    let generation: UInt64 = 0
}
enum AppConfig {
    static var mainDatabasePath: String? { fixturePathReads += 1; return nil }
    static var specialDatabasePath: String? { fixturePathReads += 1; return nil }
    static var archiveFilesPath: String? { fixturePathReads += 1; return nil }
    static var databaseFilesPath: String? { fixturePathReads += 1; return nil }
    static func archiveDatabasePath(archiveId: Int) -> String? { nil }
    static func archiveFtsDatabasePath(archiveId: Int) -> String? { nil }
}

// No I/O is permitted after the gate. These doubles make unexpected entry fail.
extension FileManager {
    func cleanupDirectory(at: URL) { fatalError("Unsupported backend reached cleanup") }
}
enum Logger {
    static let library = Log()
    struct Log: Sendable { func debug(_ message: Message) {} }
    struct Message: ExpressibleByStringInterpolation {
        init(stringLiteral value: String) {}
        init(stringInterpolation: StringInterpolation) {}
        struct StringInterpolation: StringInterpolationProtocol {
            enum Privacy { case `public` }
            init(literalCapacity: Int, interpolationCount: Int) {}
            mutating func appendLiteral(_ value: String) {}
            mutating func appendInterpolation<T>(_ value: T, privacy: Privacy) {}
        }
    }
}
