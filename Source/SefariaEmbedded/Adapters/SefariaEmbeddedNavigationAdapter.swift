//
//  SefariaEmbeddedNavigationAdapter.swift
//  Maktabah
//
//  Downstream-owned navigation adapter for embedded Sefaria-Mobile.
//  Conforms to LibraryNavigationProviding.
//

import Foundation

public final class SefariaEmbeddedNavigationAdapter: LibraryNavigationProviding, @unchecked Sendable {
    private let bridge: SefariaJSRPCBridge

    public init(bridge: SefariaJSRPCBridge = .shared) {
        self.bridge = bridge
    }

    public func normalizedLocator(for input: String) async throws -> TextLocator {
        let canonical = SefariaRef.canonicalInput(input)
        let workKey: String
        let knownTitles = LibraryDataManager.shared.booksById.values.map(\.book)
        if let resolved = SefariaRef.workKey(from: canonical, knownTitles: knownTitles) {
            workKey = resolved
        } else if let match = canonical.range(of: #"\s+\d+.*$"#, options: .regularExpression) {
            workKey = String(canonical[..<match.lowerBound])
        } else {
            workKey = canonical
        }
        return TextLocator(backend: .sefariaEmbedded, workKey: workKey, position: .canonicalRef(canonical))
    }

    public func tableOfContents(for work: LibraryWork) async throws -> [LibraryTOCNode] {
        let params = ["title": work.title]
        let paramsData = try? JSONEncoder().encode(params)
        let response = try await bridge.call(
            method: "navigation.textToc",
            paramsData: paramsData,
            timeoutMs: 15000
        )

        guard response.isSuccess, let resultData = response.resultData else {
            return []
        }

        return parseTOCNodes(from: resultData, workTitle: work.title)
    }

    public func navigationItems(for work: LibraryWork) async throws -> [LibraryNavigationItem] {
        let nodes = try await tableOfContents(for: work)
        var items: [LibraryNavigationItem] = []
        var nextIndex = 0

        func flatten(_ nodeList: [LibraryTOCNode]) {
            for node in nodeList {
                if let loc = node.locator {
                    items.append(LibraryNavigationItem(
                        locator: loc,
                        title: node.title,
                        index: nextIndex
                    ))
                    nextIndex += 1
                }
                if let children = node.children, !children.isEmpty {
                    flatten(children)
                }
            }
        }

        flatten(nodes)
        return items
    }

    public func navigationStructures(for work: LibraryWork) async throws -> [LibraryNavigationStructure] {
        let nodes = try await tableOfContents(for: work)
        guard !nodes.isEmpty else { return [] }
        return [
            LibraryNavigationStructure(
                id: "default",
                title: ChavrusaTextLocalizationResolver.resolveNavigationStructureTitle(for: "Chapters", prefersHebrew: true),
                nodes: nodes
            )
        ]
    }

    private func parseTOCNodes(from data: Data, workTitle: String) -> [LibraryTOCNode] {
        guard let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        if let schema = jsonObj["schema"] as? [String: Any],
           let nodes = schema["nodes"] as? [[String: Any]] {
            return parseSchemaNodes(nodes, workTitle: workTitle)
        }

        if let sectionNames = jsonObj["sectionNames"] as? [String],
           let text = jsonObj["text"] as? [Any] {
            return text.indices.map { idx -> LibraryTOCNode in
                let sectionNum = idx + 1
                let title = "\(workTitle) \(sectionNum)"
                let heTitle = "\(workTitle) \(sectionNum)"
                let loc = TextLocator(backend: .sefariaEmbedded, workKey: workTitle, position: .canonicalRef(title))
                return LibraryTOCNode(
                    id: title,
                    title: "\(sectionNames.first ?? "Section") \(sectionNum)",
                    heTitle: heTitle,
                    locator: loc,
                    children: nil
                )
            }
        }

        return []
    }

    private func parseSchemaNodes(_ nodes: [[String: Any]], workTitle: String) -> [LibraryTOCNode] {
        return nodes.compactMap { dict -> LibraryTOCNode? in
            let title = dict["title"] as? String ?? dict["en"] as? String ?? "Section"
            let heTitle = dict["heTitle"] as? String ?? dict["he"] as? String
            let fullRef = "\(workTitle), \(title)"
            let loc = TextLocator(backend: .sefariaEmbedded, workKey: workTitle, position: .canonicalRef(fullRef))

            let childNodes: [LibraryTOCNode]? = {
                if let children = dict["nodes"] as? [[String: Any]] {
                    return parseSchemaNodes(children, workTitle: workTitle)
                }
                return nil
            }()

            return LibraryTOCNode(
                id: fullRef,
                title: title,
                heTitle: heTitle,
                locator: loc,
                children: childNodes
            )
        }
    }
}
