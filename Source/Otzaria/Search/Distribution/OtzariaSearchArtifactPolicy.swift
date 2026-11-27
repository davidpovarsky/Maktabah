import Foundation

enum OtzariaManagedDiscoveryDisposition: Equatable, Sendable {
    case available
    case updateAvailable
    case repairRequired
}

/// Directional READ compatibility is separate from an index writer identity.
/// A source-parity candidate is deliberately insufficient to admit an index.
/// Qualification binds immutable original artifacts to reviewed runtime evidence.
/// Platform acceptance remains a separate gate before releasing the candidate.
enum OtzariaLexicalIndexReadCompatibility {
    enum Contract: String, CaseIterable, Sendable {
        case original265ToExactOccurrencesD5 = "otzaria-265-to-d5-lexical-read-v1"
    }

    // Actual Windows reads/counts/rollback: evidence commit df3b894cef2c8ea3dd50ccb31394635aa8fe4077.
    // docs/hq-integration/index-read-qualification-20261120/QUALIFICATION_REVIEW.json
    // Git LF report SHA256 3ccd704a831f4a96ec06a691bdc17e7a8988168659bad766815018c9106983a1.
    // Original Windows bytes: raw/QUALIFICATION_REVIEW.json.gz; SHA256 56fead3a78281ea6a1ba68d21806d5fa7505f2ba32b709fd03c1ce831c8fa3ca.
    // Apple full-v32 runtime acceptance remains a separate release gate.
    // Never populate this from a manifest, user default, environment variable,
    // schema equality, or git ancestry; only this exact reviewed pair is admitted.
    private static let qualifiedContracts: Set<Contract> = [.original265ToExactOccurrencesD5]

    // Exact required-resource projection reported by both real C binaries.
    // The published artifact additionally records optional lexical.db; claiming
    // that unreported file as a compiled runtime resource is not accepted.
    static let requiredRuntimeResourceHashes = [
        "Vendor/OtzariaSearchEngine/Resources/Acronyms.json":
            "cb101c9feb87394b133098bf569bd9af167babce0f83ab3b151e2599c665389f",
        "Vendor/OtzariaSearchEngine/Resources/dictionary.json":
            "cc3d02655bd3f5a8f7581cf71623cf60b3cd6ee821686cebf149f755272e9a69",
    ]

    static func qualifiedContract(
        manifest: OtzariaSearchArtifactManifest,
        consumer: OtzariaSearchEngineBuildInfo
    ) -> Contract? {
        guard let contract = candidateContract(manifest: manifest, consumer: consumer),
              qualifiedContracts.contains(contract) else { return nil }
        return contract
    }

    /// Eligibility only: this never authorizes production discovery or reads.
    static func candidateContract(
        manifest: OtzariaSearchArtifactManifest,
        consumer: OtzariaSearchEngineBuildInfo
    ) -> Contract? {
        let producer = manifest.lexicalEngine
        let resources = [
            "Application Support/Otzaria/lexical.db":
                "b42e36626802629fed178068e8cf11f0f034d6f24ae3b72ac9999b9311bf299f",
            "Vendor/OtzariaSearchEngine/Resources/Acronyms.json":
                "cb101c9feb87394b133098bf569bd9af167babce0f83ab3b151e2599c665389f",
            "Vendor/OtzariaSearchEngine/Resources/dictionary.json":
                "cc3d02655bd3f5a8f7581cf71623cf60b3cd6ee821686cebf149f755272e9a69",
        ]
        guard producer.repository == "Otzaria/otzaria_search_engine",
              producer.commit == "265a14ea54f959a3e266d6e8acfa3a3b98101d68",
              consumer.upstreamRepository == "davidpovarsky/otzaria_search_engine",
              consumer.upstreamCommit == "d5d59d1269bdf87fb0a6901cf31941726a0c699b",
              consumer.upstreamBranch == "codex/otzaria-exact-occurrences-20261120",
              producer.engineVersion == "0.1.0", consumer.engineVersion == "0.1.0",
              producer.indexSchemaVersion == 4, consumer.indexSchemaVersion == 4,
              producer.defaultGenerationOrder == 5, consumer.defaultGenerationOrder == 5,
              producer.adapterVersion == "0.1.0", consumer.adapterVersion == "0.1.0",
              producer.tantivyVersion == "0.26.1",
              producer.semanticSidecarRevision == "e836ea6cac05e695efdb03ef227e78cd1a624149",
              consumer.semanticSidecarRevision == producer.semanticSidecarRevision,
              manifest.resources.mapValues(\.sha256) == resources,
              consumer.resourceHashes == requiredRuntimeResourceHashes else { return nil }
        return .original265ToExactOccurrencesD5
    }
}

