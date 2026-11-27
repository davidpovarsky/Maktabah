import XCTest

/// Additional focused UI-04 selectors. These use Siri recognized-text delivery,
/// not a physical microphone. Platform Siri setup failures are retained; the
/// historical Native116 / Release114 manifests and timeouts are unchanged.
extension NativeRoutingAcceptanceTests {
    @MainActor
    func testSiriHistoryFromOriginalIPadReaderPreservesWorkspace() throws {
        try runOriginalSiriHistory(expectedPad: true, fromBackground: false)
    }
}

extension NativeRoutingPhoneAcceptanceTests {
    @MainActor
    func testPhoneSiriHistoryFromBackgroundPreservesOriginalReader() throws {
        try runOriginalSiriHistory(expectedPad: false, fromBackground: true)
    }
}
