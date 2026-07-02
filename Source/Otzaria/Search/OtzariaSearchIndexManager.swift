import Foundation

final class OtzariaSearchIndexManager {
    static let shared = OtzariaSearchIndexManager()

    private let fingerprintFileName = "otzaria_search_fingerprint.json"
    private let userDefaultsKey = "otzaria_tantivy_index_version"
    private let currentIndexVersion = "1"

    private init() {}

    var indexRootURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Otzaria/TantivySearchIndex", isDirectory: true)
    }

    func indexURL(for databasePath: String) -> URL {
        let fingerprint = stablePathHash(databasePath)
        return indexRootURL.appendingPathComponent(fingerprint, isDirectory: true)
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

    func isIndexCurrent(databasePath: String) -> Bool {
        do {
            let indexURL = indexURL(for: databasePath)
            let current = try currentFingerprint(databasePath: databasePath)
            return storedFingerprint(indexURL: indexURL) == current &&
                UserDefaults.standard.string(forKey: userDefaultsKey) == currentIndexVersion
        } catch {
            return false
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