enum OtzariaSearchArtifactPolicy {
    static let safetyReserve: Int64 = 1_073_741_824

    static func validateSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.hasPrefix("\\"),
              !path.contains("\\"),
              !path.contains(":"),
              !path.unicodeScalars.contains(where: { $0.value == 0 }) else { return false }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return !components.isEmpty && components.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    static func managedIdentityMatchesCanonicalData(
        _ identity: OtzariaIndexBuildIdentity,
        currentDatabase: OtzariaIndexFingerprint,
        build: OtzariaSearchEngineBuildInfo,
        trustedManifest: OtzariaSearchArtifactManifest? = nil
    ) -> Bool {
        // Every managed read binds the original producer and catalogue to
        // the fully validated current installation manifest, including exact
        // producer builds. Equal database sizes do not identify a release.
        guard let trustedManifest,
              identity.upstreamCommit == trustedManifest.lexicalEngine.commit,
              identity.catalogueHash == trustedManifest.lexicalArtifact.catalogueHash,
              identity.database.fileSize == currentDatabase.fileSize
            && identity.engineVersion == build.engineVersion
            && identity.indexSchemaVersion == build.indexSchemaVersion
            && identity.defaultGenerationOrder == build.defaultGenerationOrder
            && identity.adapterVersion == build.adapterVersion
            && identity.resourceHashes == build.resourceHashes else { return false }
        if identity.upstreamCommit == build.upstreamCommit { return true }
        // Older identity files have no repository field. A cross-revision read
        // must also bind to the independently validated original manifest;
        // matching a bare commit or schema is not sufficient provenance.
        guard OtzariaLexicalIndexReadCompatibility.qualifiedContract(
                  manifest: trustedManifest, consumer: build
              ) != nil else { return false }
        return identityMatchesArtifactProducer(identity, manifest: trustedManifest)
        // Container path, mtime, and semantic sidecar registration are not
        // part of the canonical lexical artifact identity.
    }

    /// Producer metadata binding only; this is not runtime read authorization.
    /// The identity format has no repository field, so a fully validated trusted
    /// manifest and a qualified directional contract remain separate gates.
    static func identityMatchesArtifactProducer(
        _ identity: OtzariaIndexBuildIdentity,
        manifest: OtzariaSearchArtifactManifest
    ) -> Bool {
        let producer = manifest.lexicalEngine
        let requiredResources = OtzariaLexicalIndexReadCompatibility.requiredRuntimeResourceHashes
        return identity.upstreamCommit == producer.commit
            && identity.engineVersion == producer.engineVersion
            && identity.indexSchemaVersion == producer.indexSchemaVersion
            && identity.defaultGenerationOrder == producer.defaultGenerationOrder
            && identity.adapterVersion == producer.adapterVersion
            && identity.catalogueHash == manifest.lexicalArtifact.catalogueHash
            && identity.resourceHashes == requiredResources
            && requiredResources.allSatisfy { manifest.resources[$0.key]?.sha256 == $0.value }
    }

