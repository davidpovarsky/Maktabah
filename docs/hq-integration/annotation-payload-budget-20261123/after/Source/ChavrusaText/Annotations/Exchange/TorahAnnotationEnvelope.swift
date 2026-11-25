import Foundation
import OtzariaActionCore
#if canImport(CryptoKit)
import CryptoKit
#endif

/// This component has no transport or automatic application/Save hook.
enum AnnotationExchangeCapability {
    static let liveExchangeEnabled = false
}

enum AnnotationExchangeError: Error, Sendable, Equatable {
    case invalidEnvelope, invalidScope, unsupportedVersion(Int64), payloadTooLarge
    case missingSource, ambiguousSource, staleSource, staleRevision, revisionExhausted
    case idempotencyConflict, receiptMismatch, schemaMismatch, corruptRecord
}

/// Host-injected digest, never an authority supplied by an envelope.
protocol AnnotationExchangeDigesting: Sendable {
    func sha256(_ data: Data) throws -> String
}

#if canImport(CryptoKit)
struct AnnotationExchangePlatformDigest: AnnotationExchangeDigesting {
    func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
#endif

struct AnnotationExchangeDestination: Sendable, Hashable {
    let destination: String
    let account: String
    let space: String

    init(destination: String, account: String, space: String) throws {
        guard [destination, account, space].allSatisfy({ AnnotationExchangeValidation.identifier($0) }) else {
            throw AnnotationExchangeError.invalidScope
        }
        self.destination = destination; self.account = account; self.space = space
    }

    var canonicalValue: ActionJSON {
        .object(["destination": .string(destination), "account": .string(account), "space": .string(space)])
    }
}

enum AnnotationExchangeValidation {
    static func identifier(_ text: String) -> Bool {
        !text.isEmpty && text.utf8.count <= 512 && text.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || [45, 46, 58, 95].contains($0)
        }
    }
    static func digest(_ text: String) -> Bool {
        text.utf8.count == 64 && text.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
    static func canonical(_ value: ActionJSON) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
    static func destinationList(_ destinations: [AnnotationExchangeDestination]) throws -> String {
        guard !destinations.isEmpty, destinations.count <= 16, Set(destinations).count == destinations.count else {
            throw AnnotationExchangeError.invalidScope
        }
        // Sorting each encoded value avoids delimiter/concatenation ambiguity.
        let encoded = try destinations.map { try canonical($0.canonicalValue) }.sorted { $0.lexicographicallyPrecedes($1) }
        return "[" + encoded.map { String(decoding: $0, as: UTF8.self) }.joined(separator: ",") + "]"
    }
}

/// A local optimistic witness. It is deliberately not Decodable/Codable.
struct AnnotationExchangeSourceWitness: Sendable, Equatable {
    let annotationUUID: UUID
    let exists: Bool
    let canonicalBytes: Data
    let digest: String
    let metadata: ActionObject
}

struct TorahAnnotationEnvelope: Sendable, Equatable {
    enum DeletionState: String, Sendable { case active, tombstone }
    struct RichBody: Sendable, Equatable {
        let format: String
        let formatVersion: Int64
        let bytes: Data
    }
    let namespace: String
    let annotationUUID: UUID
    let originatingApp: String
    let source: ActionObject
    let richBody: RichBody?
    let textPreview: String
    let editorRevision: String?
    let title: String?
    let deletionState: DeletionState
}

/// A decoded envelope retains the exact original bytes, including unknown keys.
/// Decoding a supported version does not authorize applying or executing it.
enum TorahAnnotationEnvelopeDocument: Sendable, Equatable {
    case supported(TorahAnnotationEnvelope, originalBytes: Data)
    case unsupported(version: Int64, originalBytes: Data)

    var originalBytes: Data {
        switch self { case .supported(_, let bytes), .unsupported(_, let bytes): bytes }
    }
}

/// Annotation-specific transport budgets. The original SDK still validates the
/// native frame/header/archive; these ceilings never construct or attest one.
enum TorahAnnotationPayloadLimits {
    static let maximumArchiveBytes = 1_048_576
    static let maximumHeaderBytes = 16_384
    static let fixedFramingBytes = 16
    static let maximumBodyBytes = fixedFramingBytes + maximumHeaderBytes + maximumArchiveBytes
    static let maximumBase64Bytes = 4 * ((maximumBodyBytes + 2) / 3)
    static let maximumEnvelopeBytes = AnnotationEnvelopeJSONCodec.maximumBytes
    static let maximumStoredEnvelopeBase64Bytes = 4 * ((maximumEnvelopeBytes + 2) / 3)
}

enum TorahAnnotationEnvelopeCodec {
    static let schemaVersion: Int64 = 1
    // The typed entry keeps the original strict grammar and its depth/node
    // limits while charging the whole annotation, including unknown/private
    // metadata, to its own bounded envelope budget.
    static let maximumBytes = TorahAnnotationPayloadLimits.maximumEnvelopeBytes

