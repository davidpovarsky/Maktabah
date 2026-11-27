import Foundation
import Observation
import Glibc

/// Scene-owned presentation lifetime. Closing the final reader tab must not
/// dismiss the overview or make the covered reader ready for native commands.
struct ReaderOverviewPresentationState: Equatable, Sendable {
    private(set) var requestID: UUID?
    private(set) var mountedID: UUID?
    private(set) var isRequested = false

    var blocksRouting: Bool { requestID != nil || mountedID != nil }

    @discardableResult
    mutating func request() -> UUID {
        // Do not reopen a presentation whose UIKit dismissal is still pending.
        if let requestID { return requestID }
        let id = UUID()
        requestID = id
        isRequested = true
        return id
    }

    func canPresent(_ id: UUID) -> Bool {
        requestID == id && isRequested && mountedID == nil
    }

    @discardableResult
    mutating func didMount(_ id: UUID) -> Bool {
        // UIKit may finish its presentation after a close was requested.
        // Retain the mounted identity until that actual controller is gone.
        guard requestID == id, mountedID == nil else { return false }
        mountedID = id
        return true
    }

    @discardableResult
    mutating func requestClose(_ id: UUID) -> Bool {
        guard requestID == id, isRequested else { return false }
        isRequested = false
        return true
    }

    @discardableResult
    mutating func didDismiss(_ id: UUID) -> Bool {
        guard requestID == id, !isRequested,
              mountedID == nil || mountedID == id else { return false }
        clear()
        return true
    }

    @discardableResult
    mutating func didDismantle(_ id: UUID) -> Bool {
        guard requestID == id, mountedID == nil || mountedID == id else { return false }
        clear()
        return true
    }

    private mutating func clear() {
        requestID = nil
        mountedID = nil
        isRequested = false
    }
}

@MainActor @Observable
private final class ActualSidebarRequestOwner {
    var overview = ReaderOverviewPresentationState() {
        willSet {
            if newValue.requestID != overview.requestID || newValue.isRequested != overview.isRequested {
                for notify in Array(overviewRequestObservers.values) { notify() }
            }
        }
    }
    @ObservationIgnored private var overviewRequestObservers: [UUID: @MainActor () -> Void] = [:]

    func observeOverviewRequestChanges(_ notify: @escaping @MainActor () -> Void) -> UUID {
        let token = UUID(); overviewRequestObservers[token] = notify; return token
    }

    func removeOverviewRequestObserver(_ token: UUID) { overviewRequestObservers.removeValue(forKey: token) }
}

enum Host: Hashable { case compactRoot, tabletToolbar, overview, profiles }
enum OriginalChange: Hashable { case overview, profiles, navigation, draft, layout }

private enum OwnedChange: Equatable {
    case host(Host, UUID, OriginalChange)
    case sidebar
}


@MainActor private final class CurrentAllowanceBoundary {
    var ownedChange: OwnedChange?
    var invalidations = 0
    func invalidateRetainedSources() { invalidations += 1 }
    func originalWillSetCallback() {
        if ownedChange != .sidebar { invalidateRetainedSources() }
    }
    func performOriginalSetter(_ perform: () -> Void) {
        ownedChange = .sidebar
        defer { ownedChange = nil }
        perform()
    }
}
@main private struct BeforeCorrectionControl {
    @MainActor static func main() {
        let sidebar = ActualSidebarRequestOwner()
        let boundary = CurrentAllowanceBoundary()
        let original = ReaderOverviewPresentationState()
        var presented = original
        presented.request()
        var reentered = false
        var callbackCount = 0
        _ = sidebar.observeOverviewRequestChanges {
            callbackCount += 1
            boundary.originalWillSetCallback()
            if !reentered {
                reentered = true
                sidebar.overview = presented
                sidebar.overview = original
            }
        }
        boundary.performOriginalSetter { sidebar.overview = presented }
        print("actual_original_willSet_callbacks=\(callbackCount) retained_source_invalidations=\(boundary.invalidations)")
        guard callbackCount >= 2 && boundary.invalidations > 0 else {
            print("FAIL: a second matching original setter callback reused the synchronous allowance")
            exit(1)
        }
    }
}
