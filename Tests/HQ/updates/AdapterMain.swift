import Foundation

@main struct AdapterFixture {
    @MainActor static func main() async throws {
        var checks = 0
        let manager = BookUpdateManager()
        // If a guard regresses, a connection error is a test failure, never a PASS.
        let unreachable = URL(string: "http://127.0.0.1:1/unsupported-updater-must-not-request")!
        for active in BackendID.allCases {
            BackendCoordinator.shared.activeBackendID = active
            for transitioning in [false, true] {
                BackendCoordinator.shared.isTransitioning = transitioning
                for saved in [nil, "otzaria", "sefaria", "sefariaEmbedded", "maktabah", "unknown"] as [String?] {
                    fixturePersistedBackend = saved
                    precondition(!MaktabahBookUpdateSafety.isMaktabahActive)
                    do {
                        _ = try await MaktabahBookUpdateSafety.preflight()
                        fatalError("Unsupported backend must fail before paths, network or SQL")
                    } catch MaktabahBookUpdateSafety.Failure.unsupportedBackend { }
                    do {
                        _ = try await manager.fetchCSVString(from: unreachable)
                        fatalError("Unsupported backend reached catalog HTTP")
                    } catch MaktabahBookUpdateSafety.Failure.unsupportedBackend { }
                    do {
                        _ = try await manager.downloadFile(from: unreachable, to: URL(fileURLWithPath: "/absent"))
                        fatalError("Unsupported backend reached download HTTP")
                    } catch MaktabahBookUpdateSafety.Failure.unsupportedBackend { }
                    do {
                        _ = try manager.makeWorkingDirectory()
                        fatalError("Unsupported backend reached staging")
                    } catch MaktabahBookUpdateSafety.Failure.unsupportedBackend { }
                    manager.cleanupWorkingDirectory()
                    do {
                        try MaktabahBookUpdateSafety.requireCurrent()
                        fatalError("Saved strings must never authorize a foreign catalog")
                    } catch MaktabahBookUpdateSafety.Failure.unsupportedBackend { }
                    precondition(fixturePathReads == 0)
                    checks += 1
                }
            }
            print("PASS \(active.rawValue): all saved identities and transition states rejected before path lookup")
        }
        fixturePersistedBackend = "maktabah"
        let context = MaktabahBookUpdateSafety.Context(generation: 0, main: "/absent", special: "/absent", archives: "/absent")
        try MaktabahBookUpdateSafety.$operationContext.withValue(context) {
            do {
                try MaktabahBookUpdateSafety.requireCurrent(context)
                fatalError("A supplied context must not grant backend authority")
            } catch MaktabahBookUpdateSafety.Failure.unsupportedBackend { }
        }
        checks += 1
        precondition(fixturePathReads == 0)
        print("EXECUTED_PASS \(checks) production-adapter boundary combinations (compiler doubles; no Apple UI validation)")
    }
}
