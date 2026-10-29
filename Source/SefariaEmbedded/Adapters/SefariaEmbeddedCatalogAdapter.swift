//
//  SefariaEmbeddedCatalogAdapter.swift
//  Maktabah
//
//  Downstream-owned catalog adapter mapping Sefaria-Mobile's recursive TOC hierarchy
//  faithfully into LibraryCatalogNode without dropping nested categories or books.
//

import Foundation

actor SefariaEmbeddedCatalogAdapter: LibraryCatalogProviding, LibraryWorkMetadataProviding {
    static let shared = SefariaEmbeddedCatalogAdapter()

    private var cachedNodes: [LibraryCatalogNode]?
    private var cachedWorkMetadata: [String: LibraryWorkMetadata] = [:]

    private init() {}

    // MARK: - LibraryCatalogProviding

    func catalog(forceRefresh: Bool) async throws -> [LibraryCatalogNode] {
        if !forceRefresh, let cached = cachedNodes {
            return cached
        }
        return try await rootNodes()
    }

    func rootNodes() async throws -> [LibraryCatalogNode] {
        if let cached = cachedNodes {
            return cached
        }

        try await SefariaRuntimeManager.shared.ensureReady()
        let response = try await SefariaJSRPCBridge.shared.call(method: "catalog.toc")
        guard response.isSuccess,
              let resultJson = response.resultJson,
              let data = resultJson.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw response.error ?? LibraryBackendError.corruptData("Failed to parse Sefaria TOC JSON")
        }

        let nodes = parseCatalogItems(jsonArray, parentPath: "")
        self.cachedNodes = nodes
        return nodes
    }

    func children(of parentID: String) async throws -> [LibraryCatalogNode] {
        let roots = try await rootNodes()
        return findChildren(in: roots, parentID: parentID) ?? []
    }

    private func findChildren(in nodes: [LibraryCatalogNode], parentID: String) -> [LibraryCatalogNode]? {
        for node in nodes {
            if node.id == parentID {
                return node.children
            }
            if !node.children.isEmpty, let found = findChildren(in: node.children, parentID: parentID) {
                return found
            }
        }
        return nil
    }

    private func parseCatalogItems(_ items: [[String: Any]], parentPath: String) -> [LibraryCatalogNode] {
        var result: [LibraryCatalogNode] = []

        for item in items {
            if let categoryName = item["category"] as? String {
                let heCategory = item["heCategory"] as? String
                let currentPath = parentPath.isEmpty ? categoryName : "\(parentPath)/\(categoryName)"
                let contents = (item["contents"] as? [[String: Any]]) ?? []
                let children = parseCatalogItems(contents, parentPath: currentPath)

                result.append(LibraryCatalogNode(
                    id: currentPath,
                    kind: .category,
                    title: categoryName,
                    heTitle: heCategory,
                    work: nil,
                    children: children
                ))
            } else if let bookTitle = item["title"] as? String {
                let heTitle = item["heTitle"] as? String
                let workLocator = TextLocator(
                    backend: .sefariaEmbedded,
                    workKey: bookTitle,
                    position: .canonicalRef(bookTitle)
                )
                let work = LibraryWork(
                    locator: workLocator,
                    title: bookTitle,
                    heTitle: heTitle,
                    categories: (item["categories"] as? [String]) ?? [],
                    description: item["enShortDesc"] as? String
                )
                result.append(LibraryCatalogNode(
                    id: bookTitle,
                    kind: .work,
                    title: bookTitle,
                    heTitle: heTitle,
                    work: work,
                    children: []
                ))

                // Cache metadata
                cachedWorkMetadata[bookTitle] = LibraryWorkMetadata(
                    workKey: bookTitle,
                    title: bookTitle,
                    heTitle: heTitle,
                    authors: [],
                    description: item["enShortDesc"] as? String,
                    categories: (item["categories"] as? [String]) ?? []
                )
            }
        }

        return result
    }

    // MARK: - LibraryWorkMetadataProviding

    func workMetadata(for workKey: String) async throws -> LibraryWorkMetadata? {
        return try await metadata(for: workKey)
    }

    func metadata(for workKey: String) async throws -> LibraryWorkMetadata {
        if let cached = cachedWorkMetadata[workKey] {
            return cached
        }

        try await SefariaRuntimeManager.shared.ensureReady()
        let params = ["title": workKey]
        let paramsData = try JSONSerialization.data(withJSONObject: params)
        let paramsJson = String(data: paramsData, encoding: .utf8)

        let response = try await SefariaJSRPCBridge.shared.call(
            method: "catalog.bookMetadata",
            paramsJson: paramsJson
        )

        guard response.isSuccess,
              let resultJson = response.resultJson,
              let data = resultJson.data(using: .utf8),
              let item = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return LibraryWorkMetadata(workKey: workKey, title: workKey, heTitle: nil, authors: [], description: nil, categories: [])
        }

        let meta = LibraryWorkMetadata(
            workKey: workKey,
            title: (item["title"] as? String) ?? workKey,
            heTitle: item["heTitle"] as? String,
            authors: (item["authors"] as? [String]) ?? [],
            description: item["enShortDesc"] as? String,
            categories: (item["categories"] as? [String]) ?? []
        )
        cachedWorkMetadata[workKey] = meta
        return meta
    }
}
