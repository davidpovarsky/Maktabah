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

/// One validated setter permits one matching original publication only.
/// Reentrant writes cannot borrow the rest of the perform() stack frame.
private struct OwnedSetterAllowance {
    let change: OwnedChange
    private var consumed = false
    init(change: OwnedChange) { self.change = change }
    mutating func consume(_ actual: OwnedChange) -> Bool {
        guard !consumed, actual == change else { return false }
        consumed = true
        return true
    }
}


@MainActor private final class CurrentAllowanceBoundary {
    var ownedChange: OwnedSetterAllowance?
    var invalidations = 0
    func invalidateRetainedSources() { invalidations += 1 }
    func originalWillSetCallback() {
        if ownedChange?.consume(.sidebar) != true { invalidateRetainedSources() }
    }
    struct HostToken { let token: UUID }
    func hostCallback(kind: Host, host: HostToken, change: OriginalChange) {
        if ownedChange?.consume(.host(kind, host.token, change)) != true { invalidateRetainedSources() }
    }
    func performHostSetter(kind: Host, token: UUID, change: OriginalChange, _ perform: () -> Void) {
        ownedChange = .init(change: .host(kind, token, change))
        defer { ownedChange = nil }
        perform()
    }
    func performOriginalSetter(_ perform: () -> Void) {
        ownedChange = .init(change: .sidebar)
        defer { ownedChange = nil }
        perform()
    }
}
@main private struct AfterCorrectionControl {
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
        let hostBoundary = CurrentAllowanceBoundary()
        let token = UUID()
        let host = CurrentAllowanceBoundary.HostToken(token: token)
        hostBoundary.performHostSetter(kind: .overview, token: token, change: .profiles) {
            hostBoundary.hostCallback(kind: .overview, host: host, change: .profiles)
            guard hostBoundary.invalidations == 0 else { exit(2) }
            hostBoundary.hostCallback(kind: .overview, host: host, change: .profiles)
            guard hostBoundary.invalidations == 1 else { exit(3) }
            hostBoundary.hostCallback(kind: .overview, host: host, change: .profiles)
            guard hostBoundary.invalidations == 2 else { exit(4) }
        }
        for (kind, other, change) in [(Host.profiles, token, OriginalChange.profiles),
                                      (.overview, UUID(), .profiles), (.overview, token, .draft)] {
            let rejected = CurrentAllowanceBoundary()
            rejected.performHostSetter(kind: .overview, token: token, change: .profiles) {
                rejected.hostCallback(kind: kind, host: .init(token: other), change: change)
            }
            guard rejected.invalidations == 1 else { exit(5) }
        }
        print("PASS: original reentrant sidebar cycle, one exact host callback, duplicate/third callback and foreign host/token/field")
    }
}
