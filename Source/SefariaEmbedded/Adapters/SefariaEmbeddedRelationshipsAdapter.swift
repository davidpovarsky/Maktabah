import Foundation

/// Original Sefaria related responses are either offline arrays or online envelopes.
/// A valid empty array is data; RPC/shape/mapping failures remain errors for the inspector's retry UI.
final class SefariaEmbeddedRelationshipsAdapter: LibraryRelationshipsProviding, Sendable {
    static let shared = SefariaEmbeddedRelationshipsAdapter()
    private init() {}

    func links(for locator: TextLocator) async throws -> [LibraryRelatedSource] {
        try Self.parseLinks(await payload(for: locator))
    }

    func topics(for locator: TextLocator) async throws -> [LibraryRelatedTopic] {
        try Self.parseTopics(await payload(for: locator))
    }

    private func payload(for locator: TextLocator) async throws -> Data {
        guard locator.backend == .sefariaEmbedded, case .canonicalRef(let ref) = locator.position else {
            throw LibraryBackendError.invalidLocator
        }
        try await SefariaRuntimeManager.shared.ensureReady()
        let params = try JSONSerialization.data(withJSONObject: ["ref": ref, "online": true])
        let response = try await SefariaJSRPCBridge.shared.call(
            method: "relationships.links", paramsJson: String(data: params, encoding: .utf8))
        guard response.isSuccess else {
            throw response.error ?? LibraryBackendError.invalidResponse("Sefaria related request failed. Try again.")
        }
        guard let json = response.resultJson, let data = json.data(using: .utf8) else {
            throw LibraryBackendError.invalidResponse("Sefaria related response has no payload. Try again.")
        }
        return data
    }

    private static func linkRows(_ value: Any) throws -> [[String: Any]] {
        if let array = value as? [Any] {
            return try array.flatMap { element -> [[String: Any]] in
                if element is [Any] { return try linkRows(element) }
                guard let row = element as? [String: Any] else {
                    throw LibraryBackendError.invalidResponse("Sefaria related link is not an object")
                }
                return [row]
            }
        }
        if let object = value as? [String: Any] {
            if let links = object["links"] { return try linkRows(links) }
            // Grouped offline links are keyed by canonical ref/category, with array values.
            guard !object.isEmpty, object.values.allSatisfy({ $0 is [Any] }) else {
                throw LibraryBackendError.invalidResponse("Unrecognized Sefaria related response")
            }
            return try object.keys.sorted().flatMap { try linkRows(object[$0]!) }
        }
        throw LibraryBackendError.invalidResponse("Unrecognized Sefaria related links format")
    }

    private static func text(_ value: Any?) -> String? {
        if let string = value as? String { return string.isEmpty ? nil : string }
        if let array = value as? [Any] {
            let strings = array.compactMap { text($0) }
            return strings.isEmpty ? nil : strings.joined(separator: "\n")
        }
        return nil
    }

    static func parseLinks(_ data: Data) throws -> [LibraryRelatedSource] {
        let rows = try linkRows(JSONSerialization.jsonObject(with: data))
        return try rows.map { row in
            guard let ref = text(row["sourceRef"]) ?? text(row["ref"]) else {
                throw LibraryBackendError.invalidResponse("Sefaria link is missing its source reference")
            }
            let collective = row["collectiveTitle"] as? [String: Any]
            let displayed = row["displayedText"] as? [String: Any]
            let workKey = text(row["workKey"]) ?? text(row["index_title"])
            guard let workKey else {
                throw LibraryBackendError.invalidResponse("Sefaria link '\(ref)' is missing its canonical book identity")
            }
            var anchors = row["anchorRefExpanded"] as? [String] ?? []
            if anchors.isEmpty, let anchor = text(row["anchorRef"]) { anchors = [anchor] }
            return LibraryRelatedSource(
                locator: .init(backend: .sefariaEmbedded, workKey: workKey, position: .canonicalRef(ref)),
                displayRef: ref, heRef: text(row["sourceHeRef"]) ?? text(row["heRef"]),
                category: text(row["category"]) ?? "Other", type: text(row["type"]) ?? "reference",
                collectiveTitle: text(collective?["en"]) ?? text(row["collectiveTitle"]),
                heCollectiveTitle: text(collective?["he"]) ?? text(row["heCollectiveTitle"]),
                primaryText: text(row["he"]) ?? text(displayed?["he"]),
                translation: text(row["text"]) ?? text(displayed?["en"]),
                versionTitle: text(row["versionTitle"]), heVersionTitle: text(row["heVersionTitle"]),
                license: text(row["license"]), anchorRefs: anchors)
        }
    }

    static func parseTopics(_ data: Data) throws -> [LibraryRelatedTopic] {
        let payload = try JSONSerialization.jsonObject(with: data)
        if payload is [Any] { return [] } // Offline link arrays contain no topic metadata.
        guard let object = payload as? [String: Any] else {
            throw LibraryBackendError.invalidResponse("Unrecognized Sefaria topics response")
        }
        guard let value = object["topics"] else {
            _ = try linkRows(object) // Validate instead of disguising an unknown response as empty.
            return []
        }
        guard let rows = value as? [[String: Any]] else {
            throw LibraryBackendError.invalidResponse("Sefaria topics is not an array")
        }
        return try rows.map { row in
            guard let slug = text(row["topic"]) ?? text(row["slug"]) else {
                throw LibraryBackendError.invalidResponse("Sefaria topic is missing its identity")
            }
            let title = row["title"] as? [String: Any]
            return .init(slug: slug, titleHe: text(title?["he"]) ?? text(row["he"]),
                         titleEn: text(title?["en"]) ?? text(row["title"]) ?? text(row["en"]))
        }
    }
}
