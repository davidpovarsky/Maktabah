import Foundation

@main struct AdapterFixture {
    @MainActor static func main() async throws {
        precondition(!MaktabahBookUpdateSafety.isMaktabahActive)
        do {
            _ = try await MaktabahBookUpdateSafety.preflight()
            fatalError("Otzaria must never authorize Maktabah updates")
        } catch MaktabahBookUpdateSafety.Failure.unsupportedBackend { }
        print("PASS actual async preflight rejects downstream backend with compiler doubles")
        do {
            try MaktabahBookUpdateSafety.requireCurrent()
            fatalError("Unset backend must fail closed")
        } catch MaktabahBookUpdateSafety.Failure.unsupportedBackend { }
        print("PASS actual synchronous SQL-open gate rejects missing explicit backend")
        print("EXECUTED_PASS 2 production-adapter boundary checks (doubles; no Apple UI validation)")
    }
}
