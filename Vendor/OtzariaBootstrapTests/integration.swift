import Foundation

enum AppConfig {
    static var appSupportDir: URL?
}

enum OtzariaDatabaseDownloader {
    static func fileSize(at url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }
}

final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }

    var current: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError("failed: \(message)") }
}

func makeSQLite(at url: URL, includeAllTables: Bool, marker: String) throws -> Data {
    do {
        let database = try SQLiteDatabase(path: url.path)
        try database.execute(query: "CREATE TABLE book (id INTEGER PRIMARY KEY, title TEXT)")
        try database.execute(query: "INSERT INTO book (title) VALUES (?)", parameters: [marker])
        if includeAllTables {
            try database.execute(query: "CREATE TABLE line (id INTEGER PRIMARY KEY, bookId INTEGER, content TEXT)")
            try database.execute(query: "CREATE TABLE category (id INTEGER PRIMARY KEY, title TEXT)")
        }
    }
    return try Data(contentsOf: url)
}

func compress(_ source: Data, to url: URL) throws {
    let capacity = ZSTD_compressBound(source.count)
    var output = Data(count: capacity)
    let result = output.withUnsafeMutableBytes { destination in
        source.withUnsafeBytes { input in
            ZSTD_compress(
                destination.baseAddress,
                capacity,
                input.baseAddress,
                source.count,
                3
            )
        }
    }
    guard ZSTD_isError(result) == 0 else {
        fatalError(String(cString: ZSTD_getErrorName(result)))
    }
    output.count = result
    try output.write(to: url)
}

func release(size: Int64, id: Int64) -> OtzariaLibraryRelease {
    OtzariaLibraryRelease(
        id: id,
        tag: "fixture-\(id)",
        asset: .init(
            id: id * 10,
            name: "seforim.db.zst",
            downloadURL: URL(string: "https://example.test/seforim.db.zst")!,
            compressedSize: size,
            digest: nil,
            updatedAt: nil
        )
    )
}

