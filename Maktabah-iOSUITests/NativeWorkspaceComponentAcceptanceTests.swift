import XCTest

// Separate focused selectors. Historical Native116 / Release114 sets are unchanged.
// Every route uses real system entity discovery, system Intent execution, original
// UIKit visibility, one canonical root+focus receipt and preserved workspace IDs.
extension NativeRoutingAcceptanceTests {
    @MainActor
    func testSystemWorkspaceProfilesListFromHistoryUsesOriginalSheet() async throws {
        try await runOriginalComponentSystemIntent(expectedPad: true,
            destination: "native.workspace.profiles", title: "Study Profiles",
            anchor: "native.workspace.profiles.list", identifier: "study-profile-management",
            presentation: "sheet")
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "study-profile-color").firstMatch.exists)
    }

    @MainActor
    func testSystemWorkspaceGroupsThenCreateRevealsOriginalControlWithoutDraft() async throws {
        try await runOriginalComponentSystemIntent(expectedPad: true,
            destination: "native.workspace.profiles", title: "Manage Tab Groups",
            anchor: "native.workspace.profiles.groups", identifier: "study-group-management",
            presentation: "sheet")
        try await runOriginalComponentSystemIntent(expectedPad: true,
            destination: "native.workspace.profiles", title: "New Study Profile",
            anchor: "native.workspace.profiles.newProfile", identifier: "study-profile-create",
            presentation: "sheet", useCurrentOriginalSurface: true)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "study-profile-color").firstMatch.exists,
                       "Navigation reveals the original create control without activating its draft")
    }

    @MainActor
    func testSystemWorkspaceOverviewGroupSelectorFromHistoryPreservesTabs() async throws {
        try await runOriginalComponentSystemIntent(expectedPad: true,
            destination: "native.workspace.overview", title: "Tab Groups",
            anchor: "native.workspace.overview.groups", identifier: "study-group-selector",
            presentation: "sheet")
    }

    @MainActor
    func testSystemWorkspaceOverviewActionsFromBackgroundDoNotExecuteMenu() async throws {
        try await runOriginalComponentSystemIntent(expectedPad: true,
            destination: "native.workspace.overview", title: "Tab group actions",
            anchor: "native.workspace.overview.actions", identifier: "study-group-actions-menu",
            presentation: "sheet", fromBackground: true)
        XCTAssertFalse(app.alerts["Tab group name"].exists)
    }

    @MainActor
    func testSystemWorkspaceOverviewBothOriginalLayoutsRemainBound() async throws {
        try await runOriginalWorkspaceLayoutSystemIntents(expectedPad: true)
    }
}

extension NativeRoutingPhoneAcceptanceTests {
    @MainActor
    func testPhoneSystemWorkspaceProfilesListFromBackgroundUsesOriginalNestedSheet() async throws {
        try await runOriginalComponentSystemIntent(expectedPad: false,
            destination: "native.workspace.profiles", title: "Study Profiles",
            anchor: "native.workspace.profiles.list", identifier: "study-profile-management",
            presentation: "sheet", fromBackground: true)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "study-profile-color").firstMatch.exists)
    }

    @MainActor
    func testPhoneSystemWorkspaceGroupsThenCreateRevealsOriginalControlWithoutDraft() async throws {
        try await runOriginalComponentSystemIntent(expectedPad: false,
            destination: "native.workspace.profiles", title: "Manage Tab Groups",
            anchor: "native.workspace.profiles.groups", identifier: "study-group-management",
            presentation: "sheet")
        try await runOriginalComponentSystemIntent(expectedPad: false,
            destination: "native.workspace.profiles", title: "New Study Profile",
            anchor: "native.workspace.profiles.newProfile", identifier: "study-profile-create",
            presentation: "sheet", useCurrentOriginalSurface: true)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "study-profile-color").firstMatch.exists)
    }

    @MainActor
    func testPhoneSystemWorkspaceOverviewGroupSelectorPreservesTabs() async throws {
        try await runOriginalComponentSystemIntent(expectedPad: false,
            destination: "native.workspace.overview", title: "Tab Groups",
            anchor: "native.workspace.overview.groups", identifier: "study-group-selector",
            presentation: "sheet")
    }

    @MainActor
    func testPhoneSystemWorkspaceOverviewActionsDoNotExecuteMenu() async throws {
        try await runOriginalComponentSystemIntent(expectedPad: false,
            destination: "native.workspace.overview", title: "Tab group actions",
            anchor: "native.workspace.overview.actions", identifier: "study-group-actions-menu",
            presentation: "sheet")
        XCTAssertFalse(app.alerts["Tab group name"].exists)
    }

    @MainActor
    func testPhoneSystemWorkspaceProfileMenuIsOriginalVisibleControl() async throws {
        try await runOriginalComponentSystemIntent(expectedPad: false,
            destination: "native.workspace.overview", title: "Study Profiles menu",
            anchor: "native.workspace.overview.profileMenu", identifier: "study-profile-menu",
            presentation: "sheet")
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "study-profile-management").firstMatch.exists)
    }

    @MainActor
    func testPhoneSystemWorkspaceOverviewBothOriginalLayoutsRemainBound() async throws {
        try await runOriginalWorkspaceLayoutSystemIntents(expectedPad: false)
    }
}
