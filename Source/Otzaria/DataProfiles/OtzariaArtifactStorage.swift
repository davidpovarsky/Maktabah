import Foundation

struct OtzariaArtifactStorage: Sendable {
    let appSupportRoot: URL
    let cachesRoot: URL
    let profileID: String

    init(profileID: String = OtzariaDataProfileRegistry.activeProfileID) throws {
        guard let appSupportRoot = AppConfig.appSupportDir else {
            throw OtzariaDatabaseAccessController.AccessError.applicationSupportUnavailable
        }
        let cachesRoot = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        self.init(appSupportRoot: appSupportRoot, cachesRoot: cachesRoot, profileID: profileID)
    }

    init(appSupportRoot: URL, cachesRoot: URL, profileID: String) {
        self.appSupportRoot = appSupportRoot
        self.cachesRoot = cachesRoot
        self.profileID = profileID
    }

    var profileRoot: URL {
        appSupportRoot
            .appendingPathComponent("Otzaria", isDirectory: true)
            .appendingPathComponent("Profiles", isDirectory: true)
            .appendingPathComponent(profileID, isDirectory: true)
    }

    var downloadsRoot: URL {
        cachesRoot
            .appendingPathComponent("Maktabah", isDirectory: true)
            .appendingPathComponent("Otzaria", isDirectory: true)
            .appendingPathComponent("Profiles", isDirectory: true)
            .appendingPathComponent(profileID, isDirectory: true)
            .appendingPathComponent("Downloads", isDirectory: true)
    }

    func componentRoot(_ component: OtzariaArtifactComponent) -> URL {
        profileRoot.appendingPathComponent(component.rawValue, isDirectory: true)
    }

    func stateURL(_ component: OtzariaArtifactComponent) -> URL {
        componentRoot(component).appendingPathComponent("installed-artifact.json")
    }
}

struct OtzariaInstallCapacityPlan: Equatable, Sendable {
    let existingInstallBytes: Int64
    let remainingDownloadBytes: Int64
    let extractionStagingBytes: Int64
    let rollbackBytes: Int64
    let promotionOverheadBytes: Int64
    let safetyReserveBytes: Int64

    var peakAdditionalBytes: Int64 {
        Self.saturatingSum([
            remainingDownloadBytes,
            extractionStagingBytes,
            rollbackBytes,
            promotionOverheadBytes,
            safetyReserveBytes,
        ])
    }

    var peakConcurrentBytes: Int64 {
        Self.saturatingSum([existingInstallBytes, peakAdditionalBytes])
    }

    private static func saturatingSum(_ values: [Int64]) -> Int64 {
        values.reduce(0) { partial, value in
            let normalized = max(0, value)
            let (sum, overflow) = partial.addingReportingOverflow(normalized)
            return overflow ? Int64.max : sum
        }
    }
}

enum OtzariaInstallCapacityCalculator {
    static let defaultSafetyReserveBytes: Int64 = 1_073_741_824

    static func plan(
        descriptor: OtzariaArtifactDescriptor,
        existingInstallBytes: Int64,
        currentPartialDownloadBytes: Int64 = 0,
        retainsRollbackCopy: Bool = true,
        safetyReserveBytes: Int64 = defaultSafetyReserveBytes
    ) -> OtzariaInstallCapacityPlan {
        let partial = min(max(0, currentPartialDownloadBytes), descriptor.compressedBytes)
        let rollback = retainsRollbackCopy ? max(0, existingInstallBytes) : 0
        return OtzariaInstallCapacityPlan(
            existingInstallBytes: max(0, existingInstallBytes),
            remainingDownloadBytes: max(0, descriptor.compressedBytes - partial),
            extractionStagingBytes: max(0, descriptor.extractedBytes),
            rollbackBytes: rollback,
            promotionOverheadBytes: 0,
            safetyReserveBytes: max(0, safetyReserveBytes)
        )
    }

    static func plan(
        compressedBytes: Int64,
        extractedBytes: Int64,
        existingInstallBytes: Int64,
        currentPartialDownloadBytes: Int64 = 0,
        retainsRollbackCopy: Bool = true,
        safetyReserveBytes: Int64 = defaultSafetyReserveBytes
    ) -> OtzariaInstallCapacityPlan {
        let descriptor = OtzariaArtifactDescriptor(
            component: .database,
            artifactID: "capacity-only",
            version: "0",
            assetName: "capacity-only",
            downloadURL: URL(string: "https://invalid.example/capacity-only")!,
            compressedBytes: max(1, compressedBytes),
            extractedBytes: max(1, extractedBytes),
            sha256: String(repeating: "0", count: 64),
            schemaVersion: 1,
            artifactVersion: 1,
            builderRevision: "capacity-only"
        )
        return plan(
            descriptor: descriptor,
            existingInstallBytes: existingInstallBytes,
            currentPartialDownloadBytes: currentPartialDownloadBytes,
            retainsRollbackCopy: retainsRollbackCopy,
            safetyReserveBytes: safetyReserveBytes
        )
    }
}
