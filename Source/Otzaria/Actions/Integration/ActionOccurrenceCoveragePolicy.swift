import Foundation
import OtzariaActionCore
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif

/// Authentication of complete published manifests is independent of runtime
/// read qualification. The original policy must admit the exact producer and
/// consumer pair as well; a pin alone never enables occurrence counting.
enum ActionOccurrenceCoveragePolicy {
    struct Coverage: Equatable, Sendable {
        let artifactIdentity: String
        let typedManifestSHA256: String
        let databaseSHA256: String
        let expectedDocuments: UInt64
        let profileID: String
    }

    // Derived with the complete original Codable models and Swift JSONEncoder,
    // sortedKeys + withoutEscapingSlashes. Installed manifests are re-encoded by
    // the original installer, so raw release-file digests are a different value.
    private static let authenticatedManifests: [String: String] = [
        "08a5ddf76ae187e3ca29c1b483637f1dc8e2a2dcb7001cdb7fe3327236234e83":
            "63fdf6750863292061ec1a4f73072355cf8f92c2a64ec7029b1ca895bb3135de",
        "102293b3a63c7f73fa05298457073804e57e020486753f8f6b8f7964ce29f17e":
            "c8c2a35a86bae5bf9012c71ac027078a25a5ff8ef584547965ad6ef41cd4db9f",
    ]

    static func authenticatedManifest(_ manifest: OtzariaSearchArtifactManifest) throws -> String {
        let actual = try digest(manifest)
        guard authenticatedManifests[manifest.artifactIdentity] == actual else {
            throw ActionOccurrenceFailure.incompleteCoverage
        }
        return actual
    }

    static func validate(
        manifest: OtzariaSearchArtifactManifest,
        database: OtzariaDatabaseInstallationManifest,
        current: OtzariaIndexFingerprint,
        identity: OtzariaIndexBuildIdentity,
        build: OtzariaSearchEngineBuildInfo,
        profileID: String
    ) throws -> Coverage {
        let manifestSHA = try authenticatedManifest(manifest)
        guard build.upstreamCommit == ActionOccurrenceEvidence.requiredEngineRevision,
              OtzariaLexicalIndexReadCompatibility.qualifiedContract(manifest: manifest, consumer: build) != nil,
              manifest.effectiveProfileID == profileID,
              database.effectiveProfileID == profileID,
              database.databaseFileSize == manifest.sourceDatabase.databaseBytes,
              identity.database == current,
              current.fileSize > 0, current.modificationTime.isFinite,
              manifest.lexicalArtifact.documentCount > 0,
              manifest.lexicalArtifact.documentCount == manifest.sourceDatabase.documentCount,
              let bytes = Int64(exactly: current.fileSize),
              bytes == manifest.sourceDatabase.databaseBytes else {
            throw ActionOccurrenceFailure.incompleteCoverage
        }
        try OtzariaSearchArtifactPolicy.validate(manifest, database: database,
            databaseBytes: bytes, build: build)
        guard OtzariaSearchArtifactPolicy.identityMatchesArtifactProducer(identity, manifest: manifest),
              OtzariaSearchArtifactPolicy.managedIdentityMatchesCanonicalData(identity,
                currentDatabase: current, build: build, trustedManifest: manifest) else {
            throw ActionOccurrenceFailure.incompleteCoverage
        }
        return Coverage(artifactIdentity: manifest.artifactIdentity,
            typedManifestSHA256: manifestSHA,
            databaseSHA256: manifest.sourceDatabase.databaseSHA256,
            expectedDocuments: manifest.lexicalArtifact.documentCount,
            profileID: profileID)
    }

    static func bookIDs(for query: ActionOccurrenceQuery) throws -> [UInt64] {
        guard query.unsupportedReason == nil, query.scopeWorkRefs.count <= 200,
              !query.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              query.text.unicodeScalars.count <= 1_000 else {
            throw ActionOccurrenceFailure.unsupportedQuery
        }
        var ids: [UInt64] = []
        for ref in query.scopeWorkRefs {
            guard ref.backend == .otzaria, ref.workKey.hasPrefix("book:"),
                  let id = UInt64(ref.workKey.dropFirst(5)), id > 0,
                  ref.workKey.utf8.elementsEqual("book:\(id)".utf8),
                  !ids.contains(id) else { throw ActionOccurrenceFailure.unsupportedQuery }
            ids.append(id)
        }
        return ids
    }

    static func digest<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return sha256(try encoder.encode(value))
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
