import XCTest
import UIKit

// Four explicit focused selectors; not a replacement for Native116 or
// Release114+2, and not a claim that the inherited suites have executed.
final class NativeSearchEntryAcceptanceTests: NativeRoutingAcceptanceTests {
    @MainActor
    func testColdSystemIntentOpensOriginalSearchAndFocusesQueryEntry() async throws {
        try await runOriginalSearchEntry(expectedPad: true, warmPrivateQuery: false)
    }

    @MainActor
    func testWarmPublicQueryEntryPreservesPrivateQueryAndOriginalOwner() async throws {
        try await runOriginalSearchEntry(expectedPad: true, warmPrivateQuery: true)
    }
}

final class NativeSearchEntryPhoneAcceptanceTests: NativeRoutingAcceptanceTests {
    @MainActor
    func testPhoneColdSystemIntentOpensOriginalSearchAndFocusesQueryEntry() async throws {
        try await runOriginalSearchEntry(expectedPad: false, warmPrivateQuery: false)
    }

    @MainActor
    func testPhoneWarmPublicQueryEntryPreservesPrivateQueryAndOriginalOwner() async throws {
        try await runOriginalSearchEntry(expectedPad: false, warmPrivateQuery: true)
    }
}
