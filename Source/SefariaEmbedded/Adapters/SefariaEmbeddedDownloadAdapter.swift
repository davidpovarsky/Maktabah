//
//  SefariaEmbeddedDownloadAdapter.swift
//  Maktabah
//
//  Downstream-owned adapter providing offline package management, download progress,
//  and updates via original Sefaria-Mobile DownloadControl.js runtime.
//

import Foundation

public actor SefariaEmbeddedDownloadAdapter: OfflineLibraryProviding, OfflineWorkProviding {
    public static let shared = SefariaEmbeddedDownloadAdapter()

    private var activeProgressHandlers: [String: @Sendable (OfflineInstallProgress) -> Void] = [:]

    private init() {
        Task {
            await self.registerEventListener()
        }
    }

    private func registerEventListener() {
        Task {
            await SefariaJSRPCBridge.shared.addEventListener(for: "downloadProgress") { [weak self] event in
                guard let self else { return }
                Task {
                    await self.handleDownloadProgressEvent(event)
                }
            }
        }
    }

    private func handleDownloadProgressEvent(_ event: SefariaRPCEvent) {
        guard let payloadJson = event.payloadJson,
              let data = payloadJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let packageTitle = json["packageTitle"] as? String else {
            return
        }

        let progress = (json["progress"] as? Double) ?? 0.0
        let completedBytes = Int64(progress * 100_000_000)
        let totalBytes: Int64 = 100_000_000

        let update = OfflineInstallProgress(
            phase: progress >= 1.0 ? .finished : .downloading,
            packageID: packageTitle,
            completedBytes: completedBytes,
            totalBytes: totalBytes
        )

        if let handler = activeProgressHandlers[packageTitle] {
            handler(update)
        }
    }

    // MARK: - OfflineLibraryProviding

    public func packages(forceRefresh: Bool) async throws -> [OfflinePackage] {
        try await SefariaRuntimeManager.shared.ensurePackagesReady()
        let response = try await SefariaJSRPCBridge.shared.call(method: "downloads.packages")
        guard response.isSuccess else {
            throw response.error ?? SefariaRPCError(code: "PACKAGES_FETCH_FAILED", message: "Failed to fetch packages")
        }
        return try response.decodeResult([OfflinePackage].self)
    }

    public func installedPackageIDs() async -> Set<String> {
        guard (try? await SefariaRuntimeManager.shared.ensurePackagesReady()) != nil else {
            return []
        }
        guard let response = try? await SefariaJSRPCBridge.shared.call(method: "downloads.installed"),
              response.isSuccess,
              let ids = try? response.decodeResult([String].self) else {
            return []
        }
        return Set(ids)
    }

    public func install(packageIDs: Set<String>, progress: @escaping @Sendable (OfflineInstallProgress) -> Void) async throws {
        try await SefariaRuntimeManager.shared.ensurePackagesReady()
        for packageID in packageIDs {
            activeProgressHandlers[packageID] = progress
            let params = ["packageName": packageID, "networkSetting": "wifiOnly"]
            let paramsJson = String(data: try JSONSerialization.data(withJSONObject: params), encoding: .utf8)

            progress(OfflineInstallProgress(
                phase: .downloading,
                packageID: packageID,
                completedBytes: 0,
                totalBytes: 100_000_000
            ))

            let response = try await SefariaJSRPCBridge.shared.call(
                method: "downloads.install",
                paramsJson: paramsJson,
                timeoutMs: 600_000 // 10 minute timeout for large downloads
            )
            activeProgressHandlers.removeValue(forKey: packageID)

            guard response.isSuccess else {
                throw response.error ?? SefariaRPCError(code: "INSTALL_FAILED", message: "Failed to install package \(packageID)")
            }

            progress(OfflineInstallProgress(
                phase: .finished,
                packageID: packageID,
                completedBytes: 100_000_000,
                totalBytes: 100_000_000
            ))
        }
    }

    public func remove(packageIDs: Set<String>) async throws {
        try await SefariaRuntimeManager.shared.ensurePackagesReady()
        let params = ["packageTitles": Array(packageIDs)]
        let paramsJson = String(data: try JSONSerialization.data(withJSONObject: params), encoding: .utf8)
        let response = try await SefariaJSRPCBridge.shared.call(method: "downloads.remove", paramsJson: paramsJson)
        guard response.isSuccess else {
            throw response.error ?? SefariaRPCError(code: "REMOVE_FAILED", message: "Failed to remove packages")
        }
    }

    public func availableUpdates() async throws -> OfflineUpdateSummary {
        try await SefariaRuntimeManager.shared.ensurePackagesReady()
        let response = try await SefariaJSRPCBridge.shared.call(method: "updates.check")
        guard response.isSuccess,
              let resultJson = response.resultJson,
              let data = resultJson.data(using: .utf8) else {
            return OfflineUpdateSummary(changedWorkCount: 0, affectedPackageIDs: [])
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let count = (json["count"] as? Int) ?? (json["hasUpdates"] as? Bool == true ? 1 : 0)
            let packageIDs = (json["packageIDs"] as? [String]) ?? []
            return OfflineUpdateSummary(changedWorkCount: count, affectedPackageIDs: Set(packageIDs))
        } else if let array = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  let allBooks = array.first as? [Any] {
            return OfflineUpdateSummary(changedWorkCount: allBooks.count, affectedPackageIDs: [])
        }

        return OfflineUpdateSummary(changedWorkCount: 0, affectedPackageIDs: [])
    }

    // MARK: - OfflineWorkProviding

    public func installedWorkKeys() async -> Set<String> {
        let pkgs = await installedPackageIDs()
        return pkgs
    }

    public func install(workKeys: Set<String>, progress: @escaping @Sendable (OfflineInstallProgress) -> Void) async throws {
        try await install(packageIDs: workKeys, progress: progress)
    }
}
