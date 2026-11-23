import Foundation
import SQLite3
import CryptoKit

// Same explicit test-only telemetry/log boundary as the retained full-v32
// source-service harness. Original SQLite/Reader/dictionary decoding is compiled.
struct OtzariaPerformanceTelemetry: Sendable {
    static let shared = Self()
    struct Interval { func end(extra: String) {} }
    func begin(_ name: String) -> Interval { .init() }
}
struct OtzariaFileLogger: Sendable {
    static let shared = Self()
    func log(_ value: String) { print(value) }
}

private struct EvidenceFailure: Error, CustomStringConvertible {
    let description: String
}
private func require(_ value: @autoclosure () -> Bool, _ message: String) throws {
    if !value() { throw EvidenceFailure(description: message) }
}
private func digest(_ text: String) -> String {
    SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
}

// Length framing and fixed field order preserve exact UTF8 bytes, including
// optional values. Swift String equality alone allows Unicode equivalence.
private struct UnitDigest {
    var value = SHA256()
    mutating func string(_ text: String) {
        let bytes = Data(text.utf8)
        var count = UInt64(bytes.count).bigEndian
        withUnsafeBytes(of: &count) { value.update(data: Data($0)) }
        value.update(data: bytes)
    }
    mutating func integer(_ number: Int) { string(String(number)) }
    mutating func optionalString(_ text: String?) {
        integer(text == nil ? 0 : 1)
        if let text { string(text) }
    }
    mutating func optionalInteger(_ number: Int?) {
        integer(number == nil ? 0 : 1)
        if let number { integer(number) }
    }
    mutating func anchor(_ anchor: OtzariaLineAnchor) {
        integer(anchor.id); integer(anchor.bookId); integer(anchor.lineIndex)
        optionalString(anchor.heRef); string(anchor.text)
        integer(anchor.range.location); integer(anchor.range.length)
    }
    mutating func finish() -> String {
        value.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
private func exactUnitDigest(_ unit: OtzariaReadingUnit) -> String {
    var hash = UnitDigest()
    hash.string("OtzariaReadingUnit-complete-v1")
    hash.string(unit.id); hash.integer(unit.bookId); hash.string(unit.mode.rawValue)
    hash.optionalInteger(unit.tocEntryId); hash.optionalString(unit.title)
    hash.optionalInteger(unit.level)
    hash.integer(unit.startLineIndex); hash.integer(unit.endLineIndex)
    hash.integer(unit.sourceLineIndices.count)
    for index in unit.sourceLineIndices { hash.integer(index) }
    hash.integer(unit.lineAnchors.count)
    for anchor in unit.lineAnchors { hash.anchor(anchor) }
    hash.string(unit.html); hash.string(unit.plainText); hash.optionalString(unit.heRef)
    return hash.finish()
}
private func anchorsDigest(_ unit: OtzariaReadingUnit) -> String {
    var hash = UnitDigest()
    hash.string("OtzariaLineAnchor-array-v1"); hash.integer(unit.lineAnchors.count)
    for anchor in unit.lineAnchors { hash.anchor(anchor) }
    return hash.finish()
}
private func descriptorDigest(_ descriptors: [OtzariaReadingUnitDescriptor?]) -> String {
    var hash = UnitDigest()
    hash.string("OtzariaReadingUnitDescriptor-current-previous-next-v1")
    for item in descriptors {
        hash.integer(item == nil ? 0 : 1)
        guard let item else { continue }
        hash.string(item.id); hash.integer(item.bookId); hash.string(item.mode.rawValue)
        hash.integer(item.includeDescendants ? 1 : 0)
        hash.optionalInteger(item.tocEntryId); hash.optionalString(item.title)
        hash.optionalInteger(item.level)
        hash.integer(item.startLineIndex); hash.integer(item.endLineIndex)
        hash.integer(item.sourceLineIndices.count)
        for index in item.sourceLineIndices { hash.integer(index) }
        hash.optionalString(item.heRef)
        hash.optionalInteger(item.previousStartLineIndex); hash.optionalInteger(item.nextStartLineIndex)
    }
    return hash.finish()
}

@main
struct PairedReaderTiming {
    struct Input: Decodable { let uri: String }

    private static func verify(_ unit: OtzariaReadingUnit) throws {
        try require(unit.id == "toc:851774" && unit.bookId == 5869 && unit.mode == .chapter,
                    "Original full-v32 chapter identity changed")
        try require(unit.sourceLineIndices == Array(40920...151115), "Original full source index set changed")
        try require(unit.lineAnchors.count == 110196, "Missing full-chapter anchors")
        try require(unit.startLineIndex == 40920 && unit.endLineIndex == 151115,
                    "Original chapter bounds changed")
        try require(unit.html.utf8.count == 30583708 && unit.plainText.utf8.count == 30245157,
                    "Original full text byte counts changed")
        let text = unit.plainText as NSString
        var nextLocation = 0
        for (index, anchor) in zip(unit.sourceLineIndices, unit.lineAnchors) {
            try require(anchor.bookId == unit.bookId && anchor.lineIndex == index, "Anchor identity changed")
            try require(anchor.range.location == nextLocation && anchor.range.length == anchor.text.utf16.count,
                        "UTF16 offset or length changed")
            try require(NSMaxRange(anchor.range) <= text.length, "Anchor escaped original full text")
            let slice = text.substring(with: anchor.range)
            try require(Data(slice.utf8) == Data(anchor.text.utf8), "Anchor UTF8 content differs from exact UTF16 slice")
            nextLocation = NSMaxRange(anchor.range) + 1
        }
        try require(nextLocation - 1 == text.length, "Final original anchor boundary changed")
    }

    // Exactly two same-process service-cache-cold/warm reads per implementation,
    // in AB then BA order. Equality, digests, SQL witnesses and JSON are OUTSIDE timers.
    private static func measure(
        _ version: String, round: Int, clear: () -> Void,
        read: () throws -> OtzariaReadingUnit?
    ) throws -> (record: [String: Any], unit: OtzariaReadingUnit) {
        clear()
        let coldStart = ProcessInfo.processInfo.systemUptime
        guard let cold = try read() else { throw EvidenceFailure(description: "Missing cold chapter") }
        let coldMS = (ProcessInfo.processInfo.systemUptime - coldStart) * 1000
        let warmStart = ProcessInfo.processInfo.systemUptime
        guard let warm = try read() else { throw EvidenceFailure(description: "Missing warm chapter") }
        let warmMS = (ProcessInfo.processInfo.systemUptime - warmStart) * 1000
        try require(cold == warm, "Original full unit cold/warm semantic equality failed")
        let fullDigest = exactUnitDigest(cold)
        try require(fullDigest == exactUnitDigest(warm), "Original full unit cold/warm exact-byte equality failed")
        try verify(cold)
        return ([
            "round": round, "version": version, "cold_ms": coldMS, "warm_ms": warmMS,
            "rows": cold.sourceLineIndices.count, "complete_unit_sha256": fullDigest,
            "html_sha256": digest(cold.html), "plain_text_sha256": digest(cold.plainText),
            "anchors_sha256": anchorsDigest(cold),
            "html_utf8_bytes": cold.html.utf8.count, "plain_utf8_bytes": cold.plainText.utf8.count,
            "cold_warm_complete_equality": true, "all_anchors_checked": cold.lineAnchors.count
        ], cold)
    }

    static func main() throws {
        let input = try JSONDecoder().decode(Input.self, from: Data(contentsOf:
            URL(fileURLWithPath: CommandLine.arguments[1])))
        let output = URL(fileURLWithPath: CommandLine.arguments[2])
        let database = try SQLiteDatabase(path: input.uri,
            flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_FULLMUTEX, queryOnly: true)
        try require(sqlite3_db_readonly(database.dbPointer, "main") == 1, "Original database must be read-only")
        let baseline = BaselineOtzariaReadingUnitService(database: database)
        let candidate = OtzariaReadingUnitService(database: database)
        var records: [[String: Any]] = []
        var roundProofs: [[String: Any]] = []
        var allUnitDigests = Set<String>()
        for round in 0..<2 {
            let order = round == 0 ? ["baseline", "candidate"] : ["candidate", "baseline"]
            var baselineUnit: OtzariaReadingUnit?
            var candidateUnit: OtzariaReadingUnit?
            for version in order {
                let measured: (record: [String: Any], unit: OtzariaReadingUnit)
                if version == "baseline" {
                    measured = try measure(version, round: round, clear: { baseline.clearCaches() },
                        read: { try baseline.readingUnit(bookId: 5869, containingLineIndex: 95380, mode: .chapter) })
                    baselineUnit = measured.unit
                } else {
                    measured = try measure(version, round: round, clear: { candidate.clearCaches() },
                        read: { try candidate.readingUnit(bookId: 5869, containingLineIndex: 95380, mode: .chapter) })
                    candidateUnit = measured.unit
                }
                records.append(measured.record)
                allUnitDigests.insert(measured.record["complete_unit_sha256"] as! String)
            }
            guard let baselineUnit, let candidateUnit else {
                throw EvidenceFailure(description: "Both original implementations must execute")
            }
            try require(baselineUnit == candidateUnit, "Complete original baseline/candidate unit mismatch")
            try require(exactUnitDigest(baselineUnit) == exactUnitDigest(candidateUnit),
                        "Complete original baseline/candidate exact-byte mismatch")
            let originalDescriptors = try [
                baseline.descriptor(bookId: 5869, containingLineIndex: 95380, mode: .chapter),
                baseline.previousDescriptor(bookId: 5869, beforeLineIndex: baselineUnit.startLineIndex, mode: .chapter),
                baseline.nextDescriptor(bookId: 5869, afterLineIndex: baselineUnit.endLineIndex, mode: .chapter)
            ]
            let candidateDescriptors = try [
                candidate.descriptor(bookId: 5869, containingLineIndex: 95380, mode: .chapter),
                candidate.previousDescriptor(bookId: 5869, beforeLineIndex: candidateUnit.startLineIndex, mode: .chapter),
                candidate.nextDescriptor(bookId: 5869, afterLineIndex: candidateUnit.endLineIndex, mode: .chapter)
            ]
            try require(originalDescriptors == candidateDescriptors, "Original navigation descriptor mismatch")
            let navigationDigest = descriptorDigest(originalDescriptors)
            try require(navigationDigest == descriptorDigest(candidateDescriptors), "Navigation exact-byte mismatch")
            let sourceRows = try database.fetch(query:
                "SELECT id, lineIndex, heRef FROM line WHERE bookId = ? AND lineIndex >= ? AND lineIndex <= ? ORDER BY lineIndex",
                parameters: [5869, 40920, 151115]) { row in (row.int(at: 0), row.int(at: 1), row.string(at: 2)) }
            try require(sourceRows.count == baselineUnit.lineAnchors.count, "Actual full SQLite row count differs")
            for (row, anchor) in zip(sourceRows, baselineUnit.lineAnchors) {
                try require(row.0 == anchor.id && row.1 == anchor.lineIndex && row.2 == anchor.heRef,
                            "Actual SQLite ID/index/reference differs from original anchor")
            }
            roundProofs.append([
                "round": round, "order": order, "complete_semantic_and_exact_byte_equality": true,
                "navigation_sha256": navigationDigest, "independent_sql_identity_rows": sourceRows.count
            ])
        }
        try require(records.count == 4 && roundProofs.count == 2 && allUnitDigests.count == 1,
                    "Eight original reads in both orders must agree")
        let report: [String: Any] = [
            "status": "EXACT_ORIGINAL_FULL_V32_UNIT_PARITY_PASS_PERFORMANCE_OBSERVATION_ONLY",
            "records": records, "round_proofs": roundProofs, "timed_reader_calls": 8,
            "sqlite_runtime_version": String(cString: sqlite3_libversion()),
            "service_cache_cold_only": true, "os_disk_caches_flushed": false,
            "ui_executed": 0, "physical_device_executed": 0, "full_performance_acceptance": false
        ]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output, options: .atomic)
    }
}
