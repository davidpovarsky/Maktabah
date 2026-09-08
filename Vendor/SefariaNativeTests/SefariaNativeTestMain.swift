import Foundation

@main
enum SefariaNativeTestMain {
    static func main() async {
        do {
            try runLocatorAndRefTests()
            try runDecodingTests()
            try runNavigationAndPackageTests()
            try runLegacyIdentityRegistryTests()
            try await runBackendCoordinatorTests()
            print("Sefaria native contract tests passed")
        } catch {
            fatalError("Sefaria native contract tests failed: \(error)")
        }
    }
}
