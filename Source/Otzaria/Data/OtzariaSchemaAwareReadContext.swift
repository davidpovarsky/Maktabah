import Foundation

/// Reuses the active bridge connection. No extra pool, database copy, or writer is created.
final class OtzariaSchemaAwareReadContext: @unchecked Sendable {
    static let shared = OtzariaSchemaAwareReadContext()
    private let cacheLock = NSLock()
    private weak var cachedDatabase: SQLiteDatabase?
    private var cachedSchemaVersion: Int?
    private var cachedCapabilities: OtzariaDatabaseCapabilities?
    private let fixtureDatabase: SQLiteDatabase?

    init(database: SQLiteDatabase? = nil) { fixtureDatabase = database }

    func snapshot<T>(database: SQLiteDatabase,
                     _ work: (SQLiteDatabase, OtzariaDatabaseCapabilities) throws -> T) throws -> T {
        var output: T?
        try database.transaction {
            try Task.checkCancellation()
            let version = try database.fetch(query: "PRAGMA schema_version") { $0.int(at: 0) }.first ?? 0
            let cached: OtzariaDatabaseCapabilities? = cacheLock.withLock {
                cachedDatabase === database && cachedSchemaVersion == version ? cachedCapabilities : nil
            }
            let capabilities = try cached ?? OtzariaDatabaseCapabilities(database: database)
            if cached == nil {
                cacheLock.withLock {
                    cachedDatabase = database
                    cachedSchemaVersion = version
                    cachedCapabilities = capabilities
                }
            }
            output = try work(database, capabilities)
            try Task.checkCancellation()
        }
        return output!
    }

    func read<T: Sendable>(_ work: @escaping @Sendable (SQLiteDatabase, OtzariaDatabaseCapabilities) throws -> T) async throws -> T {
        if let database = fixtureDatabase {
            let task = Task.detached(priority: .userInitiated) { [self] in
                try snapshot(database: database, work)
            }
            return try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
        }
        #if os(iOS)
        let task = Task.detached(priority: .userInitiated) { [self] in
            try OtzariaMaktabahBridge.shared.withDatabase { database in
                try snapshot(database: database, work)
            }
        }
        return try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
        #else
        throw LibraryBackendError.capabilityUnavailable
        #endif
    }
}