@main
enum OtzariaBootstrapIntegrationHarness {
static func main() throws {
let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("otzaria-bootstrap-tests-\(UUID().uuidString)", isDirectory: true)
let appSupport = root.appendingPathComponent("Application Support/Maktabah", isDirectory: true)
let downloads = root.appendingPathComponent("Caches/Otzaria/Downloads", isDirectory: true)
try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }
AppConfig.appSupportDir = appSupport

let storage = OtzariaDatabaseStorage(appSupportRoot: appSupport, downloadsRoot: downloads)
let installer = OtzariaDatabaseInstaller()
let extractor = OtzariaZstdStreamExtractor()

let currentProjection = OtzariaBookSchemaCompatibility.projection(
    columns: ["id", "title", "categoryId"]
)
expect(currentProjection.filePath == "NULL", "current schema path fallback")
expect(currentProjection.fileType == "'txt'", "current schema type fallback")
expect(currentProjection.eligiblePredicate == "1 = 1", "current schema eligibility")
let currentTOCProjection = OtzariaTOCSchemaCompatibility.projection(columns: ["id", "lineId"])
expect(currentTOCProjection.resolvedLineIndex == "ln.lineIndex", "current TOC lineId fallback")
let legacyProjection = OtzariaBookSchemaCompatibility.projection(
    columns: ["id", "filePath", "fileType", "volume", "pages"]
)
expect(legacyProjection.filePath == "b.filePath", "legacy path column")
expect(legacyProjection.eligiblePredicate.contains("fileType"), "legacy link filtering")
let legacyTOCProjection = OtzariaTOCSchemaCompatibility.projection(columns: ["id", "lineId", "lineIndex"])
expect(legacyTOCProjection.resolvedLineIndex == "COALESCE(te.lineIndex, ln.lineIndex)", "legacy TOC lineIndex fallback")

let sourceURL = root.appendingPathComponent("valid.sqlite")
let source = try makeSQLite(at: sourceURL, includeAllTables: true, marker: "first")
let archive = root.appendingPathComponent("valid.sqlite.zst")
try compress(source, to: archive)

let extracted = root.appendingPathComponent("streamed.sqlite")
let progressCalls = LockedCounter()
let extractedBytes = try extractor.extract(archiveURL: archive, outputURL: extracted) { consumed, total in
    expect(consumed <= total, "bounded extraction progress")
    progressCalls.increment()
}
expect(extractedBytes == Int64(source.count), "streaming output size")
let streamedBytes = try Data(contentsOf: extracted)
expect(streamedBytes == source, "streaming output bytes")
expect(progressCalls.current > 0, "streaming progress")

let corrupt = root.appendingPathComponent("corrupt.zst")
try Data("not a zstd frame".utf8).write(to: corrupt)
let corruptOutput = root.appendingPathComponent("corrupt-output.sqlite")
do {
    _ = try extractor.extract(archiveURL: corrupt, outputURL: corruptOutput) { _, _ in }
    fatalError("corrupt zstd was accepted")
} catch {}
expect(!FileManager.default.fileExists(atPath: corruptOutput.path), "failed extraction removes output")

let prepared = try installer.prepare(
    archiveURL: archive,
    release: release(size: Int64((try Data(contentsOf: archive)).count), id: 1),
    storage: storage,
    progress: { _, _ in },
    validationStarted: {}
)
let finalURL = try installer.promote(prepared, storage: storage)
expect(FileManager.default.fileExists(atPath: finalURL.path), "initial atomic promotion")
try OtzariaDatabaseAccessController.shared.validateDatabase(at: finalURL)
let installedBeforeFailure = try Data(contentsOf: finalURL)

let missingURL = root.appendingPathComponent("missing.sqlite")
let missingSource = try makeSQLite(at: missingURL, includeAllTables: false, marker: "invalid")
let missingArchive = root.appendingPathComponent("missing.sqlite.zst")
try compress(missingSource, to: missingArchive)
do {
    _ = try installer.prepare(
        archiveURL: missingArchive,
        release: release(size: Int64((try Data(contentsOf: missingArchive)).count), id: 2),
        storage: storage,
        progress: { _, _ in },
        validationStarted: {}
    )
    fatalError("missing required tables were accepted")
} catch {}
let installedAfterFailure = try Data(contentsOf: finalURL)
expect(installedAfterFailure == installedBeforeFailure, "old DB survives failed staging")
expect(!FileManager.default.fileExists(atPath: storage.stagingDatabaseURL.path), "failed staging is removed")

let secondURL = root.appendingPathComponent("second.sqlite")
let secondSource = try makeSQLite(at: secondURL, includeAllTables: true, marker: "second")
let secondArchive = root.appendingPathComponent("second.sqlite.zst")
try compress(secondSource, to: secondArchive)
let preparedSecond = try installer.prepare(
    archiveURL: secondArchive,
    release: release(size: Int64((try Data(contentsOf: secondArchive)).count), id: 3),
    storage: storage,
    progress: { _, _ in },
    validationStarted: {}
)
let staleWAL = URL(fileURLWithPath: finalURL.path + "-wal")
try Data("stale".utf8).write(to: staleWAL)
_ = try installer.promote(preparedSecond, storage: storage)
expect(!FileManager.default.fileExists(atPath: staleWAL.path), "stale managed WAL removed")
try OtzariaDatabaseAccessController.shared.validateDatabase(at: finalURL)
expect(FileManager.default.fileExists(atPath: storage.installationManifestURL.path), "manifest written")

let controller = OtzariaDatabaseAccessController.shared
_ = try controller.activateManagedDatabase(at: finalURL)
if case .managedInternal? = controller.source {} else {
    fatalError("failed: managed database activation")
}
controller.clearSelection()
let restoredManaged = try controller.restoreIfNeeded()
expect(restoredManaged?.standardizedFileURL == finalURL.standardizedFileURL, "managed bootstrap restore")
controller.clearSelection(deleteManagedInternalDatabase: true)
let restoredAfterRemoval = try controller.restoreIfNeeded()
expect(restoredAfterRemoval == nil, "no database returns to bootstrap confirmation")

print("Otzaria zstd, SQLite validation, and atomic installer tests passed")
}
}
