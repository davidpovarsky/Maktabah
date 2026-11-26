import XCTest
@testable import OtzariaActionCore

private struct OfflinePackageFixture: ActionBackendStatePort, ActionOfflinePackageObservationPort {
    func snapshot() async -> ActionBackendSnapshot { .init(backend: .sefaria, generation: 1) }
    func report(for backend: ActionBackendID) async -> ActionBackendReport { .init(id: backend, operations: [:]) }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async -> ActionCapabilityAssessment {
        .init(registered: true, supported: true, availableNow: true)
    }

    func offlinePackages(forceRefresh: Bool, invocation: ActionPortInvocation) async -> [ActionOfflinePackage] {
        [.init(id: "tanakh", title: forceRefresh ? "Refreshed Tanakh" : "Tanakh", heTitle: "תנ״ך",
               parentID: nil, compressedSize: 150, indexTitles: ["Deuteronomy"], isCompleteLibrary: false)]
    }
    func offlinePackageStatus(includeWorks: Bool, invocation: ActionPortInvocation) async -> ActionOfflinePackageStatus {
        .init(installedPackageIDs: ["tanakh"], installedWorkKeys: includeWorks ? ["Deuteronomy"] : nil)
    }
    func offlinePackageUpdates(invocation: ActionPortInvocation) async -> ActionOfflinePackageUpdates {
        .init(changedWorkCount: 1, affectedPackageIDs: ["tanakh"])
    }
}

final class OfflinePackageObservationTests: XCTestCase, @unchecked Sendable {
    private func run(_ action: String, arguments: ActionObject = [:], scoped: Bool = false) async throws -> ActionResult {
        let original = MockPorts()
        let engine = try ActionExecutor(state: OfflinePackageFixture(), resolver: original, search: original)
        return await engine.execute(.init(action: action, arguments: arguments),
            context: .init(subjectID: "packages", origin: .internalAI, allowedBackends: [.sefaria],
                           contentRights: [.sefaria], scopes: [.contentRead],
                           allowedWorkKeys: scoped ? [.sefaria: ["Deuteronomy"]] : nil))
    }

    func testListStatusAndUpdatesUseOriginalReadOnlyPorts() async throws {
        let list = try await run("packages.list", arguments: ["forceRefresh": .bool(true)])
        XCTAssertEqual(list.status, .completed)
        XCTAssertEqual(try list.data?["packages"]?.decoded(as: [ActionOfflinePackage].self).first?.title, "Refreshed Tanakh")
        let packageOnly = try await run("packages.status")
        XCTAssertNil(packageOnly.data?["installedWorkKeys"])
        let works = try await run("packages.status", arguments: ["includeWorks": .bool(true)])
        XCTAssertEqual(works.data?["installedWorkKeys"], .array([.string("Deuteronomy")]))
        let updates = try await run("packages.checkUpdates")
        XCTAssertEqual(updates.data?["hasUpdates"], .bool(true))
        XCTAssertEqual(updates.data?["changedWorkCount"], .integer(1))
    }

    func testPerWorkGrantCannotReadWholePackageCatalog() async throws {
        let result = try await run("packages.list", scoped: true)
        XCTAssertEqual(result.error?.code, "permission_denied")
    }
}
