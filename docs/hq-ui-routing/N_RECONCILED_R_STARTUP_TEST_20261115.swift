import Foundation
import XCTest

/// Executes R's exact committed30 actual attach/switchGroup interaction checks
/// against e8 reconciled bodies, with its explicit native/backend/catalog doubles.
@MainActor final class NReconciledRStartupTests: XCTestCase, @unchecked Sendable {
    func testImmutableReconciledStartupBodiesPreserveLateNativeOpenAndMappingCoherence() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("N-e8-startup-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            BackendCoordinator.shared.beforeNextCommit = nil
            BackendCoordinator.shared.activeBackendID = .otzaria
            BackendCoordinator.shared.generation = 0
            try? FileManager.default.removeItem(at: root)
        }
        try await WorkspaceStartupReconciliationChecks.run(root: root)
    }
}
