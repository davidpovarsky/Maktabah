import Foundation
struct SignatureFixture { let index: URL }
func verifyThreeActualCalls(value: SignatureFixture, parent: URL, permissions: Int) throws {
try FileManager.default.setAttributes([.posixPermissions: permissions],
                atPath: value.index.deletingLastPathComponent().path)
try FileManager.default.setAttributes([.posixPermissions: permissions & ~0o222], atPath: parent.path)
try FileManager.default.setAttributes([.posixPermissions: permissions], atPath: parent.path)
}
