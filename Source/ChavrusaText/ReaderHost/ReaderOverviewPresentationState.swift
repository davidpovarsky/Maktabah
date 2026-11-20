import Foundation

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
