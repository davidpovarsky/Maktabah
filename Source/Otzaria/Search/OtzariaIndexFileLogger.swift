import Foundation

enum OtzariaIndexFileLogger {
    private static let queue = DispatchQueue(label: "com.goldcreative.otzaria.index.filelogger")
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    static func log(_ message: String) {
        write(message)
    }

    static func logError(_ message: String, error: Error) {
        write("\(message) errorType=\(type(of: error)) localizedDescription=\(error.localizedDescription) description=\(String(describing: error))")
    }

    static func logFileURL() -> URL? {
        guard let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return base
            .appendingPathComponent("OtzariaLogs", isDirectory: true)
            .appendingPathComponent("otzaria-index.log")
    }

    static func readLogText() -> String {
        guard let url = logFileURL(),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return ""
        }
        return text
    }

    static func clearLog() {
        queue.async {
            guard let url = logFileURL() else {
                NSLog("%@", "[OtzariaIndex] clearLog skipped: log URL unavailable")
                return
            }
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data().write(to: url, options: .atomic)
                NSLog("%@", "[OtzariaIndex] cleared persistent log at \(url.path)")
            } catch {
                NSLog("%@", "[OtzariaIndex] clearLog failed: \(error.localizedDescription)")
            }
        }
    }

    private static func write(_ message: String) {
        queue.async {
            let line = makeLine(message)
            NSLog("%@", "[OtzariaIndex] \(message)")

            guard let url = logFileURL() else { return }
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                let data = Data((line + "\n").utf8)
                if FileManager.default.fileExists(atPath: url.path) {
                    let handle = try FileHandle(forWritingTo: url)
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                } else {
                    try data.write(to: url, options: .atomic)
                }
            } catch {
                NSLog("%@", "[OtzariaIndex] persistent log write failed: \(error.localizedDescription)")
            }
        }
    }

    private static func makeLine(_ message: String) -> String {
        let timestamp = formatter.string(from: Date())
        let pid = ProcessInfo.processInfo.processIdentifier
        let thread = Thread.isMainThread ? "main" : "\(Thread.current)"
        return "\(timestamp) pid=\(pid) thread=\(thread) \(message)"
    }
}
