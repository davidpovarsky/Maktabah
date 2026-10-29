//
//  SefariaEmbeddedCatalogAdapter.swift
//  Maktabah
//
//  Downstream-owned catalog adapter mapping Sefaria-Mobile's recursive TOC hierarchy
//  faithfully into LibraryCatalogNode without dropping nested categories or books.
//

import Foundation

public actor SefariaEmbeddedCatalogAdapter: LibraryCatalogProviding, LibraryWorkMetadataProviding {
    public static let shared = SefariaEmbeddedCatalogAdapter()

    private var cachedNodes: [LibraryCatalogNode]?
    private var cachedWorkMetadata: [String: LibraryWorkMetadata] = [:]

    private init() {}

    public func rootNodes() async throws -> [LibraryCatalogNode] {
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

    public func children(of parentID: String) async throws -> [LibraryCatalogNode] {
        let roots = try await rootNodes()
        return findChildren(in: roots, parentID: parentID) ?? []
    }

    private func findChildren(in nodes: [LibraryCatalogNode], parentID: String) -> [LibraryCatalogNode]? {
        for node in nodes {
            if node.id == parentID {
                return node.children
            }
            if let children = node.children, let found = findChildren(in: children, parentID: parentID) {
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

                result.append(.category(
                    id: currentPath,
                    title: categoryName,
                    heTitle: heCategory,
                    children: children
                ))
            } else if let bookTitle = item["title"] as? String {
                let heTitle = item["heTitle"] as? String
                result.append(.book(
                    id: bookTitle,
                    title: bookTitle,
                    heTitle: heTitle,
                    workKey: bookTitle
                ))

                // Cache metadata
                cachedWorkMetadata[bookTitle] = LibraryWorkMetadata(
                    workKey: bookTitle,
                    title: bookTitle,
                    heTitle: heTitle,
                    authors: [],
                    categories: (item["categories"] as? [String]) ?? [],
                    order: item["order"] as? Int,
                    description: item["enShortDesc"] as? String,
                    heDescription: item["heShortDesc"] as? String
                )
            }
        }

        return result
    }

    // MARK: - LibraryWorkMetadataProviding

    public func metadata(for workKey: String) async throws -> LibraryWorkMetadata {
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
            return LibraryWorkMetadata(workKey: workKey, title: workKey, heTitle: nil, authors: [], categories: [])
        }

        let meta = LibraryWorkMetadata(
            workKey: workKey,
            title: (item["title"] as? String) ?? workKey,
            heTitle: item["heTitle"] as? String,
            authors: (item["authors"] as? [String]) ?? [],
            categories: (item["categories"] as? [String]) ?? [],
            order: item["order"] as? Int,
            description: item["enShortDesc"] as? String,
            heDescription: item["heShortDesc"] as? String
        )
        cachedWorkMetadata[workKey] = meta
        return meta
    }
}
