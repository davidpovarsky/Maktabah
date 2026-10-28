//
//  SefariaEmbeddedSearchAdapter.swift
//  Maktabah
//
//  Downstream-owned search adapter delegating to original Sefaria @sefaria/search engine.
//  Conforms to LibrarySearchProviding.
//

import Foundation

public final class SefariaEmbeddedSearchAdapter: LibrarySearchProviding, @unchecked Sendable {
    private let bridge: SefariaJSRPCBridge

    public init(bridge: SefariaJSRPCBridge = .shared) {
        self.bridge = bridge
    }

    public func search(_ request: LibrarySearchRequest) async throws -> LibrarySearchPage {
        let pageSize = max(1, min(request.pageSize, 100))
        let offset = request.offset

        let queryProps: [String: Any] = [
            "query": request.query,
            "type": "text",
            "size": pageSize,
            "from": offset,
            "sort_type": "relevance",
        ]

        let params: [String: Any] = ["queryProps": queryProps]
        let paramsData = try JSONSerialization.data(withJSONObject: params)

        let response = try await bridge.call(
            method: "search.query",
            paramsData: paramsData,
            timeoutMs: 20000
        )

        guard response.isSuccess, let resultData = response.resultData else {
            return LibrarySearchPage(items: [], totalCount: 0, hasMore: false, nextOffset: offset)
        }

        return parseSearchPage(from: resultData, query: request.query, offset: offset, pageSize: pageSize)
    }

    private func parseSearchPage(
        from data: Data,
        query: String,
        offset: Int,
        pageSize: Int
    ) -> LibrarySearchPage {
        guard let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hitsObj = jsonObj["hits"] as? [String: Any],
              let totalObj = hitsObj["total"] as? [String: Any],
              let totalCount = totalObj["value"] as? Int,
              let hits = hitsObj["hits"] as? [[String: Any]] else {
            return LibrarySearchPage(items: [], totalCount: 0, hasMore: false, nextOffset: offset)
        }

        let items: [SearchResultItem] = hits.compactMap { hitDict -> SearchResultItem? in
            guard let source = hitDict["_source"] as? [String: Any],
                  let ref = source["ref"] as? String else {
                return nil
            }

            let heRef = source["heRef"] as? String ?? ref
            let title = (source["title"] as? String) ?? ref
            let highlight = hitDict["highlight"] as? [String: Any]
            let snippet = (highlight?["exact"] as? [String])?.first
                ?? (highlight?["naive_lemmatizer"] as? [String])?.first
                ?? (source["text"] as? String)
                ?? ""

            let locator = TextLocator(backend: .sefariaEmbedded, workKey: title, position: .canonicalRef(ref))

            return SearchResultItem(
                locator: locator,
                title: ref,
                heTitle: heRef,
                snippet: snippet,
                score: hitDict["_score"] as? Double ?? 1.0
            )
        }

        let nextOffset = offset + items.count
        let hasMore = nextOffset < totalCount

        return LibrarySearchPage(
            items: items,
            totalCount: totalCount,
            hasMore: hasMore,
            nextOffset: nextOffset
        )
    }
}
