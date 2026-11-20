import CloudKit
import Foundation

extension AnnotationLocalEditorCloudClient {
    /// Uses only the original configured container/private DB/zone and original
    /// Annotation CKRecord mapping. It grants no Anytype Space, exchange target,
    /// substitute account, or rich-body transport.
    static func original() -> Self? {
        guard AppConfig.useICloud else { return nil }
        let core = CloudKitCoreManager.shared
        guard core.isAvailable, let container = core.container, core.privateDatabase != nil else { return nil }
        let observation = AnnotationLocalEditorCloudAccountObservation(center: .default, changedNotification: .CKAccountChanged)
        let lifetime = observation.lifetime
        return .init(account: observation, isPermitted: { AppConfig.useICloud }, resolveAccount: {
            guard lifetime.isCurrent, AppConfig.useICloud else { return nil }
            guard try await container.accountStatus() == .available,
                  lifetime.isCurrent, AppConfig.useICloud else { return nil }
            let identity = try await container.userRecordID()
            guard lifetime.isCurrent, AppConfig.useICloud else { return nil }
            return try .init(recordName: identity.recordName, zoneName: identity.zoneID.zoneName,
                             ownerName: identity.zoneID.ownerName)
        }, debounce: { annotation in
            guard let recordID = annotation.ckRecordId else { throw AnnotationLocalEditorCloudDeferral.invalidRecord }
            // One operation owns this original two-second debouncer. The shared
            // UUID-only buffer cannot merge different profile/account owners.
            let debouncer = CloudKitUploadDebouncer<Annotation>()
            let result: Result<Annotation, any Error> = await withCheckedContinuation { continuation in
                Task {
                    await debouncer.add(items: [(id: recordID, item: annotation)], completion: nil, debounce: true) { items, callbacks in
                        guard items.count == 1, callbacks.isEmpty, let item = items.first else {
                            continuation.resume(returning: .failure(AnnotationLocalEditorCloudDeferral.invalidRecord))
                            return
                        }
                        continuation.resume(returning: .success(item))
                    }
                }
            }
            // The original debouncer's timer captures weak self. Retain this
            // actual instance through completion, without adding a retain cycle.
            withExtendedLifetime(debouncer) {}
            return try result.get()
        }, upload: { annotation in
            guard let record = annotation.toCKRecord(zoneID: core.zoneId) else { return .notAttempted(.invalidRecord) }
            return await withCheckedContinuation { continuation in
                // Completion precedes notification as in the original Core.
                // This operation owns its later notification and therefore
                // suppresses only the default live-settings/global worker path.
                core.upload(records: [record], completionNotification: {}) { result in
                    switch result {
                    case .success: continuation.resume(returning: .succeeded)
                    case .failure(let error): continuation.resume(returning: .failed(error))
                    }
                }
            }
        }, workerRequest: {
            core.workerRequestSnapshot()
        }, waitForWorker: {
            try await Task.sleep(for: .seconds(60))
        }, sendWorker: { request in
            await withCheckedContinuation { continuation in
                URLSession.shared.dataTask(with: request) { _, _, error in
                    if let error { continuation.resume(returning: .failure(error)) }
                    else { continuation.resume(returning: .success(())) }
                }.resume()
            }
        })
    }
}
