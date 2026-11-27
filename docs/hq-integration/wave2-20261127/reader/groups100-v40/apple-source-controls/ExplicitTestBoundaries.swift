import XCTest
import UIKit

// These are explicit compile-only declarations for unrelated Faithful/R27
// base methods. No XCTest, UI action or native acceptance is executed here.
class FaithfulReaderUIBase: MaktabahUITestBase {
    let workspaceNamespace = UUID().uuidString
    var readerTestTier: TestTier { .smoke }
    var readerAdditionalLaunchArguments: [String] { [] }
    func launchReader(enabled: Bool = true, scenario: String = "reader", backend: String = "otzaria", language: String = "he", background: Int = 0, recordViewport: Bool = false, fontSize: Float? = nil, tier: TestTier) { fatalError("Compile only") }
    func workspaceContainerParent() throws -> URL { fatalError("Compile only") }
    func workspaceSidecarURL() throws -> URL { fatalError("Compile only") }
    func attachWorkspaceSnapshot(_ name: String) throws { fatalError("Compile only") }
    func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) { fatalError("Compile only") }
    func readerLibraryPaletteLauncher() -> XCUIElement { fatalError("Compile only") }
    func retainNativeEvidence(_ name: String) { fatalError("Compile only") }
    func assertReaderHasText(expectedSourceText: String? = nil) { fatalError("Compile only") }
    func establishSingleBookOverviewFixture(phone: Bool) throws { fatalError("Compile only") }
}
class R27NativeUIBase: FaithfulReaderUIBase {
    func assertTarget(backend: String) throws -> String { fatalError("Compile only") }
}
