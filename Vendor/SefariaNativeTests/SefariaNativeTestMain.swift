import Foundation

@main
enum SefariaNativeTestMain {
    static func main() async {
        do {
            FileHandle.standardError.write(Data("STAGE BEGIN LocatorAndRefTests\n".utf8))
            try runLocatorAndRefTests()
            FileHandle.standardError.write(Data("STAGE PASS LocatorAndRefTests\n".utf8))
            FileHandle.standardError.write(Data("STAGE BEGIN DecodingTests\n".utf8))
            try await runDecodingTests()
            FileHandle.standardError.write(Data("STAGE PASS DecodingTests\n".utf8))
            FileHandle.standardError.write(Data("STAGE BEGIN NavigationAndPackageTests\n".utf8))
            try await runNavigationAndPackageTests()
            FileHandle.standardError.write(Data("STAGE PASS NavigationAndPackageTests\n".utf8))
            #if !PORTABLE_CONTRACT_TESTS
            FileHandle.standardError.write(Data("STAGE BEGIN LegacyIdentityRegistryTests\n".utf8))
            try runLegacyIdentityRegistryTests()
            FileHandle.standardError.write(Data("STAGE PASS LegacyIdentityRegistryTests\n".utf8))
            FileHandle.standardError.write(Data("STAGE BEGIN BackendCoordinatorTests\n".utf8))
            try await runBackendCoordinatorTests()
            FileHandle.standardError.write(Data("STAGE PASS BackendCoordinatorTests\n".utf8))
            FileHandle.standardError.write(Data("STAGE BEGIN UnifiedSearchArchitectureTests\n".utf8))
            try runUnifiedSearchArchitectureTests()
            FileHandle.standardError.write(Data("STAGE PASS UnifiedSearchArchitectureTests\n".utf8))
            #endif
            #if !PORTABLE_CONTRACT_TESTS && !OTZARIA_INSPECTOR_MAPPING_TESTS
            FileHandle.standardError.write(Data("STAGE BEGIN OtzariaPerformanceUnitTests\n".utf8))
            try await runOtzariaPerformanceUnitTests()
            FileHandle.standardError.write(Data("STAGE PASS OtzariaPerformanceUnitTests\n".utf8))
            #endif
            print("Sefaria native contract tests passed")
        } catch {
            fatalError("Sefaria native contract tests failed: \(error)")
        }
    }
}
