import Foundation

final class OtzariaFileLogger {
    static let shared = OtzariaFileLogger()

    private let queue = DispatchQueue(label: "org.maktabah.otzaria.filelogger")
    private let fileManager = FileManager.default
    private let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private init() {}

    func log(_ message: String) {
        queue.async { [formatter, fileManager] in
            guard let url = Self.logFileURL(fileManager: fileManager) else { return }
            let line = "\(formatter.string(from: Date())) \(message)\n"
            guard let data = line.data(using: .utf8) else { return }

            do {
                try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fileManager.fileExists(atPath: url.path) {
                    let handle = try FileHandle(forWritingTo: url)
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                } else {
                    try data.write(to: url, options: .atomic)
                }
            } catch {
                NSLog("%@", "[OtzariaFileLogger] \(error.localizedDescription)")
            }
        }
    }

    func clear() {
        queue.async { [fileManager] in
            guard let url = Self.logFileURL(fileManager: fileManager) else { return }
            try? fileManager.removeItem(at: url)
        }
    }

    private static func logFileURL(fileManager: FileManager) -> URL? {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documents
            .appendingPathComponent("OtzariaLogs", isDirectory: true)
            .appendingPathComponent("otzaria-reader.log", isDirectory: false)
    }
}
