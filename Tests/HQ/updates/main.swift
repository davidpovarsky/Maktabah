import Foundation
import SQLite3

// Portable checks compile the actual downstream service against the installed Windows SQLite SDK.
var checks = 0
func check(_ name: String, _ body: () throws -> Void) rethrows {
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
func attach(_ target: String) -> Int32 {
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
