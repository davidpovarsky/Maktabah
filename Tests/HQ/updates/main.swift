import Foundation
import SQLite3

// Portable checks compile the actual downstream service against the installed Windows SQLite SDK.
var checks = 0
@MainActor func check(_ name: String, _ body: () throws -> Void) rethrows {
    try body()
    checks += 1
    print("PASS \(name)")
}
func rejected(_ body: () throws -> Void) {
    do { try body(); fatalError("Expected fail-closed rejection") } catch { }
}
let buildRoot = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL.resolvingSymlinksInPath()
let expectedBuildRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent(".build").standardizedFileURL.resolvingSymlinksInPath()
precondition(buildRoot == expectedBuildRoot, "Fixtures must stay inside the leased test build directory")
let root = buildRoot.appendingPathComponent("fixture-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }
func path(_ name: String) -> String { root.appendingPathComponent(name).path }
func create(_ name: String, _ sql: String) throws -> String {
    let target = path(name)
    var db: OpaquePointer?
    guard sqlite3_open(target, &db) == SQLITE_OK, let db else { fatalError("Fixture open failed") }
    defer { sqlite3_close_v2(db) }
    guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { fatalError("Fixture SQL failed: \(String(cString: sqlite3_errmsg(db)))") }
    return target
}
let main = try create("main.sqlite", "CREATE TABLE '0bok'(bkid INTEGER PRIMARY KEY,cat INTEGER,bk TEXT,Archive INTEGER,betaka TEXT,authno INTEGER,inf TEXT,TafseerNam TEXT,bVer INTEGER,PdfCs INTEGER); INSERT INTO '0bok' VALUES(1,1,'sentinel',1,'',1,'','',1,0);")
let special = try create("special.sqlite", "CREATE TABLE Auth(authid INTEGER PRIMARY KEY,auth TEXT,inf TEXT,Lng TEXT,HigriD TEXT,oVer INTEGER);")
let beforeMain = try Data(contentsOf: URL(fileURLWithPath: main))
let beforeSpecial = try Data(contentsOf: URL(fileURLWithPath: special))
try check("compatible Maktabah core schema") {
    try MaktabahBookUpdateSafety.validateLibrary(backend: "maktabah", main: main, special: special)
}
for backend in [nil, "otzaria", "sefaria", "sefariaEmbedded", "unknown"] as [String?] {
    check("unsupported backend \(backend ?? "nil") rejected before path access") {
        rejected { try MaktabahBookUpdateSafety.validateLibrary(backend: backend, main: path("absent.sqlite"), special: special) }
        precondition(!FileManager.default.fileExists(atPath: path("absent.sqlite")))
    }
}
check("missing existing target never created") {
    rejected { _ = try MaktabahBookUpdateSafety.openReadOnly(path: path("absent.sqlite")) }
    precondition(!FileManager.default.fileExists(atPath: path("absent.sqlite")))
}
let wrong = try create("wrong.sqlite", "CREATE TABLE book(id INTEGER PRIMARY KEY,title TEXT); CREATE TABLE line(book_id INTEGER,content TEXT);")
check("Otzaria-like schema rejected with Maktabah backend claim") {
    rejected { try MaktabahBookUpdateSafety.validateLibrary(backend: "maktabah", main: wrong, special: special) }
}
let empty = try create("empty.sqlite", "PRAGMA user_version=0;")
check("empty schema rejected") {
    rejected { try MaktabahBookUpdateSafety.validateLibrary(backend: "maktabah", main: empty, special: special) }
}
check("same main/special identity rejected") {
    rejected { try MaktabahBookUpdateSafety.validateLibrary(backend: "maktabah", main: main, special: main) }
}
let missingColumn = try create("missing-column.sqlite", "CREATE TABLE '0bok'(bkid INTEGER,bVer INTEGER);")
check("partial metadata schema rejected") {
    rejected { try MaktabahBookUpdateSafety.validateLibrary(backend: "maktabah", main: missingColumn, special: special) }
}
let archive = try create("1.sqlite", "CREATE TABLE b1(nass BLOB,part INTEGER,id INTEGER,page INTEGER); CREATE TABLE t1(tit TEXT,lvl INTEGER,sub INTEGER,id INTEGER);")
let fts = try create("1_fts.sqlite", "CREATE TABLE archive_index(rowid INTEGER PRIMARY KEY,book_id INTEGER,page INTEGER,id INTEGER,part INTEGER); CREATE VIRTUAL TABLE archive_fts USING fts5(nass_clean);")
try check("compatible archive and unified FTS") { try MaktabahBookUpdateSafety.validateArchive(path: archive, ftsPath: fts) }
check("empty archive rejected before attach") { rejected { try MaktabahBookUpdateSafety.validateArchive(path: empty, ftsPath: fts) } }
check("missing FTS rejected without creation") {
    rejected { try MaktabahBookUpdateSafety.validateArchive(path: archive, ftsPath: path("absent-fts.sqlite")) }
    precondition(!FileManager.default.fileExists(atPath: path("absent-fts.sqlite")))
}
let badArchive = try create("bad-archive.sqlite", "CREATE TABLE b1(nonsense TEXT); CREATE TABLE t1(nonsense TEXT);")
check("archive names alone do not authorize mutation") { rejected { try MaktabahBookUpdateSafety.validateArchive(path: badArchive, ftsPath: fts) } }
let legacy = try create("legacy-fts.sqlite", "CREATE VIRTUAL TABLE b1_fts USING fts5(nass_clean);")
try check("compatible legacy FTS") { try MaktabahBookUpdateSafety.validateArchive(path: archive, ftsPath: legacy) }
let badFTS = try create("bad-fts.sqlite", "CREATE TABLE archive_index(id INTEGER); CREATE TABLE archive_fts(text TEXT);")
check("FTS names with wrong columns rejected") { rejected { try MaktabahBookUpdateSafety.validateArchive(path: archive, ftsPath: badFTS) } }
let corrupt = path("corrupt.sqlite")
try Data("not a sqlite file".utf8).write(to: URL(fileURLWithPath: corrupt))
check("corrupt input rejected without repair") { rejected { try MaktabahBookUpdateSafety.validateLibrary(backend: "maktabah", main: corrupt, special: special) } }
let view = try create("view.sqlite", "CREATE TABLE real(bkid INTEGER,bVer INTEGER); CREATE VIEW '0bok' AS SELECT * FROM real;")
check("views cannot impersonate writable metadata tables") { rejected { try MaktabahBookUpdateSafety.requireColumns(path: view, table: "0bok", columns: ["bkid", "bver"]) } }
try check("read-only preflight preserves core bytes and creates no sidecars") {
    let afterMain = try Data(contentsOf: URL(fileURLWithPath: main))
    let afterSpecial = try Data(contentsOf: URL(fileURLWithPath: special))
    precondition(afterMain == beforeMain)
    precondition(afterSpecial == beforeSpecial)
    for name in ["main.sqlite", "special.sqlite"] {
        for suffix in ["-wal", "-shm", "-journal"] { precondition(!FileManager.default.fileExists(atPath: path(name + suffix))) }
    }
}
print("EXECUTED_PASS \(checks) downstream safety checks; SQLite \(String(cString: sqlite3_libversion()))")

let parser = BookUpdateManager()
try check("actual upstream catalog parser valid header and quoted delimiter") {
    let rows = try parser.parseIndexCSV("bkid;cat;ver;file;size;name\n1;2;3;fixture-id;20;\"Book; title\"\n")
    precondition(rows.count == 1 && rows[0].bk == "Book; title")
}
check("actual catalog parser five-column row throws instead of trapping") {
    rejected { _ = try parser.parseIndexCSV("1;2;3;fixture-id;20") }
}
check("actual catalog parser rejects mixed valid/corrupt batch") {
    rejected { _ = try parser.parseIndexCSV("1;2;3;fixture-id;20;Book\n2;3;4;bad;50") }
}
check("actual catalog parser rejects negative size") { rejected { _ = try parser.parseIndexCSV("1;2;3;file;-1;Book") } }
check("actual catalog parser rejects unmatched quote") { rejected { _ = try parser.parseIndexCSV("1;2;3;file;20;\"Book") } }
check("actual catalog parser rejects integer overflow") { rejected { _ = try parser.parseIndexCSV("1;2;3;file;99999999999999999999999;Book") } }
try check("actual catalog parser permits empty lines") {
    let rows = try parser.parseIndexCSV("\n\n")
    precondition(rows.isEmpty)
}
print("EXECUTED_PASS \(checks) total safety/catalog checks")
try check("staging capacity includes copies and overhead") {
    try MaktabahBookUpdateSafety.validateStagingCapacity(requiredBytes: 10, availableBytes: 64 * 1024 * 1024 + 30)
}
check("staging capacity rejects shortage before download") { rejected { try MaktabahBookUpdateSafety.validateStagingCapacity(requiredBytes: 10, availableBytes: 29) } }
check("staging capacity rejects arithmetic overflow") { rejected { try MaktabahBookUpdateSafety.validateStagingCapacity(requiredBytes: Int64.max, availableBytes: Int64.max) } }
check("staging capacity rejects negative catalog size") { rejected { try MaktabahBookUpdateSafety.validateStagingCapacity(requiredBytes: -1, availableBytes: Int64.max) } }
print("EXECUTED_PASS \(checks) total checks including disk budget")
try check("book identity matches catalog") { try MaktabahBookUpdateSafety.validateBookIdentity(expected: 1, actual: 1, archive: 1) }
check("book identity mismatch blocked") { rejected { try MaktabahBookUpdateSafety.validateBookIdentity(expected: 1, actual: 2, archive: 1) } }
check("invalid archive identity blocked") { rejected { try MaktabahBookUpdateSafety.validateBookIdentity(expected: 1, actual: 1, archive: 0) } }
let fakeFTS = try create("fake-fts.sqlite", "CREATE TABLE archive_index(rowid INTEGER PRIMARY KEY,book_id INTEGER,page INTEGER,id INTEGER,part INTEGER); CREATE TABLE archive_fts(nass_clean TEXT);")
check("ordinary table cannot impersonate an FTS5 index") { rejected { try MaktabahBookUpdateSafety.validateArchive(path: archive, ftsPath: fakeFTS) } }
print("EXECUTED_PASS \(checks) total schema/catalog/capacity/identity checks")
var attachHost: OpaquePointer?
precondition(sqlite3_open_v2(archive, &attachHost, SQLITE_OPEN_READWRITE | SQLITE_OPEN_URI, nil) == SQLITE_OK)
defer { sqlite3_close_v2(attachHost) }
@MainActor func attach(_ target: String) -> Int32 {
    var stmt: OpaquePointer?
    precondition(sqlite3_prepare_v2(attachHost, "ATTACH DATABASE ? AS probe", -1, &stmt, nil) == SQLITE_OK)
    defer { sqlite3_finalize(stmt) }
    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    _ = target.withCString { sqlite3_bind_text(stmt, 1, $0, -1, transient) }
    return sqlite3_step(stmt)
}
check("URI attachment refuses a missing writable target without creating it") {
    let absent = path("absent-attach.sqlite")
    precondition(attach(MaktabahBookUpdateSafety.existingDatabaseURI(path: absent)) != SQLITE_DONE)
    precondition(!FileManager.default.fileExists(atPath: absent))
}
check("readonly attachment resolves escaped Unicode and punctuation paths") {
    let named = path("ספר # % name.sqlite")
    try! FileManager.default.copyItem(atPath: special, toPath: named)
    precondition(attach(MaktabahBookUpdateSafety.existingDatabaseURI(path: named, readOnly: true)) == SQLITE_DONE)
    precondition(sqlite3_exec(attachHost, "CREATE TABLE probe.denied(x)", nil, nil, nil) != SQLITE_OK)
    precondition(sqlite3_exec(attachHost, "DETACH DATABASE probe", nil, nil, nil) == SQLITE_OK)
    precondition(MaktabahBookUpdateSafety.existingDatabaseURI(path: path("virtual?name.sqlite")).contains("%3F"))
}
print("EXECUTED_PASS \(checks) total portable checks including existing-only ATTACH")

try check("catalog preserves escaped quotes, Hebrew, BOM and CRLF") {
    let entries = try parser.parseIndexCSV("\u{FEFF}bkid;cat;ver;file;size;name\r\n1;2;3;fixture-id;20;\"ספר \"\"אחד\"\"; title\"\r\n")
    precondition(entries.count == 1 && entries[0].bk == "ספר \"אחד\"; title")
}
try check("catalog preserves quoted newlines") {
    let entries = try parser.parseIndexCSV("1;2;3;fixture-id;20;\"first\nsecond\"")
    precondition(entries[0].bk == "first\nsecond")
}
for (name, csv) in [
    ("quote in unquoted field", "1;2;3;fixture-id;20;Bo\"ok\""),
    ("junk after closing quote", "1;2;3;fixture-id;20;\"Book\"junk"),
    ("two unclosed quoted fields with even quote count", "1;2;3;fixture-id;20;\"Book\n2;2;3;file;20;\"Other"),
    ("NUL in quoted field", "1;2;3;fixture-id;20;\"Bo\0ok\""),
    ("extra column", "1;2;3;fixture-id;20;Book;unexpected"),
    ("download query injection", "1;2;3;file&export=other;20;Book"),
    ("duplicate book identities", "1;2;3;file;20;Book\n1;2;4;file;30;Other"),
] {
    check("catalog rejects \(name)") { rejected { _ = try parser.parseIndexCSV(csv) } }
}
try check("author catalog valid header, BOM and blank lines") {
    let entries = try parser.parseAuthIndexCSV("\u{FEFF}authid;version;file\r\n\r\n1;3;author_file\r\n")
    precondition(entries.count == 1 && entries[0].authId == 1 && entries[0].versionName == 3)
}
for (name, csv) in [
    ("partial batch", "1;3;file\n2;3"),
    ("negative version", "1;-1;file"),
    ("overflowing version", "1;999999999999999999999999;file"),
    ("duplicate authors", "1;3;file\n1;4;other"),
    ("invalid author identity", "0;3;file"),
    ("query injection", "1;3;file&other=value"),
    ("malformed quoting", "1;3;\"file"),
] {
    check("author catalog rejects \(name)") { rejected { _ = try parser.parseAuthIndexCSV(csv) } }
}
check("bounded catalog rejects oversized payload") {
    rejected { _ = try MaktabahBookUpdateSafety.catalogRows(String(repeating: "a", count: 8 * 1024 * 1024 + 1)) }
}
check("bounded catalog rejects excessive row count") {
    rejected { _ = try MaktabahBookUpdateSafety.catalogRows(String(repeating: "\n", count: 100_001)) }
}
print("EXECUTED_PASS \(checks) total portable service/production-parser checks")

func openWriter(_ path: String) -> OpaquePointer {
    var db: OpaquePointer?
    precondition(sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_URI, nil) == SQLITE_OK)
    sqlite3_busy_timeout(db, 0)
    return db!
}
func sql(_ db: OpaquePointer, _ text: String) {
    precondition(sqlite3_exec(db, text, nil, nil, nil) == SQLITE_OK, String(cString: sqlite3_errmsg(db)))
}
func scalar(_ db: OpaquePointer, _ text: String) -> Int64 {
    var statement: OpaquePointer?
    precondition(sqlite3_prepare_v2(db, text, -1, &statement, nil) == SQLITE_OK)
    defer { sqlite3_finalize(statement) }
    precondition(sqlite3_step(statement) == SQLITE_ROW)
    return sqlite3_column_int64(statement, 0)
}

