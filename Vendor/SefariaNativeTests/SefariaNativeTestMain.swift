import Foundation

@main
enum SefariaNativeTestMain {
    static func main() async {
        do {
            try runLocatorAndRefTests()
            try await runDecodingTests()
            try await runNavigationAndPackageTests()
            #if !PORTABLE_CONTRACT_TESTS
            try runLegacyIdentityRegistryTests()
            try await runBackendCoordinatorTests()
            try runUnifiedSearchArchitectureTests()
            #endif
            print("Sefaria native contract tests passed")
        } catch {
            fatalError("Sefaria native contract tests failed: \(error)")
        }
    }
}
