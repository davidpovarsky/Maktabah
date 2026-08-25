import Foundation

enum ZayitInstallCapacityPolicy {
    static let reserveBytes: Int64 = 1_073_741_824

    static func requiredBytes(
        extractedBytes: Int64,
        packagedPartBytes: [Int64],
        currentPartialBytes: Int64 = 0
    ) -> Int64 {
        let largestPart = packagedPartBytes.max() ?? 0
        let remainingPart = max(0, largestPart - min(max(0, currentPartialBytes), largestPart))
        // The existing final installation is already reflected in available
        // capacity and promotion is a same-volume rename, not another copy.
        return extractedBytes + remainingPart + reserveBytes
    }
}