    /// Installing or repairing metadata records who PRODUCED the index, never
    /// the runtime that happens to consume it. The existing required-resource
    /// projection is retained for exact-build artifacts with extra resources.
    /// Admission and physical engine/count checks remain the caller's gates.
    static func artifactProducerIdentity(
        manifest: OtzariaSearchArtifactManifest,
        database: OtzariaIndexFingerprint,
        requiredResourceNames: Set<String>
    ) throws -> OtzariaIndexBuildIdentity {
        var resources: [String: String] = [:]
        for name in requiredResourceNames {
            guard let resource = manifest.resources[name] else {
                throw OtzariaSearchArtifactError.incompatible("resource \(name)")
            }
            resources[name] = resource.sha256
        }
        let producer = manifest.lexicalEngine
        return OtzariaIndexBuildIdentity(
            database: database,
            upstreamCommit: producer.commit,
            engineVersion: producer.engineVersion,
            indexSchemaVersion: producer.indexSchemaVersion,
            defaultGenerationOrder: producer.defaultGenerationOrder,
            adapterVersion: producer.adapterVersion,
            resourceHashes: resources,
            catalogueHash: manifest.lexicalArtifact.catalogueHash,
            semanticArtifactIdentity: nil
        )
    }

    static func managedDiscoveryDisposition(
        trustedArtifactIdentity: String?,
        availableArtifactIdentity: String
    ) -> OtzariaManagedDiscoveryDisposition {
        guard let trustedArtifactIdentity else { return .available }
        return trustedArtifactIdentity == availableArtifactIdentity
            ? .repairRequired
            : .updateAvailable
    }

    static func requiredInstallCapacity(
        manifest: OtzariaSearchArtifactManifest,
        alreadyDownloadedBytes: Int64,
        existingFinalBytes: Int64
    ) -> Int64 {
        // `availableCapacity` already excludes the existing trusted index. Its
        // atomic rename to `.previous` consumes no additional file data.
        _ = existingFinalBytes
        // The installer streams one independently compressed part at a time,
        // verifies and extracts it, then deletes it before downloading the next.
        let largestPart = manifest.lexicalArtifact.parts.map(\.packagedBytes).max() ?? 0
        let remaining = max(0, largestPart - min(alreadyDownloadedBytes, largestPart))
        return saturatedSum([
            remaining,
            manifest.lexicalArtifact.extractedBytes,
            safetyReserve,
        ])
    }

    static func validate(
        _ manifest: OtzariaSearchArtifactManifest,
        database: OtzariaDatabaseInstallationManifest,
        databaseBytes: Int64,
        build: OtzariaSearchEngineBuildInfo
    ) throws {
        try validate(manifest, database: database, databaseBytes: databaseBytes, build: build,
                     readContract: OtzariaLexicalIndexReadCompatibility.qualifiedContract(
                        manifest: manifest, consumer: build
                     ))
    }

    /// A qualification probe, not an admission token. Uses every original
    /// database/profile/part/layout gate; success still cannot populate the
    /// production qualification registry or authorize discovery/installation.
    static func validateReadCompatibilityCandidate(
        _ manifest: OtzariaSearchArtifactManifest,
        database: OtzariaDatabaseInstallationManifest,
        databaseBytes: Int64,
        build: OtzariaSearchEngineBuildInfo
    ) throws -> OtzariaLexicalIndexReadCompatibility.Contract {
        guard let candidate = OtzariaLexicalIndexReadCompatibility.candidateContract(
            manifest: manifest, consumer: build
        ) else { throw OtzariaSearchArtifactError.incompatible("unqualified read candidate") }
        try validate(manifest, database: database, databaseBytes: databaseBytes, build: build,
                     readContract: candidate)
        return candidate
    }

