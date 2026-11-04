import Foundation

/// Coordinator for defensive reader session restoration in ChavrusaText.
/// Fixes SESSION-01 by ensuring `activeTabId` is only selected if it actually exists in
/// the restored open tabs list, falling back safely without force-unwrapping to the first valid restored tab.
final class ReaderSessionRestoreCoordinator {
    struct RestoredSessionState<Tab: Identifiable> {
        let validTabs: [Tab]
        let activeTab: Tab?
        let activeTabId: Tab.ID?
        let wasStaleIdNormalized: Bool

        init(
            validTabs: [Tab],
            activeTab: Tab?,
            activeTabId: Tab.ID?,
            wasStaleIdNormalized: Bool
        ) {
            self.validTabs = validTabs
            self.activeTab = activeTab
            self.activeTabId = activeTabId
            self.wasStaleIdNormalized = wasStaleIdNormalized
        }
    }

    init() {}

    /// Resolves restored active tab defensively against the list of restored tabs.
    /// Never force-unwraps and requires only `Identifiable` conformance from Tab.
    func resolveActiveTab<Tab: Identifiable>(
        savedActiveId: Tab.ID?,
        restoredTabs: [Tab]
    ) -> RestoredSessionState<Tab> where Tab.ID: Equatable {
        guard !restoredTabs.isEmpty else {
            return RestoredSessionState(
                validTabs: [],
                activeTab: nil,
                activeTabId: nil,
                wasStaleIdNormalized: false
            )
        }

        if let savedId = savedActiveId, let match = restoredTabs.first(where: { $0.id == savedId }) {
            return RestoredSessionState(
                validTabs: restoredTabs,
                activeTab: match,
                activeTabId: match.id,
                wasStaleIdNormalized: false
            )
        }

        // Safe fallback without force unwrap
        guard let fallback = restoredTabs.first else {
            return RestoredSessionState(
                validTabs: [],
                activeTab: nil,
                activeTabId: nil,
                wasStaleIdNormalized: false
            )
        }

        return RestoredSessionState(
            validTabs: restoredTabs,
            activeTab: fallback,
            activeTabId: fallback.id,
            wasStaleIdNormalized: savedActiveId != nil
        )
    }
}

extension ReaderSessionRestoreCoordinator.RestoredSessionState: Equatable where Tab: Equatable, Tab.ID: Equatable {
    static func == (
        lhs: ReaderSessionRestoreCoordinator.RestoredSessionState<Tab>,
        rhs: ReaderSessionRestoreCoordinator.RestoredSessionState<Tab>
    ) -> Bool {
        lhs.validTabs == rhs.validTabs &&
        lhs.activeTab == rhs.activeTab &&
        lhs.activeTabId == rhs.activeTabId &&
        lhs.wasStaleIdNormalized == rhs.wasStaleIdNormalized
    }
}
