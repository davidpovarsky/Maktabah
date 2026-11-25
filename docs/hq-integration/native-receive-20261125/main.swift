import Foundation
import CryptoKit

enum ControlFailure: Error { case failed(String) }
var passed: [String] = []
let suite = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: suite, withIntermediateDirectories: true)
let note = UUID(uuidString: "F95C189C-66FC-4080-8A58-4F348D055FC0")!
let other = UUID(uuidString: "884BFF83-F3E7-4992-90D4-850206031CDC")!
let raw = Data("synthetic historical response; never a native receipt".utf8)
func sha(_ b: Data) -> String { SHA256.hash(data:b).map{String(format:"%02x",$0)}.joined() }
func check(_ value: @autoclosure () -> Bool, _ label: String) throws {
    guard value() else { throw ControlFailure.failed(label) }
    passed.append(label)
}
func database(_ name: String) throws -> URL {
    let d = suite.appendingPathComponent(name, isDirectory: true)
    try FileManager.default.createDirectory(at:d,withIntermediateDirectories:true)
    return d.appendingPathComponent("profile.sqlite")
}
func root(_ db: URL) -> URL {
    db.deletingLastPathComponent().appendingPathComponent("profile.sqlite.native-import-history", isDirectory:true)
}
func record(uuid: UUID = note, revision: Int64 = 1, object: String = "actual-object-id-is-only-historical-data") -> [String:Any] {
    ["schema":"otzaria.original.annotation.native-commit.v1",
     "status":"LOCAL_NATIVE_IMPORT_READBACK_VERIFIED",
     "remoteDeviceAcknowledgement":false,"namespace":"otzaria.local.annotation",
     "annotationUUID":uuid.uuidString, "preparedSessionID":UUID().uuidString,
     "attemptID":UUID().uuidString, "savedRevision":revision,
     "sourceDigest":String(repeating:"a",count:64),"payloadDigest":String(repeating:"b",count:64),
     "bodyDigest":String(repeating:"c",count:64),"accountID":"historical-account","spaceID":"historical-space",
     "objectID":object,"traceID":"historical-trace","sourceArchiveSHA256":String(repeating:"d",count:64),
     "nativeArchiveSHA256":String(repeating:"e",count:64),"nativeResponseSHA256":sha(raw),
     "nativeResponseBytes":raw.base64EncodedString(),
     "objectMappings":[["sourceSpaceID":"source-space","sourceObjectID":"source-root","objectID":object]]]
}
@discardableResult
func write(_ value:[String:Any], db:URL, flat:Bool=false, name:String=UUID().uuidString) throws -> URL {
    let d = flat ? root(db) : root(db).appendingPathComponent(note.uuidString,isDirectory:true)
    try FileManager.default.createDirectory(at:d,withIntermediateDirectories:true)
    let u=d.appendingPathComponent(name+".json")
    try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]).write(to:u)
    return u
}
func rejected(_ label:String, mutation:([String:Any])->[String:Any]) throws {
    let db=try database(label); try write(mutation(record()),db:db)
    do { _ = try AnnotationOriginalEditorNativeReceiptFile.mappings(annotationUUID:note,capturedDatabaseURL:db) }
    catch { passed.append(label); return }
    throw ControlFailure.failed(label)
}
let absent=try database("absent")
let absentMappings = try AnnotationOriginalEditorNativeReceiptFile.mappings(annotationUUID:note,capturedDatabaseURL:absent)
try check(absentMappings.isEmpty && !FileManager.default.fileExists(atPath:root(absent).path),"missing-history-is-read-only")
let current=try database("current"); let currentURL=try write(record(),db:current)
let currentMappings=try AnnotationOriginalEditorNativeReceiptFile.mappings(annotationUUID:note,capturedDatabaseURL:current)
try check(currentMappings.count==1 && currentMappings[0].receiptURL==currentURL,"per-note-history")
let flat=try database("legacy");let legacyURL=try write(record(),db:flat,flat:true)
let legacyMappings=try AnnotationOriginalEditorNativeReceiptFile.mappings(annotationUUID:note,capturedDatabaseURL:flat)
try check(legacyMappings.count==1 && legacyMappings[0].receiptURL==legacyURL,"legacy-flat-history-retained")
try write(record(revision:4),db:flat)
let latest=try AnnotationOriginalEditorNativeReceiptFile.mappings(annotationUUID:note,capturedDatabaseURL:flat)
try check(latest.count==1 && latest[0].savedRevision==4 && FileManager.default.fileExists(atPath:legacyURL.path),"same-destination-latest-no-rewrite")
let independent=try database("independent");try write(record(),db:independent);try write(record(object:"second-target"),db:independent)
try check(try! AnnotationOriginalEditorNativeReceiptFile.mappings(annotationUUID:note,capturedDatabaseURL:independent).count==2,"distinct-native-targets-retained")
let unrelated=try database("other-note");try write(record(uuid:other),db:unrelated,flat:true)
try check(try! AnnotationOriginalEditorNativeReceiptFile.mappings(annotationUUID:note,capturedDatabaseURL:unrelated).isEmpty,"other-uuid-not-admitted")
for (key,value,label) in [
 ("schema","unrecognized","wrong-schema"),
 ("status","nativeAwaitReturned","await-return-is-not-receipt"),
 ("namespace","different-namespace","wrong-namespace"),
 ("nativeResponseSHA256",String(repeating:"0",count:64),"response-checksum-mismatch")
] {
    try rejected(label) { source in var copy=source;copy[key]=value;return copy }
}
try rejected("remote-ack-cannot-be-fabricated") { source in var copy=source;copy["remoteDeviceAcknowledgement"]=true;return copy }
try rejected("negative-saved-revision") { source in var copy=source;copy["savedRevision"] = -1;return copy }
try rejected("root-missing-from-native-mapping") { source in var copy=source;copy["objectMappings"]=[];return copy }
try rejected("empty-native-response") { source in var copy=source;copy["nativeResponseBytes"]="";copy["nativeResponseSHA256"]=sha(Data());return copy }
let linkDB=try database("symlink-file");let valid=try write(record(),db:linkDB)
let link=valid.deletingLastPathComponent().appendingPathComponent("linked.json")
try FileManager.default.createSymbolicLink(at:link,withDestinationURL:valid)
do { _=try AnnotationOriginalEditorNativeReceiptFile.mappings(annotationUUID:note,capturedDatabaseURL:linkDB);throw ControlFailure.failed("symlink-file-refused") }
catch is AnnotationOriginalEditorReceiptError { passed.append("symlink-file-refused") }
let dirDB=try database("symlink-directory")
try FileManager.default.createSymbolicLink(at:root(dirDB),withDestinationURL:root(current))
do { _=try AnnotationOriginalEditorNativeReceiptFile.mappings(annotationUUID:note,capturedDatabaseURL:dirDB);throw ControlFailure.failed("symlink-directory-refused") }
catch is AnnotationOriginalEditorReceiptError { passed.append("symlink-directory-refused") }
do { _=try AnnotationOriginalEditorNativeReceiptFile.mappings(annotationUUID:note,capturedDatabaseURL:URL(string:"https://invalid.example/profile")!);throw ControlFailure.failed("non-file-database-refused") }
catch is AnnotationOriginalEditorReceiptError { passed.append("non-file-database-refused") }
let emptyDB=try database("empty-file");let emptyURL=try write(record(),db:emptyDB);try Data().write(to:emptyURL)
do { _=try AnnotationOriginalEditorNativeReceiptFile.mappings(annotationUUID:note,capturedDatabaseURL:emptyDB);throw ControlFailure.failed("empty-history-refused") }
catch is AnnotationOriginalEditorReceiptError { passed.append("empty-history-refused") }
let directoryDB=try database("unrelated-directories");try write(record(),db:directoryDB)
for i in 0..<5_000 {
 let d=root(directoryDB).appendingPathComponent("unrelated-\(i)",isDirectory:true)
 try FileManager.default.createDirectory(at:d,withIntermediateDirectories:false)
 // A corrupt archive in an unrelated note must never be decoded by this lookup.
 try Data("irrelevant corrupt archive".utf8).write(to:d.appendingPathComponent("archive.json"))
}
let start=ContinuousClock.now
let selected=try AnnotationOriginalEditorNativeReceiptFile.mappings(annotationUUID:note,capturedDatabaseURL:directoryDB)
let elapsed=start.duration(to:.now)
try check(selected.count==1,"unrelated-note-archives-not-read")
let result:[String:Any]=["status":"PASSED_ACTUAL_SWIFT_HISTORY_COMPONENT_CONTROLS","passed":passed.count,
 "controls":passed,"unrelated_directory_count":5_000,"single_note_lookup_duration":"\(elapsed)",
 "scope":"exact production history decoder and file checks; synthetic historical files only; no native SDK/engine/UI acceptance claim"]
let bytes=try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys])
print(String(decoding:bytes,as:UTF8.self))
