import Foundation
import COpenSSL

// Actual OpenSSL SHA-256 on Oracle Linux. This is not a crypto double and does
// not qualify Apple's CryptoKit or an original native body/header.
struct BudgetOpenSSLDigest: AnnotationExchangeDigesting {
    func sha256(_ data: Data) throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let success = data.withUnsafeBytes { input in
            bytes.withUnsafeMutableBufferPointer { output in
                SHA256(input.bindMemory(to: UInt8.self).baseAddress, input.count, output.baseAddress) != nil
            }
        }
        guard success else { throw CheckFailure("OpenSSL SHA256 failed") }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
