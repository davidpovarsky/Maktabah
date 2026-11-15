import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// Current native state participates in freshness even before a command exists
/// or when a particular route cannot be advertised. Private values stay inside
/// this trusted in-process observation; this type has no wire representation.
public struct NativeSceneIdentity: Sendable, Equatable {
    public let topLevel: Int
    public let activeTabID: UIStableID?
    public let section: ActionTextRef?
    public let selectedRange: UIUTF16Range?
    public let state: UIStateSpec
    public let libraryQuery: String
    public let globalQuery: String
    public init(topLevel: Int, activeTabID: UIStableID?, section: ActionTextRef?, selectedRange: UIUTF16Range?,
                state: UIStateSpec, libraryQuery: String, globalQuery: String) {
        self.topLevel = topLevel; self.activeTabID = activeTabID; self.section = section; self.selectedRange = selectedRange
        self.state = state; self.libraryQuery = libraryQuery; self.globalQuery = globalQuery
    }
}
