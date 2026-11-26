
import Foundation
import CryptoKit

actor SefariaHTTPClient {
    let root: URL
    var blocked = false
    var calls: [String] = []
    var responseOverride: String?
    var duplicateMetadata = false
    var missingFamily = false
    init(root: URL) { self.root = root }
    func block() { blocked = true }
    func configure(response: String? = nil, duplicate: Bool = false, familyMissing: Bool = false) {
        responseOverride = response; duplicateMetadata = duplicate; missingFamily = familyMissing
    }
    func count() -> Int { calls.count }
    func get<T: Decodable & Sendable>(_ type: T.Type, url: URL) async throws -> T {
        guard !blocked else { throw URLError(.notConnectedToInternet) }
        calls.append(url.absoluteString)
        var name: String
        if url.path.hasPrefix("/api/texts/versions/") { name = "psalms-versions.json" }
        else {
            let selectors = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                .filter { $0.name == "version" }.compactMap(\.value) ?? []
            if let exact = selectors.first(where: { $0.contains("|") }) {
                switch exact {
                case "hebrew|Tanach with Text Only": name = "psalms131-text-only.json"
                case "hebrew|Tanach with Nikkud": name = "psalms131-nikkud.json"
                case "english|The Holy Scriptures: A New Translation (JPS 1917)": name = "psalms131-jps1917.json"
                case "french|Bible du Rabbinat 1899 [fr]": name = "psalms131-french.json"
                default: throw LibraryBackendError.invalidResponse("Unexpected exact selector: " + exact)
                }
                if let responseOverride { name = responseOverride }
            } else { name = "psalms131-default.json" }
        }
        var data = try Data(contentsOf: root.appendingPathComponent(name))
        if name == "psalms-versions.json", duplicateMetadata || missingFamily {
            var rows = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
            if duplicateMetadata { rows += rows.filter { $0["versionTitle"] as? String == "Tanach with Text Only" } }
            if missingFamily { rows = rows.map { var row = $0; row.removeValue(forKey: "languageFamilyName"); return row } }
            data = try JSONSerialization.data(withJSONObject: rows)
        }
        return try JSONDecoder().decode(type, from: data)
    }
}

