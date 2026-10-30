//
//  SefariaEmbeddedDownloadAdapter.swift
//  Maktabah
//
//  Downstream-owned adapter providing offline package management, download progress,
//  and updates via original Sefaria-Mobile DownloadControl.js runtime.
//

import Foundation

actor SefariaEmbeddedDownloadAdapter: OfflineLibraryProviding, OfflineWorkProviding {
    static let shared = SefariaEmbeddedDownloadAdapter()

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
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        let packageTitle = json["packageTitle"] as? String
        let completedBytes = (json["bytesWritten"] as? Int64)
            ?? Int64((json["bytesWritten"] as? Double) ?? Double((json["bytesWritten"] as? Int) ?? 0))
        let totalBytes = (json["totalBytes"] as? Int64)
            ?? Int64((json["totalBytes"] as? Double) ?? Double((json["totalBytes"] as? Int) ?? 0))
        let fraction = (json["fraction"] as? Double)
            ?? (totalBytes > 0 ? Double(completedBytes) / Double(totalBytes) : 0.0)

        guard let packageTitle = json["packageTitle"] as? String,
              let handler = activeProgressHandlers[packageTitle] else {
            return
        }

        let update = OfflineInstallProgress(
            phase: .downloading,
            packageID: packageTitle,
            completedBytes: completedBytes,
            totalBytes: totalBytes > 0 ? totalBytes : 0
        )

        handler(update)
    }

    // MARK: - OfflineLibraryProviding

    func packages(forceRefresh: Bool) async throws -> [OfflinePackage] {
        try await SefariaRuntimeManager.shared.ensurePackagesReady()
        let response = try await SefariaJSRPCBridge.shared.call(method: "downloads.packages")
        guard response.isSuccess else {
            throw response.error ?? SefariaRPCError(code: "PACKAGES_FETCH_FAILED", message: "Failed to fetch packages")
        }
        return try response.decodeResult([OfflinePackage].self)
    }

    func installedPackageIDs() async -> Set<String> {
        guard (try? await SefariaRuntimeManager.shared.ensurePackagesReady()) != nil else {
            return []
        }
        guard let response = try? await SefariaJSRPCBridge.shared.call(method: "downloads.installed"),
              response.isSuccess,
              let resultJson = response.resultJson,
              let data = resultJson.data(using: .utf8) else {
            return []
        }

        if let jsonDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let pkgs = (jsonDict["packages"] as? [String]) ?? []
            return Set(pkgs)
        } else if let ids = try? JSONDecoder().decode([String].self, from: data) {
            return Set(ids)
        }
        return []
    }

    func install(packageIDs: Set<String>, progress: @escaping @Sendable (OfflineInstallProgress) -> Void) async throws {
        try await SefariaRuntimeManager.shared.ensurePackagesReady()
        for packageID in packageIDs {
            activeProgressHandlers[packageID] = progress
            let params = ["packageName": packageID, "networkSetting": "all"]
            let paramsJson = String(data: try JSONSerialization.data(withJSONObject: params), encoding: .utf8)

            progress(OfflineInstallProgress(
                phase: .downloading,
                packageID: packageID,
                completedBytes: 0,
                totalBytes: 0
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

            // Verify package was actually recorded as installed
            let installedIDs = await installedPackageIDs()
            let isVerified = installedIDs.contains(packageID)
            guard isVerified else {
                throw SefariaRPCError(
                    code: "INSTALL_VERIFICATION_FAILED",
                    message: "Package \(packageID) completion could not be verified in local store",
                    retryable: true
                )
            }

            progress(OfflineInstallProgress(
                phase: .finished,
                packageID: packageID,
                completedBytes: 0,
                totalBytes: 0
            ))
        }
    }

    func remove(packageIDs: Set<String>) async throws {
        try await SefariaRuntimeManager.shared.ensurePackagesReady()
        let params = ["packageTitles": Array(packageIDs)]
        let paramsJson = String(data: try JSONSerialization.data(withJSONObject: params), encoding: .utf8)
        let response = try await SefariaJSRPCBridge.shared.call(method: "downloads.remove", paramsJson: paramsJson)
        guard response.isSuccess else {
            throw response.error ?? SefariaRPCError(code: "REMOVE_FAILED", message: "Failed to remove packages")
        }
    }

    func availableUpdates() async throws -> OfflineUpdateSummary {
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

    func update(progress: @escaping @Sendable (OfflineInstallProgress) -> Void) async throws {
        let updates = try await availableUpdates()
        guard updates.hasUpdates else { return }

        if !updates.affectedPackageIDs.isEmpty {
            try await install(packageIDs: updates.affectedPackageIDs, progress: progress)
            return
        }

        progress(OfflineInstallProgress(phase: .downloading, packageID: "Update", completedBytes: 0, totalBytes: 0))
        activeProgressHandlers["Update"] = progress
        defer { activeProgressHandlers.removeValue(forKey: "Update") }

        let response = try await SefariaJSRPCBridge.shared.call(
            method: "updates.download",
            paramsJson: nil,
            timeoutMs: 600_000
        )
        guard response.isSuccess else {
            throw response.error ?? SefariaRPCError(code: "UPDATE_FAILED", message: "Failed to download Sefaria updates")
        }
        progress(OfflineInstallProgress(phase: .finished, packageID: "Update", completedBytes: 0, totalBytes: 0))
    }

    func cancelInstall() async {
        _ = try? await SefariaJSRPCBridge.shared.call(method: "downloads.cancel")
        activeProgressHandlers.removeAll()
    }

    // MARK: - OfflineWorkProviding

    func installedWorkKeys() async -> Set<String> {
        guard (try? await SefariaRuntimeManager.shared.ensurePackagesReady()) != nil else {
            return []
        }
        guard let response = try? await SefariaJSRPCBridge.shared.call(method: "downloads.installed"),
              response.isSuccess,
              let resultJson = response.resultJson,
              let data = resultJson.data(using: .utf8) else {
            return []
        }

        if let jsonDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let books = jsonDict["books"] as? [String] {
            return Set(books)
        }
        return []
    }

    func install(workKeys: Set<String>, progress: @escaping @Sendable (OfflineInstallProgress) -> Void) async throws {
        let allPackages = (try? await packages(forceRefresh: false)) ?? []
        var packagesToInstall = Set<String>()

        for workKey in workKeys {
            for pkg in allPackages {
                if pkg.indexTitles?.contains(workKey) == true {
                    packagesToInstall.insert(pkg.id)
                }
            }
        }

        guard !packagesToInstall.isEmpty else {
            throw LibraryBackendError.invalidResponse("No package found containing requested works: \(workKeys.joined(separator: ", "))")
        }

        try await install(packageIDs: packagesToInstall, progress: progress)
    }

    func remove(workKeys: Set<String>) async throws {
        try await SefariaRuntimeManager.shared.ensurePackagesReady()
        let params = ["bookTitles": Array(workKeys)]
        let paramsJson = String(data: try JSONSerialization.data(withJSONObject: params), encoding: .utf8)
        let response = try await SefariaJSRPCBridge.shared.call(method: "downloads.remove", paramsJson: paramsJson)
        guard response.isSuccess else {
            throw response.error ?? SefariaRPCError(code: "REMOVE_FAILED", message: "Failed to remove works")
        }
    }

    func cancelWorkInstall() async {
        await cancelInstall()
    }
}
