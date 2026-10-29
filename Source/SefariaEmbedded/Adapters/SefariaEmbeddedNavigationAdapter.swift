//
//  SefariaEmbeddedNavigationAdapter.swift
//  Maktabah
//
//  Downstream-owned navigation adapter providing structural TOC, Talmud amudim,
//  and alternate structures directly from Sefaria-Mobile's textToc.
//

import Foundation

final class SefariaEmbeddedNavigationAdapter: LibraryNavigationProviding, Sendable {
    static let shared = SefariaEmbeddedNavigationAdapter()

    private init() {}

    // MARK: - LibraryNavigationProviding

    func normalizedLocator(for input: String) async throws -> TextLocator {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return TextLocator(backend: .sefariaEmbedded, workKey: trimmed, position: .canonicalRef(trimmed))
    }

    func tableOfContents(for work: LibraryWork) async throws -> [LibraryTOCNode] {
        return try await tableOfContents(for: work.locator.workKey, structureID: nil)
    }

    func navigationItems(for work: LibraryWork) async throws -> [LibraryNavigationItem] {
        return try await navigationItems(for: work.locator.workKey, structureID: nil)
    }

    func navigationStructures(for work: LibraryWork) async throws -> [LibraryNavigationStructure] {
        return try await navigationStructures(for: work.locator.workKey)
    }

    func navigationStructures(for workKey: String) async throws -> [LibraryNavigationStructure] {
        try await SefariaRuntimeManager.shared.ensureReady()
        let params = ["title": workKey]
        let paramsData = try JSONSerialization.data(withJSONObject: params)
        let paramsJson = String(data: paramsData, encoding: .utf8)

        let response = try await SefariaJSRPCBridge.shared.call(
            method: "navigation.textToc",
            paramsJson: paramsJson
        )

        let defaultTOC = try await tableOfContents(for: workKey, structureID: nil)

        guard response.isSuccess,
              let resultJson = response.resultJson,
              let data = resultJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [LibraryNavigationStructure(id: "default", title: "תוכן עניינים", nodes: defaultTOC)]
        }

        var structures: [LibraryNavigationStructure] = [
            LibraryNavigationStructure(id: "default", title: "סדר רגיל", nodes: defaultTOC)
        ]

        if let alts = json["alts"] as? [String: Any] {
            for (altKey, altVal) in alts {
                if let altDict = altVal as? [String: Any] {
                    let title = (altDict["en"] as? String) ?? altKey
                    let altNodes = try await tableOfContents(for: workKey, structureID: altKey)
                    structures.append(LibraryNavigationStructure(
                        id: altKey,
                        title: title,
                        nodes: altNodes
                    ))
                }
            }
        }

        return structures
    }

    func tableOfContents(for workKey: String, structureID: String?) async throws -> [LibraryTOCNode] {
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
                let ref = "\(parentRef), \(title)"
                let children = parseSchemaNodes(nodeDict, workKey: workKey, parentRef: ref)

                let locator = TextLocator(
                    backend: .sefariaEmbedded,
                    workKey: workKey,
                    position: .canonicalRef(ref)
                )

                return LibraryTOCNode(
                    locator: locator,
                    title: title,
                    children: children
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
                    locator: locator,
                    title: "\(sectionNames[0]) \(chapterNum)",
                    children: []
                )
            }
        }

        return []
    }

    func navigationItems(for workKey: String, structureID: String?) async throws -> [LibraryNavigationItem] {
        let toc = try await tableOfContents(for: workKey, structureID: structureID)
        return toc.enumerated().map { idx, node in
            LibraryNavigationItem(
                locator: node.locator,
                title: node.title,
                index: idx
            )
        }
    }
}
