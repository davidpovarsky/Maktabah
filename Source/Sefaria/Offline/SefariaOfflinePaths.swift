import Foundation

struct SefariaOfflinePaths: Sendable {
    let root: URL
    var schemaRoot: URL { root.appendingPathComponent("schema-\(SefariaExportContract.currentSchema)", isDirectory: true) }
    var packages: URL { schemaRoot.appendingPathComponent("packages", isDirectory: true) }
    var expandedBooks: URL { schemaRoot.appendingPathComponent("expanded", isDirectory: true) }
    var staging: URL { root.appendingPathComponent("staging", isDirectory: true) }
    var state: URL { root.appendingPathComponent("installed-state.json") }
    var manifestCache: URL { root.appendingPathComponent("packages.json") }

    init(root: URL? = nil) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.root = root ?? support.appendingPathComponent("Maktabah/SefariaOffline", isDirectory: true)
    }

    static func safeComponent(_ value: String) -> String {
        Data(value.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
    }
}
