import Foundation
struct SignatureFixture { let index: URL }
func verifyThreeActualCalls(value: SignatureFixture, parent: URL, permissions: Int) throws {
try FileManager.default.setAttributes([.posixPermissions: permissions],
                ofItemAtPath: value.index.deletingLastPathComponent().path)
try FileManager.default.setAttributes([.posixPermissions: permissions & ~0o222], ofItemAtPath: parent.path)
try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: parent.path)
}
