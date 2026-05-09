import Foundation

final class AnnotationsResultsFileMonitor {
    static let shared = AnnotationsResultsFileMonitor()

    private let syncQueue = DispatchQueue(label: "com.maktabah.annotations-results-file-monitor")
    private var presenters: [PresentedDatabaseFile] = []
    private var isSuppressingCallbacks = false
    private var pendingReloadWorkItem: DispatchWorkItem?

    private init() {}

    func suppressCallbacks<T>(_ operation: () throws -> T) rethrows -> T {
        syncQueue.sync {
            isSuppressingCallbacks = true
            pendingReloadWorkItem?.cancel()
            pendingReloadWorkItem = nil
        }

        defer {
            syncQueue.sync {
                isSuppressingCallbacks = false
            }
        }

        return try operation()
    }

    func updatePresentedFiles(in folderURL: URL?) {
        syncQueue.sync {
            presenters.forEach(NSFileCoordinator.removeFilePresenter(_:))
            presenters.removeAll()

            guard let folderURL else { return }

            let files = [
                folderURL.appendingPathComponent("Annotations.sqlite"),
                folderURL.appendingPathComponent("SearchResults.sqlite"),
            ]

            presenters = files.map { PresentedDatabaseFile(url: $0) { [weak self] in
                self?.scheduleReload()
            } }

            presenters.forEach(NSFileCoordinator.addFilePresenter(_:))
        }
    }

    private func scheduleReload() {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }

            let shouldReload = syncQueue.sync { !self.isSuppressingCallbacks }
            guard shouldReload else { return }

            DispatchQueue.main.async {
                AppConfig.setupAnnotationsAndResults()
            }
        }

        syncQueue.sync {
            guard !isSuppressingCallbacks else { return }
            pendingReloadWorkItem?.cancel()
            pendingReloadWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
        }
    }
}

private final class PresentedDatabaseFile: NSObject, NSFilePresenter {
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue
    private let onExternalChange: @Sendable () -> Void

    init(url: URL, onExternalChange: @escaping @Sendable () -> Void) {
        presentedItemURL = url
        self.onExternalChange = onExternalChange
        presentedItemOperationQueue = {
            let queue = OperationQueue()
            queue.maxConcurrentOperationCount = 1
            queue.qualityOfService = .userInitiated
            return queue
        }()
        super.init()
    }

    func presentedItemDidChange() {
        onExternalChange()
    }

    func presentedItemDidMove(to newURL: URL) {
        onExternalChange()
    }

    func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void) {
        onExternalChange()
        completionHandler(nil)
    }
}
