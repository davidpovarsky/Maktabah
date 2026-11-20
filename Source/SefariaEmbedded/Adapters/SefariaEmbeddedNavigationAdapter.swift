//
//  SefariaEmbeddedNavigationAdapter.swift
//  Maktabah
//
//  Downstream-owned navigation adapter over the original Sefaria-Mobile textToc.
//  Display and canonical navigation are decoded by the shared Sefaria parser.
//

import Foundation

final class SefariaEmbeddedNavigationAdapter: LibraryNavigationProviding, Sendable {
    static let shared = SefariaEmbeddedNavigationAdapter()

    private init() {}

    func normalizedLocator(for input: String) async throws -> TextLocator {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return TextLocator(backend: .sefariaEmbedded, workKey: trimmed, position: .canonicalRef(trimmed))
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
        guard !workKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LibraryBackendError.invalidLocator
        }
        try Task.checkCancellation()
        try await SefariaRuntimeManager.shared.ensureReady()
        let bridge = SefariaJSRPCBridge.shared
        let epoch = await bridge.sessionEpoch
        guard await bridge.resourcesAreStable else { throw LibraryBackendError.staleRequest }
        let params = String(decoding: try JSONEncoder().encode(["title": workKey]), as: UTF8.self)
        let response = try await bridge.call(method: "navigation.textToc",
            paramsJson: params, generation: epoch)
        try Task.checkCancellation()
        let structures = try Self.decodeStructures(response, workKey: workKey)
        guard await bridge.sessionEpoch == epoch, await bridge.resourcesAreStable else {
            throw LibraryBackendError.staleRequest
        }
        try Task.checkCancellation()
        return structures
    }

    func tableOfContents(for workKey: String, structureID: String?) async throws -> [LibraryTOCNode] {
        let structures = try await navigationStructures(for: workKey)
        let id = structureID ?? "default"
        guard let structure = structures.first(where: { $0.id == id }) else {
            throw LibraryBackendError.invalidLocator
        }
        return structure.nodes
    }

    func navigationItems(for workKey: String, structureID: String?) async throws -> [LibraryNavigationItem] {
        let nodes = try await tableOfContents(for: workKey, structureID: structureID)
        var items: [LibraryNavigationItem] = []
        func collect(_ nodes: [LibraryTOCNode]) {
            for node in nodes {
                if node.children.isEmpty {
                    items.append(LibraryNavigationItem(locator: node.locator,
                        title: node.title, index: items.count))
                } else { collect(node.children) }
            }
        }
        collect(nodes)
        return items
    }

    static func decodeStructures(
        _ response: SefariaRPCResponse, workKey: String,
        prefersHebrew: Bool = LibraryPresentationPolicy.prefersHebrew()
    ) throws -> [LibraryNavigationStructure] {
        guard response.isSuccess else {
            throw response.error ?? LibraryBackendError.invalidResponse("Mobile TOC request failed")
        }
        guard let json = response.resultJson, json.utf8.count <= 16_777_216 else {
            throw LibraryBackendError.invalidResponse("Mobile TOC payload is absent or oversized")
        }
        let index: SefariaOfflineIndexDTO
        do { index = try JSONDecoder().decode(SefariaOfflineIndexDTO.self, from: Data(json.utf8)) }
        catch { throw LibraryBackendError.invalidResponse("Mobile TOC payload is malformed") }
        guard index.title.utf8.elementsEqual(workKey.utf8) else {
            throw LibraryBackendError.invalidResponse("Mobile TOC belongs to a different work")
        }
        let parsed = try SefariaNavigationParser.mobileIndexStructures(
            schema: index.schema, alternateStructures: index.alternateStructures,
            indexTitle: workKey, prefersHebrew: prefersHebrew)
        func remap(_ node: LibraryTOCNode) throws -> LibraryTOCNode {
            guard case .canonicalRef(let ref) = node.locator.position,
                  ref == workKey || ref.hasPrefix(workKey + " ") || ref.hasPrefix(workKey + ", ") else {
                throw LibraryBackendError.invalidResponse("Mobile TOC has a foreign canonical reference")
            }
            return LibraryTOCNode(
                locator: TextLocator(backend: .sefariaEmbedded, workKey: workKey,
                    position: node.locator.position),
                title: node.title, children: try node.children.map(remap))
        }
        return try parsed.map {
            LibraryNavigationStructure(id: $0.id == "primary" ? "default" : $0.id,
                title: $0.title, nodes: try $0.nodes.map(remap))
        }
    }
}
