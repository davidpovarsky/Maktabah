import Foundation

actor SefariaDiskCache {
    private let directory: URL
    private let maxBytes: Int64

    init(directory: URL? = nil, maxBytes: Int64 = 50 * 1_024 * 1_024) {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.directory = directory ?? caches.appendingPathComponent("Maktabah/SefariaRemote", isDirectory: true)
        self.maxBytes = maxBytes
    }

    func decode<T: Decodable & Sendable>(_ name: String) -> T? {
        let url = safeURL(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func encode<T: Encodable & Sendable>(_ value: T, as name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: safeURL(name), options: .atomic)
        trimIfNeeded()
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    private func safeURL(_ name: String) -> URL {
        directory.appendingPathComponent(name.replacingOccurrences(of: "/", with: "_"))
    }

    private func trimIfNeeded() {
        let manager = FileManager.default
        guard let files = try? manager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return }
        let records = files.compactMap { url -> (URL, Int64, Date) in
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) else {
                return (url, 0, .distantPast)
            }
            return (url, Int64(values.fileSize ?? 0), values.contentModificationDate ?? .distantPast)
        }
        var total = records.reduce(Int64(0)) { $0 + $1.1 }
        guard total > maxBytes else { return }
        for record in records.sorted(by: { $0.2 < $1.2 }) where total > maxBytes {
            try? manager.removeItem(at: record.0)
            total -= record.1
        }
    }
}
