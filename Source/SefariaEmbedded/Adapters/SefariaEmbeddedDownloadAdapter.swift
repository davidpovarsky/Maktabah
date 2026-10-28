//
//  SefariaEmbeddedDownloadAdapter.swift
//  Maktabah
//
//  Downstream-owned download and offline storage adapter delegating directly
//  to Sefaria-Mobile's DownloadControl.js and Expo FileSystem.
//  Conforms to OfflineLibraryProviding and OfflineWorkProviding.
//

import Foundation

public final class SefariaEmbeddedDownloadAdapter: OfflineLibraryProviding, OfflineWorkProviding, @unchecked Sendable {
    private let bridge: SefariaJSRPCBridge
    private var progressCallbacks: [String: @Sendable (OfflineInstallProgress) -> Void] = [:]

    public init(bridge: SefariaJSRPCBridge = .shared) {
        self.bridge = bridge

        Task { [weak self] in
            await bridge.addEventListener(for: "downloadProgress") { event in
                guard let self = self,
                      let data = event.payloadData,
                      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let title = dict["packageTitle"] as? String,
                      let callback = self.progressCallbacks[title] else {
                    return
                }

                let progressInfo = dict["progress"] as? [String: Any]
                let bytesWritten = (progressInfo?["totalBytesWritten"] as? Int64) ?? 0
                let totalBytes = (progressInfo?["totalBytesExpectedToWrite"] as? Int64) ?? 0

                let progress = OfflineInstallProgress(
                    packageID: title,
                    bytesDownloaded: bytesWritten,
                    totalBytes: totalBytes,
                    isComplete: bytesWritten >= totalBytes && totalBytes > 0
                )
                callback(progress)
            }
        }
    }

    public func packages(forceRefresh: Bool) async throws -> [OfflinePackage] {
        let response = try await bridge.call(method: "downloads.selected")
        guard response.isSuccess, let resultData = response.resultData else {
            return []
        }

        guard let selections = try? JSONSerialization.jsonObject(with: resultData) as? [String: Bool] else {
            return []
        }

        return selections.map { (title, isSelected) in
            OfflinePackage(
                id: title,
                title: title,
                heTitle: title,
                sizeBytes: 0,
                parentID: nil
            )
        }
    }

    public func installedPackageIDs() async -> Set<String> {
        let response = try? await bridge.call(method: "downloads.selected")
        guard let response = response, response.isSuccess, let resultData = response.resultData,
              let selections = try? JSONSerialization.jsonObject(with: resultData) as? [String: Bool] else {
            return []
        }
        return Set(selections.filter { $0.value }.map(\.key))
    }

    public func install(
        packageIDs: Set<String>,
        progress: @escaping @Sendable (OfflineInstallProgress) -> Void
    ) async throws {
        for packageID in packageIDs {
            progressCallbacks[packageID] = progress
            let params = ["packageTitle": packageID, "networkSetting": "all"]
            let paramsData = try JSONEncoder().encode(params)
            _ = try await bridge.call(
                method: "downloads.install",
                paramsData: paramsData,
                timeoutMs: 300000 // 5 minutes per package
            )
            progressCallbacks.removeValue(forKey: packageID)
        }
    }

    public func remove(packageIDs: Set<String>) async throws {
        for packageID in packageIDs {
            let params = ["packageTitle": packageID]
            let paramsData = try JSONEncoder().encode(params)
            _ = try await bridge.call(method: "downloads.remove", paramsData: paramsData)
        }
    }

    public func availableUpdates() async throws -> OfflineUpdateSummary {
        let response = try await bridge.call(method: "updates.check")
        guard response.isSuccess, let resultData = response.resultData,
              let summary = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any] else {
            return OfflineUpdateSummary(changedWorkCount: 0, totalBytes: 0)
        }

        let count = (summary["updatesAvailable"] as? Int) ?? 0
        let bytes = (summary["totalBytes"] as? Int64) ?? 0
        return OfflineUpdateSummary(changedWorkCount: count, totalBytes: bytes)
    }

    public func update(progress: @escaping @Sendable (OfflineInstallProgress) -> Void) async throws {
        _ = try await bridge.call(method: "updates.download", timeoutMs: 300000)
    }

    public func cancelInstall() async {
        _ = try? await bridge.call(method: "downloads.cancel")
        progressCallbacks.removeAll()
    }

    // MARK: - OfflineWorkProviding

    public func installedWorkKeys() async -> Set<String> {
        return await installedPackageIDs()
    }

    public func install(
        workKeys: Set<String>,
        progress: @escaping @Sendable (OfflineInstallProgress) -> Void
    ) async throws {
        try await install(packageIDs: workKeys, progress: progress)
    }

    public func remove(workKeys: Set<String>) async throws {
        try await remove(packageIDs: workKeys)
    }

    public func cancelWorkInstall() async {
        await cancelInstall()
    }
}