try check("busy WAL checkpoint reports failure and preserves committed data") {
    let target = try create("busy-recovery.sqlite", "CREATE TABLE sentinel(value INTEGER); INSERT INTO sentinel VALUES(1);")
    let writer = openWriter(target)
    sql(writer, "PRAGMA journal_mode=WAL; PRAGMA wal_autocheckpoint=0;")
    let reader = try MaktabahBookUpdateSafety.openReadOnly(path: target)
    defer { sqlite3_close_v2(reader) }
    sql(reader, "BEGIN;")
    precondition(scalar(reader, "SELECT COUNT(*) FROM sentinel") == 1)
    sql(writer, "INSERT INTO sentinel VALUES(2);")
    do {
        try MaktabahBookUpdateSafety.checkpointAndClose(writer, schemas: ["main"])
        fatalError("Busy checkpoint must not publish success")
    } catch let error as NSError {
        precondition(error.domain == "MaktabahBookUpdateRecovery" && error.code == Int(SQLITE_BUSY))
        precondition(error.localizedDescription.contains("Recovery files were preserved"))
    }
    let recoveryData = try Data(contentsOf: URL(fileURLWithPath: target + "-wal"))
    precondition(recoveryData.count > 0)
    let reopened = try MaktabahBookUpdateSafety.openReadOnly(path: target)
    defer { sqlite3_close_v2(reopened) }
    precondition(scalar(reopened, "SELECT COUNT(*) FROM sentinel") == 2)
    precondition(scalar(reader, "SELECT COUNT(*) FROM sentinel") == 1)
    sql(reader, "COMMIT;")
}
try check("successful checkpoint closes safely and reopens committed content") {
    let target = try create("checkpoint-success.sqlite", "CREATE TABLE sentinel(value INTEGER);")
    let writer = openWriter(target)
    sql(writer, "PRAGMA journal_mode=WAL; INSERT INTO sentinel VALUES(9);")
    try MaktabahBookUpdateSafety.checkpointAndClose(writer, schemas: ["main"])
    let reopened = try MaktabahBookUpdateSafety.openReadOnly(path: target)
    defer { sqlite3_close_v2(reopened) }
    precondition(scalar(reopened, "SELECT value FROM sentinel") == 9)
}
try check("closing after a checkpoint failure rolls back an uncommitted write") {
    let target = try create("rollback-recovery.sqlite", "CREATE TABLE sentinel(value INTEGER); INSERT INTO sentinel VALUES(1);")
    let writer = openWriter(target)
    sql(writer, "PRAGMA journal_mode=WAL; BEGIN IMMEDIATE; UPDATE sentinel SET value=99;")
    do {
        try MaktabahBookUpdateSafety.checkpointAndClose(writer, schemas: ["main"])
        fatalError("Checkpoint during a write transaction must fail")
    } catch let error as NSError {
        precondition(error.domain == "MaktabahBookUpdateRecovery" && error.code == Int(SQLITE_LOCKED))
    }
    let reopened = try MaktabahBookUpdateSafety.openReadOnly(path: target)
    defer { sqlite3_close_v2(reopened) }
    precondition(scalar(reopened, "SELECT value FROM sentinel") == 1)
}
try check("attached FTS checkpoint failure preserves archive and FTS recovery independently") {
    let target = try create("attached-recovery.sqlite", "CREATE TABLE sentinel(value INTEGER); INSERT INTO sentinel VALUES(1);")
    let search = try create("attached-recovery-fts.sqlite", "CREATE VIRTUAL TABLE archive_fts USING fts5(nass_clean); INSERT INTO archive_fts VALUES('old');")
    let ftsWriter = openWriter(search)
    sql(ftsWriter, "PRAGMA journal_mode=WAL; PRAGMA wal_autocheckpoint=0;")
    let ftsReader = try MaktabahBookUpdateSafety.openReadOnly(path: search)
    defer { sqlite3_close_v2(ftsReader) }
    sql(ftsReader, "BEGIN;")
    precondition(scalar(ftsReader, "SELECT COUNT(*) FROM archive_fts WHERE archive_fts MATCH 'old'") == 1)
    sql(ftsWriter, "INSERT INTO archive_fts VALUES('fresh');")
    sqlite3_close_v2(ftsWriter)
    let writer = openWriter(target)
    sql(writer, "PRAGMA journal_mode=WAL; INSERT INTO sentinel VALUES(2);")
    let uri = MaktabahBookUpdateSafety.existingDatabaseURI(path: search).replacingOccurrences(of: "'", with: "''")
    sql(writer, "ATTACH DATABASE '\(uri)' AS fts_db;")
    do {
        try MaktabahBookUpdateSafety.checkpointAndClose(writer)
        fatalError("Busy FTS checkpoint must fail even if archive checkpoint succeeds")
    } catch let error as NSError {
        precondition(error.domain == "MaktabahBookUpdateRecovery" && error.code == Int(SQLITE_BUSY))
        precondition(error.localizedDescription.contains("fts_db"))
    }
    let recoveryData = try Data(contentsOf: URL(fileURLWithPath: search + "-wal"))
    precondition(recoveryData.count > 0)
    let archiveReopened = try MaktabahBookUpdateSafety.openReadOnly(path: target)
    defer { sqlite3_close_v2(archiveReopened) }
    precondition(scalar(archiveReopened, "SELECT COUNT(*) FROM sentinel") == 2)
    let ftsReopened = try MaktabahBookUpdateSafety.openReadOnly(path: search)
    defer { sqlite3_close_v2(ftsReopened) }
    precondition(scalar(ftsReopened, "SELECT COUNT(*) FROM archive_fts WHERE archive_fts MATCH 'fresh'") == 1)
    sql(ftsReader, "COMMIT;")
}
print("EXECUTED_PASS \(checks) total portable checks including WAL recovery fault injection")
