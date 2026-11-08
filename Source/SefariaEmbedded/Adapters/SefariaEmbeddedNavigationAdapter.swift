import Foundation

/// Maps original Sefaria index records without deriving canonical references from translated labels.
final class SefariaEmbeddedNavigationAdapter: LibraryNavigationProviding, Sendable {
    static let shared = SefariaEmbeddedNavigationAdapter()
    private init() {}

    func normalizedLocator(for input: String) async throws -> TextLocator {
        try await SefariaRuntimeManager.shared.ensureReady()
        let ref = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let response = try await SefariaJSRPCBridge.shared.call(
            method: "navigation.normalize", paramsJson: Self.json(["ref": ref]))
        let result = try Self.object(response)
        guard let canonical = result["ref"] as? String, let title = result["title"] as? String else {
            throw LibraryBackendError.invalidLocator
        }
        return TextLocator(backend: .sefariaEmbedded, workKey: title, position: .canonicalRef(canonical))
    }

    func tableOfContents(for work: LibraryWork) async throws -> [LibraryTOCNode] {
        try await tableOfContents(for: work.locator.workKey, structureID: nil)
    }

    func navigationItems(for work: LibraryWork) async throws -> [LibraryNavigationItem] {
        try await navigationItems(for: work.locator.workKey, structureID: nil)
    }

    func navigationStructures(for work: LibraryWork) async throws -> [LibraryNavigationStructure] {
        try await navigationStructures(for: work.locator.workKey)
    }

    func navigationStructures(for workKey: String) async throws -> [LibraryNavigationStructure] {
        let record = try await index(for: workKey)
        return try Self.structures(record, workKey: workKey, hebrew: LibraryPresentationPolicy.prefersHebrew())
    }

    func tableOfContents(for workKey: String, structureID: String?) async throws -> [LibraryTOCNode] {
        let structures = try await navigationStructures(for: workKey)
        guard let structure = structures.first(where: { $0.id == (structureID ?? "default") }) else {
            throw LibraryBackendError.invalidLocator
        }
        return structure.nodes
    }

    func navigationItems(for workKey: String, structureID: String?) async throws -> [LibraryNavigationItem] {
        let toc = try await tableOfContents(for: workKey, structureID: structureID)
        var items: [LibraryNavigationItem] = []
        func visit(_ nodes: [LibraryTOCNode]) {
            for node in nodes {
                if node.children.isEmpty {
                    items.append(.init(locator: node.locator, title: node.title, index: items.count))
                } else { visit(node.children) }
            }
        }
        visit(toc)
        return items
    }

    private func index(for workKey: String) async throws -> [String: Any] {
        try await SefariaRuntimeManager.shared.ensureReady()
        let response = try await SefariaJSRPCBridge.shared.call(
            method: "navigation.textToc", paramsJson: Self.json(["title": workKey]))
        return try Self.object(response)
    }

    private static func json(_ params: [String: String]) throws -> String? {
        String(data: try JSONSerialization.data(withJSONObject: params), encoding: .utf8)
    }

