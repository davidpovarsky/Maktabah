import Foundation

enum ZayitInstallCapacityPolicy {
    static let reserveBytes = OtzariaInstallCapacityCalculator.defaultSafetyReserveBytes

    static func requiredBytes(
        extractedBytes: Int64,
        packagedPartBytes: [Int64],
        currentPartialBytes: Int64 = 0
    ) -> Int64 {
        let largestPart = packagedPartBytes.max() ?? 0
        return OtzariaInstallCapacityCalculator.plan(
            compressedBytes: max(1, largestPart),
            extractedBytes: max(1, extractedBytes),
            existingInstallBytes: 0,
            currentPartialDownloadBytes: currentPartialBytes,
            retainsRollbackCopy: false,
            safetyReserveBytes: reserveBytes
        ).peakAdditionalBytes
    }
}
