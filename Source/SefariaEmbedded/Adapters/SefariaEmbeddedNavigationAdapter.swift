//
//  SefariaEmbeddedNavigationAdapter.swift
//  Maktabah
//
//  Downstream-owned navigation adapter providing structural TOC, Talmud amudim,
//  and alternate structures directly from Sefaria-Mobile's textToc.
//

import Foundation

public final class SefariaEmbeddedNavigationAdapter: LibraryNavigationProviding, Sendable {
    public static let shared = SefariaEmbeddedNavigationAdapter()

    private init() {}

    public func navigationStructures(for workKey: String) async throws -> [LibraryNavigationStructure] {
        try await SefariaRuntimeManager.shared.ensureReady()
        let params = ["title": workKey]
        let paramsData = try JSONSerialization.data(withJSONObject: params)
        let paramsJson = String(data: paramsData, encoding: .utf8)

        let response = try await SefariaJSRPCBridge.shared.call(
            method: "navigation.textToc",
            paramsJson: paramsJson
        )

        guard response.isSuccess,
              let resultJson = response.resultJson,
              let data = resultJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [LibraryNavigationStructure(id: "default", title: "תוכן עניינים", isDefault: true)]
        }

        var structures: [LibraryNavigationStructure] = [
            LibraryNavigationStructure(id: "default", title: "סדר רגיל", isDefault: true)
        ]

        if let alts = json["alts"] as? [String: Any] {
            for (altKey, altVal) in alts {
                if let altDict = altVal as? [String: Any] {
                    let title = (altDict["en"] as? String) ?? altKey
                    structures.append(LibraryNavigationStructure(
                        id: altKey,
                        title: title,
                        isDefault: false
                    ))
                }
            }
        }

        return structures
    }

    public func tableOfContents(for workKey: String, structureID: String?) async throws -> [LibraryTOCNode] {
        try await SefariaRuntimeManager.shared.ensureReady()
        let params = ["title": workKey]
        let paramsData = try JSONSerialization.data(withJSONObject: params)
        let paramsJson = String(data: paramsData, encoding: .utf8)

        let response = try await SefariaJSRPCBridge.shared.call(
            method: "navigation.textToc",
            paramsJson: paramsJson
        )

        guard response.isSuccess,
              let resultJson = response.resultJson,
              let data = resultJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        if let schema = json["schema"] as? [String: Any] {
            return parseSchemaNodes(schema, workKey: workKey, parentRef: workKey)
        }

        return []
    }

    private func parseSchemaNodes(_ schema: [String: Any], workKey: String, parentRef: String) -> [LibraryTOCNode] {
        if let nodes = schema["nodes"] as? [[String: Any]] {
            return nodes.enumerated().compactMap { idx, nodeDict in
                let title = (nodeDict["en"] as? String) ?? (nodeDict["title"] as? String) ?? "Section \(idx + 1)"
                let heTitle = (nodeDict["he"] as? String) ?? (nodeDict["heTitle"] as? String)
                let ref = "\(parentRef), \(title)"
                let children = parseSchemaNodes(nodeDict, workKey: workKey, parentRef: ref)

                let locator = TextLocator(
                    backend: .sefariaEmbedded,
                    workKey: workKey,
                    position: .canonicalRef(ref)
                )

                return LibraryTOCNode(
                    id: ref,
                    title: title,
                    heTitle: heTitle,
                    locator: locator,
                    children: children.isEmpty ? nil : children
                )
            }
        }

        // Jagged array node with sectionNames: e.g. ["Chapter", "Verse"]
        if let sectionNames = schema["sectionNames"] as? [String], !sectionNames.isEmpty {
            // Flat chapter list
            let count = (schema["lengths"] as? [Int])?.first ?? 50
            return (1...count).map { chapterNum in
                let ref = "\(workKey) \(chapterNum)"
                let locator = TextLocator(
                    backend: .sefariaEmbedded,
                    workKey: workKey,
                    position: .canonicalRef(ref)
                )
                return LibraryTOCNode(
                    id: ref,
                    title: "\(sectionNames[0]) \(chapterNum)",
                    heTitle: "\(chapterNum)",
                    locator: locator,
                    children: nil
                )
            }
        }

        return []
    }

    public func navigationItems(for workKey: String, structureID: String?) async throws -> [LibraryNavigationItem] {
        let toc = try await tableOfContents(for: workKey, structureID: structureID)
        return toc.map { node in
            LibraryNavigationItem(
                id: node.id,
                title: node.title,
                heTitle: node.heTitle,
                locator: node.locator
            )
        }
    }
}