    private static func object(_ response: SefariaRPCResponse) throws -> [String: Any] {
        guard response.isSuccess else {
            throw response.error ?? LibraryBackendError.invalidResponse("Sefaria navigation failed")
        }
        guard let text = response.resultJson, let data = text.data(using: .utf8),
              let record = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LibraryBackendError.invalidResponse("Sefaria navigation returned invalid data")
        }
        return record
    }

    static func title(_ node: [String: Any], hebrew: Bool) -> String? {
        let keys = hebrew ? ["heTitle", "he"] : ["title", "en"]
        for key in keys {
            if let text = node[key] as? String, !text.isEmpty { return text }
        }
        if let titles = node["titles"] as? [[String: Any]],
           let primary = titles.first(where: { ($0["lang"] as? String) == (hebrew ? "he" : "en") && ($0["primary"] as? Bool) == true }),
           let text = primary["text"] as? String { return text }
        return nil
    }

    static func structures(_ record: [String: Any], workKey: String, hebrew: Bool) throws -> [LibraryNavigationStructure] {
        guard let schema = record["schema"] as? [String: Any] else {
            throw LibraryBackendError.invalidResponse("Sefaria index is missing its schema")
        }
        let workTitle = title(record, hebrew: hebrew) ?? title(schema, hebrew: hebrew) ?? workKey
        var result = [LibraryNavigationStructure(id: "default", title: hebrew ? "סדר רגיל" : "Default",
            nodes: parse(schema, workKey: workKey, parentRef: workKey, parentTitle: workTitle, hebrew: hebrew))]
        let alts = (record["alts"] as? [String: Any]) ?? (record["alt_structs"] as? [String: Any]) ?? [:]
        for key in alts.keys.sorted() {
            guard let alt = alts[key] as? [String: Any] else { continue }
            let name = title(alt, hebrew: hebrew)
                ?? ChavrusaTextLocalizationResolver.resolveNavigationStructureTitle(for: key, prefersHebrew: hebrew)
            result.append(.init(id: key, title: name,
                nodes: parse(alt, workKey: workKey, parentRef: workKey, parentTitle: workTitle, hebrew: hebrew)))
        }
        return result
    }

    private static func parse(_ schema: [String: Any], workKey: String, parentRef: String,
                              parentTitle: String, hebrew: Bool) -> [LibraryTOCNode] {
        func locator(_ ref: String) -> TextLocator {
            .init(backend: .sefariaEmbedded, workKey: workKey, position: .canonicalRef(ref))
        }
        if let nodes = schema["nodes"] as? [[String: Any]] {
            return nodes.flatMap { node -> [LibraryTOCNode] in
                let canonicalTitle = title(node, hebrew: false)
                let isDefault = node["default"] as? Bool == true
                guard isDefault || canonicalTitle != nil || node["wholeRef"] is String else { return [] }
                let ref = (node["wholeRef"] as? String) ?? (node["ref"] as? String)
                    ?? (isDefault ? parentRef : "\(parentRef), \(canonicalTitle!)")
                let label = title(node, hebrew: hebrew) ?? canonicalTitle ?? parentTitle
                let children = parse(node, workKey: workKey, parentRef: ref, parentTitle: label, hebrew: hebrew)
                if isDefault { return children }
                return [.init(locator: locator(ref), title: label, children: children)]
            }
        }
        if let refs = schema["refs"] as? [String] {
            // ArrayMapNode refs/wholeRef are authoritative, including ranges and alternate structures.
            let originalLabel = (schema["sectionNames"] as? [String])?.first ?? "Section"
            let label = hebrew ? ((schema["heSectionNames"] as? [String])?.first
                ?? ChavrusaTextLocalizationResolver.resolveNavigationStructureTitle(for: originalLabel, prefersHebrew: true))
                : originalLabel
            return refs.enumerated().filter { !$0.element.isEmpty }.map { index, ref in
                .init(locator: locator(ref), title: "\(label) \(hebrew ? TalmudHebrewAddressFormatter.hebrewDafNumeral(from: index + 1) : String(index + 1))", children: [])
            }
        }
        guard let sectionName = (schema["sectionNames"] as? [String])?.first,
              let count = (schema["lengths"] as? [Int])?.first, count > 0 else { return [] }
        let isTalmud = (schema["addressTypes"] as? [String])?.first == "Talmud"
        let start = isTalmud ? 3 : 1 // Sefaria's one-based Talmud address: 3 == 2a.
        guard count >= start else { return [] }
        let sectionTitle = hebrew
            ? ((schema["heSectionNames"] as? [String])?.first
                ?? ChavrusaTextLocalizationResolver.resolveNavigationStructureTitle(for: sectionName, prefersHebrew: true))
            : sectionName
        return (start...count).map { number in
            let address = isTalmud ? "\((number + 1) / 2)\(number.isMultiple(of: 2) ? "b" : "a")" : String(number)
            let displayAddress = hebrew
                ? (isTalmud ? TalmudHebrewAddressFormatter.format(address: address)
                    : TalmudHebrewAddressFormatter.hebrewDafNumeral(from: number)) : address
            return .init(locator: locator("\(parentRef) \(address)"),
                title: "\(sectionTitle) \(displayAddress)", children: [])
        }
    }
}
