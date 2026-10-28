//
//  SefariaEmbeddedCatalogAdapter.swift
//  Maktabah
//
//  Downstream-owned catalog adapter for embedded Sefaria-Mobile.
//  Conforms to LibraryCatalogProviding and LibraryWorkMetadataProviding.
//

import Foundation

public final class SefariaEmbeddedCatalogAdapter: LibraryCatalogProviding, LibraryWorkMetadataProviding, @unchecked Sendable {
    private var cachedNodes: [LibraryCatalogNode]?
    private let bridge: SefariaJSRPCBridge

    public init(bridge: SefariaJSRPCBridge = .shared) {
        self.bridge = bridge
    }

    public func catalog(forceRefresh: Bool) async throws -> [LibraryCatalogNode] {
        if !forceRefresh, let cached = cachedNodes {
            return cached
        }

        let response = try await bridge.call(method: "catalog.root", paramsData: nil)
        guard response.isSuccess, let resultData = response.resultData else {
            throw SefariaRPCError(
                code: "CATALOG_FETCH_FAILED",
                message: response.error?.message ?? "Failed to fetch Sefaria root catalog"
            )
        }

        let nodes = try parseCatalogNodes(from: resultData)
        self.cachedNodes = nodes
        return nodes
    }

    public func workMetadata(for workKey: String) async throws -> LibraryWorkMetadata? {
        let params = ["title": workKey]
        let paramsData = try? JSONEncoder().encode(params)
        let response = try await bridge.call(method: "catalog.bookMetadata", paramsData: paramsData)
        guard response.isSuccess, let resultData = response.resultData else {
            return nil
        }

        return try? JSONDecoder().decode(LibraryWorkMetadata.self, from: resultData)
    }

    private func parseCatalogNodes(from data: Data) throws -> [LibraryCatalogNode] {
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return jsonArray.compactMap { dict -> LibraryCatalogNode? in
            guard let category = dict["category"] as? String else {
                if let title = dict["title"] as? String {
                    let heTitle = dict["heTitle"] as? String
                    let work = LibraryWork(
                        locator: TextLocator(backend: .sefariaEmbedded, workKey: title, position: .canonicalRef(title)),
                        title: title,
                        heTitle: heTitle,
                        categories: dict["categories"] as? [String] ?? [],
                        description: dict["description"] as? String
                    )
                    return .book(work)
                }
                return nil
            }

            let heCategory = dict["heCategory"] as? String
            return .category(LibraryCategory(
                id: category,
                title: category,
                heTitle: heCategory,
                parentID: nil
            ))
        }
    }

    public func clearCache() {
        cachedNodes = nil
    }
}
