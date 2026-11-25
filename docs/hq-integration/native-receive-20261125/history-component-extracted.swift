import Foundation
import CryptoKit
enum AnnotationOriginalEditorReceiptError: Error { case wrongAttempt, unverifiedNativeResult, unsafeStorage, conflictingHistory }
enum AnnotationOriginalEditorNativeReceiptFile {
    private struct Record: Codable {
        struct Mapping: Codable {
            let sourceSpaceID: String
            let sourceObjectID: String
            let objectID: String
        }
        let schema: String
        let status: String
        let remoteDeviceAcknowledgement: Bool
        let namespace: String
        let annotationUUID: UUID
        let preparedSessionID: UUID
        let attemptID: UUID
        let savedRevision: Int64
        let sourceDigest: String
        let payloadDigest: String
        let bodyDigest: String
        let accountID: String
        let spaceID: String
        let objectID: String
        let traceID: String
        let sourceArchiveSHA256: String
        let nativeArchiveSHA256: String
        let nativeResponseSHA256: String
        let nativeResponseBytes: Data
        let objectMappings: [Mapping]
    }

    /// Historical destination data only. Every selected destination is read
    /// afresh through an actual current original account/Space and UUID/type
    /// validation. Decoding this file grants no SDK ownership, write or ACK.
    struct HistoricalMapping: Sendable, Identifiable {
        var id: String { accountID + ":" + spaceID + ":" + objectID }
        let accountID: String
        let spaceID: String
        let objectID: String
        let savedRevision: Int64
        let bodyDigest: String
        let receiptURL: URL
    }

    static func mappings(annotationUUID: UUID, capturedDatabaseURL: URL) throws -> [HistoricalMapping] {
        guard capturedDatabaseURL.isFileURL else { throw AnnotationOriginalEditorReceiptError.unsafeStorage }
        let database = capturedDatabaseURL.standardizedFileURL.resolvingSymlinksInPath()
        let root = database.deletingLastPathComponent()
            .appendingPathComponent(database.lastPathComponent + ".native-import-history", isDirectory: true)
        let manager = FileManager.default
        guard manager.fileExists(atPath: root.path) else { return [] }
        func files(in directory: URL) throws -> [URL] {
            let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                throw AnnotationOriginalEditorReceiptError.unsafeStorage
            }
            let children = try manager.contentsOfDirectory(at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard children.count <= 10_000 else { throw AnnotationOriginalEditorReceiptError.unsafeStorage }
            return children.filter { $0.pathExtension == "json" }
        }
        let note = root.appendingPathComponent(annotationUUID.uuidString, isDirectory: true)
        var candidates = manager.fileExists(atPath: note.path) ? try files(in: note) : []
        // Read the former flat layout without moving/deleting any historical file.
        candidates += try files(in: root)
        var result: [String: HistoricalMapping] = [:]
        for url in candidates {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true,
                  let size = values.fileSize, size > 0, size <= 3 * 1_024 * 1_024 else {
                throw AnnotationOriginalEditorReceiptError.unsafeStorage
            }
            let bytes = try Data(contentsOf: url, options: .mappedIfSafe)
            guard bytes.count == size else { throw AnnotationOriginalEditorReceiptError.unsafeStorage }
            let record = try JSONDecoder().decode(Record.self, from: bytes)
            guard record.schema == "otzaria.original.annotation.native-commit.v1",
                  record.status == "LOCAL_NATIVE_IMPORT_READBACK_VERIFIED",
                  !record.remoteDeviceAcknowledgement else {
                throw AnnotationOriginalEditorReceiptError.unverifiedNativeResult
            }
            guard record.annotationUUID == annotationUUID else { continue }
            guard record.namespace == "otzaria.local.annotation", record.savedRevision >= 0,
                  !record.accountID.isEmpty, !record.spaceID.isEmpty, !record.objectID.isEmpty,
                  !record.nativeResponseBytes.isEmpty,
                  record.nativeResponseBytes.count <= 2 * 1_024 * 1_024,
                  SHA256.hash(data: record.nativeResponseBytes).map({ String(format: "%02x", $0) }).joined()
                    == record.nativeResponseSHA256,
                  record.objectMappings.contains(where: { $0.objectID.utf8.elementsEqual(record.objectID.utf8) }) else {
                throw AnnotationOriginalEditorReceiptError.unverifiedNativeResult
            }
            let value = HistoricalMapping(accountID: record.accountID, spaceID: record.spaceID,
                objectID: record.objectID, savedRevision: record.savedRevision,
                bodyDigest: record.bodyDigest, receiptURL: url)
            if let prior = result[value.id], prior.savedRevision >= value.savedRevision { continue }
            result[value.id] = value
        }
        return result.values.sorted {
            if $0.savedRevision != $1.savedRevision { return $0.savedRevision > $1.savedRevision }
            return $0.id.utf8.lexicographicallyPrecedes($1.id.utf8)
        }
    }

}