    private static func validate(
        _ manifest: OtzariaSearchArtifactManifest,
        database: OtzariaDatabaseInstallationManifest,
        databaseBytes: Int64,
        build: OtzariaSearchEngineBuildInfo,
        readContract: OtzariaLexicalIndexReadCompatibility.Contract?
    ) throws {
        guard manifest.formatVersion == OtzariaSearchArtifactManifest.currentFormatVersion else {
            throw OtzariaSearchArtifactError.incompatible("manifest format \(manifest.formatVersion)")
        }
        guard manifest.effectiveProfileID == database.effectiveProfileID,
              manifest.effectiveProfileVersion == database.effectiveProfileVersion,
              OtzariaDataProfileCompatibility.matchesActiveProfile(
                  profileID: manifest.profileID,
                  profileVersion: manifest.profileVersion
              ) else {
            throw OtzariaSearchArtifactError.incompatible("data profile identity")
        }
        let source = manifest.sourceDatabase
        guard source.repository == database.repository,
              source.releaseID == database.releaseID,
              source.releaseTag == database.releaseTag,
              source.assetID == database.assetID,
              source.assetName == database.assetName,
              source.sourceAssetDigest == (database.digest ?? ""),
              source.compressedBytes == database.compressedSize,
              database.databaseFileSize == databaseBytes,
              source.databaseBytes == databaseBytes else {
            throw OtzariaSearchArtifactError.incompatible("source database identity")
        }
        let engine = manifest.lexicalEngine
        let exactProducer = engine.repository == build.upstreamRepository
            && engine.commit == build.upstreamCommit
        guard exactProducer || readContract != nil,
              engine.engineVersion == build.engineVersion,
              engine.indexSchemaVersion == build.indexSchemaVersion,
              engine.defaultGenerationOrder == build.defaultGenerationOrder,
              engine.adapterVersion == build.adapterVersion else {
            throw OtzariaSearchArtifactError.incompatible("lexical engine/schema identity")
        }
        for (name, hash) in build.resourceHashes {
            guard manifest.resources[name]?.sha256 == hash else {
                throw OtzariaSearchArtifactError.incompatible("resource \(name)")
            }
        }
        let artifact = manifest.lexicalArtifact
        guard artifact.documentCount == source.documentCount,
              artifact.sourceCount == source.bookCount,
              artifact.extractedBytes > 0,
              artifact.packagedBytes > 0,
              artifact.fileCount > 0,
              artifact.parts.reduce(Int64(0), { saturatedAdd($0, $1.packagedBytes) }) == artifact.packagedBytes else {
            throw OtzariaSearchArtifactError.malformedManifest("inconsistent lexical totals")
        }
        var expectedOffsets: [String: Int64] = [:]
        for part in artifact.parts {
            guard validateSafeRelativePath(part.destinationPath) else {
                throw OtzariaSearchArtifactError.invalidPartPath(part.destinationPath)
            }
            guard part.compression == "zstd",
                  part.packagedBytes > 0,
                  part.uncompressedBytes > 0,
                  part.sha256.count == 64,
                  part.sha256.allSatisfy({ $0.isHexDigit }),
                  part.destinationOffset == expectedOffsets[part.destinationPath, default: 0] else {
                throw OtzariaSearchArtifactError.malformedManifest("invalid part \(part.assetName)")
            }
            expectedOffsets[part.destinationPath] = saturatedAdd(
                part.destinationOffset,
                part.uncompressedBytes
            )
        }
        guard expectedOffsets.count == artifact.fileCount else {
            throw OtzariaSearchArtifactError.malformedManifest(
                "inconsistent extracted file layout: declaredFiles=\(artifact.fileCount) " +
                "representedPaths=\(expectedOffsets.count)"
            )
        }
        let representedBytes = expectedOffsets.values.reduce(Int64(0), saturatedAdd)
        guard representedBytes == artifact.extractedBytes else {
            throw OtzariaSearchArtifactError.malformedManifest(
                "inconsistent extracted file layout: declaredBytes=\(artifact.extractedBytes) " +
                "representedBytes=\(representedBytes)"
            )
        }
    }

    private static func saturatedSum(_ values: [Int64]) -> Int64 {
        values.reduce(0, saturatedAdd)
    }

    private static func saturatedAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int64.max : value
    }
}
