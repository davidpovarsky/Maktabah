import Foundation

final class OtzariaSearchIndexManager {
    static let shared = OtzariaSearchIndexManager()

    private let fingerprintFileName = "otzaria_search_fingerprint.json"
    private let manifestFileName = "indexed_books.json"
    private let sentinelFileName = ".otzaria_index_building"
    private let userDefaultsKey = "otzaria_tantivy_index_version"
    let currentIndexVersion = "1"

    private init() {}

    var indexRootURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Otzaria/TantivySearchIndex", isDirectory: true)
    }

    func indexURL(for databasePath: String) -> URL {
        let fingerprint = stablePathHash(databasePath)
        return indexRootURL.appendingPathComponent(fingerprint, isDirectory: true)
    }

    func buildingIndexURL(for databasePath: String) -> URL {
        indexURL(for: databasePath).appendingPathExtension("building")
    }

    func previousIndexURL(for databasePath: String) -> URL {
        indexURL(for: databasePath).appendingPathExtension("previous")
    }

    func sentinelURL(for databasePath: String) -> URL {
        indexRootURL.appendingPathComponent("\(sentinelFileName).\(stablePathHash(databasePath))")
    }

    func manifestURL(indexURL: URL) -> URL {
        indexURL.appendingPathComponent(manifestFileName)
    }

    func currentFingerprint(databasePath: String) throws -> OtzariaIndexFingerprint {
        let url = URL(fileURLWithPath: databasePath)
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return OtzariaIndexFingerprint(
            databasePath: databasePath,
            fileSize: UInt64(values.fileSize ?? 0),
            modificationTime: values.contentModificationDate?.timeIntervalSince1970 ?? 0
        )
    }

    func storedFingerprint(indexURL: URL) -> OtzariaIndexFingerprint? {
        let url = indexURL.appendingPathComponent(fingerprintFileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(OtzariaIndexFingerprint.self, from: data)
    }

    func writeFingerprint(_ fingerprint: OtzariaIndexFingerprint, indexURL: URL) throws {
        try FileManager.default.createDirectory(at: indexURL, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(fingerprint)
        try data.write(to: indexURL.appendingPathComponent(fingerprintFileName), options: .atomic)
        UserDefaults.standard.set(currentIndexVersion, forKey: userDefaultsKey)
    }

    func writeManifest(_ manifest: OtzariaIndexedBooksManifest, indexURL: URL) throws {
        try FileManager.default.createDirectory(at: indexURL, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: manifestURL(indexURL: indexURL), options: .atomic)
    }

    func storedManifest(indexURL: URL) -> OtzariaIndexedBooksManifest? {
        guard let data = try? Data(contentsOf: manifestURL(indexURL: indexURL)) else { return nil }
        return try? JSONDecoder().decode(OtzariaIndexedBooksManifest.self, from: data)
    }

    func isIndexCurrent(databasePath: String) -> Bool {
        do {
            let indexURL = indexURL(for: databasePath)
            guard FileManager.default.fileExists(atPath: indexURL.path) else { return false }
            let current = try currentFingerprint(databasePath: databasePath)
            guard storedFingerprint(indexURL: indexURL) == current,
                  UserDefaults.standard.string(forKey: userDefaultsKey) == currentIndexVersion else {
                return false
            }
            let engine = try OtzariaSearchEngineBridge(indexURL: indexURL)
            let count = try engine.documentCount()
            return count > 0
        } catch {
            return false
        }
    }

    func prepareBuildingIndex(databasePath: String) throws -> URL {
        let fileManager = FileManager.default
        let buildingURL = buildingIndexURL(for: databasePath)
        try fileManager.createDirectory(at: indexRootURL, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: buildingURL.path) {
            try fileManager.removeItem(at: buildingURL)
        }
        try fileManager.createDirectory(at: buildingURL, withIntermediateDirectories: true)
        try Data(databasePath.utf8).write(to: sentinelURL(for: databasePath), options: .atomic)
        return buildingURL
    }

    func recoverInterruptedBuild(databasePath: String) throws {
        let fileManager = FileManager.default
        let sentinelURL = sentinelURL(for: databasePath)
        let buildingURL = buildingIndexURL(for: databasePath)
        guard fileManager.fileExists(atPath: sentinelURL.path) else { return }
        if fileManager.fileExists(atPath: buildingURL.path) {
            try? fileManager.removeItem(at: buildingURL)
        }
        try? fileManager.removeItem(at: sentinelURL)
    }

    func cancelBuildingIndex(databasePath: String) {
        let fileManager = FileManager.default
        let buildingURL = buildingIndexURL(for: databasePath)
        if fileManager.fileExists(atPath: buildingURL.path) {
            try? fileManager.removeItem(at: buildingURL)
        }
        try? fileManager.removeItem(at: sentinelURL(for: databasePath))
    }

    func promoteBuildingIndex(databasePath: String) throws {
        let fileManager = FileManager.default
        let finalURL = indexURL(for: databasePath)
        let buildingURL = buildingIndexURL(for: databasePath)
        let previousURL = previousIndexURL(for: databasePath)

        if fileManager.fileExists(atPath: previousURL.path) {
            try fileManager.removeItem(at: previousURL)
        }
        if fileManager.fileExists(atPath: finalURL.path) {
            try fileManager.moveItem(at: finalURL, to: previousURL)
        }

        do {
            try fileManager.moveItem(at: buildingURL, to: finalURL)
            if fileManager.fileExists(atPath: previousURL.path) {
                try? fileManager.removeItem(at: previousURL)
            }
            try? fileManager.removeItem(at: sentinelURL(for: databasePath))
        } catch {
            if fileManager.fileExists(atPath: finalURL.path) {
                try? fileManager.removeItem(at: finalURL)
            }
            if fileManager.fileExists(atPath: previousURL.path) {
                try? fileManager.moveItem(at: previousURL, to: finalURL)
            }
            throw error
        }
    }

    func clearIndex(databasePath: String) throws {
        let url = indexURL(for: databasePath)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func stablePathHash(_ value: String) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(hash, radix: 16)
    }
}