    static func encode(_ envelope: TorahAnnotationEnvelope) throws -> Data {
        var body: ActionJSON = .null
        if let rich = envelope.richBody {
            guard rich.bytes.count <= TorahAnnotationPayloadLimits.maximumBodyBytes else {
                throw AnnotationExchangeError.payloadTooLarge
            }
            body = .object(["format": .string(rich.format), "formatVersion": .integer(rich.formatVersion),
                            "bytesBase64": .string(rich.bytes.base64EncodedString())])
        }
        var fields: ActionObject = ["schemaVersion": .integer(schemaVersion), "namespace": .string(envelope.namespace),
            "annotationUUID": .string(envelope.annotationUUID.uuidString), "originatingApp": .string(envelope.originatingApp),
            "source": .object(envelope.source), "richBody": body, "textPreview": .string(envelope.textPreview),
            "deletionState": .string(envelope.deletionState.rawValue)]
        if let title = envelope.title { fields["title"] = .string(title) }
        if let revision = envelope.editorRevision { fields["editorRevision"] = .string(revision) }
        let bytes = try AnnotationExchangeValidation.canonical(.object(fields))
        _ = try decode(bytes)
        return bytes
    }

    static func decode(_ bytes: Data) throws -> TorahAnnotationEnvelopeDocument {
        guard bytes.count <= maximumBytes else { throw AnnotationExchangeError.payloadTooLarge }
        let fields: ActionObject
        do { fields = try AnnotationEnvelopeJSONCodec.decodeObject(bytes) }
        catch { throw AnnotationExchangeError.invalidEnvelope }
        guard let version = fields["schemaVersion"]?.integer, version > 0 else { throw AnnotationExchangeError.invalidEnvelope }
        guard version == schemaVersion else { return .unsupported(version: version, originalBytes: bytes) }
        guard let namespace = fields["namespace"]?.string, AnnotationExchangeValidation.identifier(namespace),
              let identity = fields["annotationUUID"]?.string, let uuid = UUID(uuidString: identity),
              let origin = fields["originatingApp"]?.string, AnnotationExchangeValidation.identifier(origin),
              let source = fields["source"]?.object,
              let sourceDigest = source["snapshotSHA256"]?.string, AnnotationExchangeValidation.digest(sourceDigest),
              let sourceState = source["state"]?.string, ["present", "absent"].contains(sourceState),
              let preview = fields["textPreview"]?.string, preview.utf8.count <= 8_192,
              let state = fields["deletionState"]?.string.flatMap(TorahAnnotationEnvelope.DeletionState.init(rawValue:)) else {
            throw AnnotationExchangeError.invalidEnvelope
        }
        func optionalString(_ name: String, maximum: Int) throws -> String? {
            guard let value = fields[name] else { return nil }
            guard let text = value.string, text.utf8.count <= maximum else { throw AnnotationExchangeError.invalidEnvelope }
            return text
        }
        let title = try optionalString("title", maximum: 1_024)
        let editorRevision = try optionalString("editorRevision", maximum: 512)
        let body: TorahAnnotationEnvelope.RichBody?
        if fields["richBody"] == .null { body = nil }
        else {
            guard let rich = fields["richBody"]?.object,
                  let format = rich["format"]?.string, AnnotationExchangeValidation.identifier(format),
                  let formatVersion = rich["formatVersion"]?.integer, formatVersion > 0,
                  let encoded = rich["bytesBase64"]?.string else { throw AnnotationExchangeError.invalidEnvelope }
            // Bound the encoded allocation before Foundation decodes it, then
            // check the actual bytes and canonical base64 representation.
            guard encoded.utf8.count <= TorahAnnotationPayloadLimits.maximumBase64Bytes else {
                throw AnnotationExchangeError.payloadTooLarge
            }
            guard let data = Data(base64Encoded: encoded),
                  data.base64EncodedString() == encoded else { throw AnnotationExchangeError.invalidEnvelope }
            guard data.count <= TorahAnnotationPayloadLimits.maximumBodyBytes else {
                throw AnnotationExchangeError.payloadTooLarge
            }
            body = .init(format: format, formatVersion: formatVersion, bytes: data)
        }
        guard (state == .active && sourceState == "present") ||
              (state == .tombstone && sourceState == "absent" && body == nil && preview.isEmpty) else {
            throw AnnotationExchangeError.invalidEnvelope
        }
        return .supported(.init(namespace: namespace, annotationUUID: uuid, originatingApp: origin,
            source: source, richBody: body, textPreview: preview, editorRevision: editorRevision,
            title: title, deletionState: state), originalBytes: bytes)
    }
}
