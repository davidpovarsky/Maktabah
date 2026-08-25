import Foundation

enum OtzariaManagedDiscoveryDisposition: Equatable, Sendable {
    case available
    case updateAvailable
    case repairRequired
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
        build: OtzariaSearchEngineBuildInfo
    ) -> Bool {
        identity.database.fileSize == currentDatabase.fileSize
            && identity.upstreamCommit == build.upstreamCommit
            && identity.engineVersion == build.engineVersion
            && identity.indexSchemaVersion == build.indexSchemaVersion
            && identity.defaultGenerationOrder == build.defaultGenerationOrder
            && identity.adapterVersion == build.adapterVersion
            && identity.resourceHashes == build.resourceHashes
        // Container path, mtime, and semantic sidecar registration are not
        // part of the canonical lexical artifact identity.
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
        guard manifest.formatVersion == OtzariaSearchArtifactManifest.currentFormatVersion else {
            throw OtzariaSearchArtifactError.incompatible("manifest format \(manifest.formatVersion)")
        }
        let source = manifest.sourceDatabase
        guard source.repository == database.repository,
              source.releaseID == database.releaseID,
              source.releaseTag == database.releaseTag,
              source.assetID == database.assetID,
              source.assetName == database.assetName,
              source.sourceAssetDigest == (database.digest ?? ""),
              source.compressedBytes == database.compressedSize,
              source.databaseBytes == databaseBytes else {
            throw OtzariaSearchArtifactError.incompatible("source database identity")
        }
        let engine = manifest.lexicalEngine
        guard engine.repository == build.upstreamRepository,
              engine.commit == build.upstreamCommit,
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
