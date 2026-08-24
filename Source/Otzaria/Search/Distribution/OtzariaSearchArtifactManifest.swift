import Foundation

struct OtzariaSearchArtifactManifest: Codable, Equatable, Sendable {
    static let currentFormatVersion = 1

    let formatVersion: Int
    let artifactIdentity: String
    let sourceDatabase: SourceDatabase
    let lexicalEngine: LexicalEngine
    let resources: [String: Resource]
    let lexicalArtifact: LexicalArtifact
    let semantic: SemanticArtifact?

    struct SourceDatabase: Codable, Equatable, Sendable {
        let repository: String
        let releaseTag: String
        let releaseID: Int64
        let assetID: Int64
        let assetName: String
        let sourceAssetDigest: String
        let compressedBytes: Int64
        let databaseBytes: Int64
        let databaseSHA256: String
        let bookCount: Int
        let documentCount: UInt64
    }

    struct LexicalEngine: Codable, Equatable, Sendable {
        let repository: String
        let commit: String
        let engineVersion: String
        let indexSchemaVersion: UInt32
        let defaultGenerationOrder: UInt32
        let tantivyVersion: String
        let adapterVersion: String
        let semanticSidecarRevision: String
    }

    struct Resource: Codable, Equatable, Sendable {
        let version: String?
        let bytes: Int64
        let sha256: String
    }

    struct LexicalArtifact: Codable, Equatable, Sendable {
        let documentCount: UInt64
        let sourceCount: Int
        let catalogueHash: String
        let extractedBytes: Int64
        let packagedBytes: Int64
        let fileCount: Int
        let segmentsBeforeOptimize: Int
        let segmentsAfterOptimize: Int
        let parts: [Part]
    }

    struct Part: Codable, Equatable, Sendable {
        let assetName: String
        let packagedBytes: Int64
        let sha256: String
        let destinationPath: String
        let destinationOffset: Int64
        let uncompressedBytes: Int64
        let compression: String
    }

    struct SemanticArtifact: Codable, Equatable, Sendable {
        let sidecarRevision: String
        let modelRepository: String
        let modelFilename: String
        let modelSHA256: String
        let modelBytes: Int64
        let embeddingDimension: UInt32
        let recipeIdentity: String
        let storeFormatVersion: String
        let vectorCount: UInt64
        let requiredLexicalArtifactIdentity: String
        let parts: [Part]
    }
}

struct OtzariaResolvedSearchArtifact: Equatable, Sendable {
    let releaseID: Int64
    let releaseTag: String
    let manifest: OtzariaSearchArtifactManifest
    let partURLs: [String: URL]
}

enum OtzariaSearchArtifactError: LocalizedError, Equatable, Sendable {
    case unavailable
    case malformedManifest(String)
    case incompatible(String)
    case missingPart(String)
    case invalidPartPath(String)
    case insufficientStorage(required: Int64, available: Int64)
    case downloadFailed(String)
    case sizeMismatch(asset: String, expected: Int64, actual: Int64)
    case digestMismatch(asset: String)
    case extractionFailed(String)
    case validationFailed(String)
    case activationFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "A compatible Otzaria search package is not available yet."
        case .malformedManifest(let detail):
            return "The Otzaria search package manifest is invalid: \(detail)"
        case .incompatible(let detail):
            return "The Otzaria search package is not compatible with this library: \(detail)"
        case .missingPart(let name):
            return "The Otzaria search package is missing \(name)."
        case .invalidPartPath(let path):
            return "The Otzaria search package contains an unsafe path: \(path)"
        case .insufficientStorage(let required, let available):
            return "Search index installation requires \(Self.format(required)); \(Self.format(available)) is available."
        case .downloadFailed(let detail):
            return "The Otzaria search package download failed: \(detail)"
        case .sizeMismatch(let asset, _, _):
            return "The downloaded search package part has the wrong size: \(asset)."
        case .digestMismatch(let asset):
            return "The downloaded search package part failed SHA-256 verification: \(asset)."
        case .extractionFailed(let detail):
            return "The Otzaria search package could not be extracted: \(detail)"
        case .validationFailed(let detail):
            return "The staged Otzaria search index is invalid: \(detail)"
        case .activationFailed(let detail):
            return "The Otzaria search index could not be activated safely: \(detail)"
        case .cancelled:
            return "The Otzaria search package download was cancelled. It can be resumed later."
        }
    }

    private static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
