import Foundation

extension Notification.Name {
    static let libraryOfflineAvailabilityDidChange = Notification.Name("libraryOfflineAvailabilityDidChange")
}

@MainActor
final class LibraryOfflineAvailabilityController {
    static let shared = LibraryOfflineAvailabilityController()

    private final class Snapshot: @unchecked Sendable {
        private let lock = NSLock()
        private var backendID: BackendID?
        private var installedWorkKeys: Set<String> = []
        private var supportsWorkOfflineManagement = false

        func update(backendID: BackendID, installedWorkKeys: Set<String>, supportsWorkOfflineManagement: Bool) {
            lock.withLock {
                self.backendID = backendID
                self.installedWorkKeys = installedWorkKeys
                self.supportsWorkOfflineManagement = supportsWorkOfflineManagement
            }
        }

        func isInstalled(workKey: String, backendID: BackendID) -> Bool {
            lock.withLock {
                self.backendID == backendID && installedWorkKeys.contains(workKey)
            }
        }

        var supportsOfflineManagement: Bool {
            lock.withLock { supportsWorkOfflineManagement }
        }
    }

    private(set) var backendID: BackendID?
    private(set) var installedWorkKeys: Set<String> = []
    private var refreshTask: Task<Void, Never>?
    nonisolated private let snapshot = Snapshot()

    private init() {}

    nonisolated var supportsWorkOfflineManagement: Bool {
        snapshot.supportsOfflineManagement
    }

    nonisolated func isInstalled(workKey: String, backendID: BackendID) -> Bool {
        snapshot.isInstalled(workKey: workKey, backendID: backendID)
    }

    func refresh() async {
        refreshTask?.cancel()
        refreshTask = nil
        await performRefresh()
    }

    private func performRefresh() async {
        let expectedBackend = BackendCoordinator.shared.activeBackendID
        guard let provider = BackendCoordinator.shared.offlineWorkProvider() else {
            backendID = expectedBackend
            installedWorkKeys = []
            snapshot.update(backendID: expectedBackend, installedWorkKeys: [], supportsWorkOfflineManagement: false)
            NotificationCenter.default.post(name: .libraryOfflineAvailabilityDidChange, object: expectedBackend)
            return
        }
        let keys = await provider.installedWorkKeys()
        guard !Task.isCancelled, expectedBackend == BackendCoordinator.shared.activeBackendID else { return }
        backendID = expectedBackend
        installedWorkKeys = keys
        snapshot.update(backendID: expectedBackend, installedWorkKeys: keys, supportsWorkOfflineManagement: true)
        NotificationCenter.default.post(name: .libraryOfflineAvailabilityDidChange, object: expectedBackend)
    }

    func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            await self?.performRefresh()
            self?.refreshTask = nil
        }
    }

    func resetForBackendChange() {
        refreshTask?.cancel()
        backendID = BackendCoordinator.shared.activeBackendID
        installedWorkKeys = []
        snapshot.update(
            backendID: BackendCoordinator.shared.activeBackendID,
            installedWorkKeys: [],
            supportsWorkOfflineManagement: BackendCoordinator.shared.offlineWorkProvider() != nil
        )
        scheduleRefresh()
    }
}
