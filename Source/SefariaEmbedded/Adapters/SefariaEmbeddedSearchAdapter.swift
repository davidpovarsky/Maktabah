//
//  SefariaEmbeddedSearchAdapter.swift
//  Maktabah
//
//  Downstream-owned adapter providing full-text search via original Sefaria-Mobile
//  @sefaria/search engine with exact queryProps (start, size, type).
//

import Foundation

public final class SefariaEmbeddedSearchAdapter: LibrarySearchProviding, Sendable {
    public static let shared = SefariaEmbeddedSearchAdapter()

    private init() {}

    public func search(request: LibrarySearchRequest) async throws -> LibrarySearchPage {
        try await SefariaRuntimeManager.shared.ensureReady()

        let params: [String: Any] = [
            "query": request.query,
            "offset": request.offset,
            "limit": 20,
            "type": "text",
            "field": "exact",
            "sortType": "relevance",
        ]

        let paramsData = try JSONSerialization.data(withJSONObject: params)
        let paramsJson = String(data: paramsData, encoding: .utf8)

        let response = try await SefariaJSRPCBridge.shared.call(
            method: "search.query",
            paramsJson: paramsJson,
            timeoutMs: 15000
        )

        guard response.isSuccess,
              let resultJson = response.resultJson,
              let data = resultJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw response.error ?? SefariaRPCError(code: "SEARCH_FAILED", message: "Search query execution failed")
        }

        let rawHits = (json["hits"] as? [[String: Any]]) ?? []
        let total = (json["total"] as? Int) ?? rawHits.count
        let start = (json["start"] as? Int) ?? request.offset

        let hits: [LibrarySearchHit] = rawHits.compactMap { hitDict in
            guard let ref = hitDict["ref"] as? String else { return nil }
            let heRef = hitDict["heRef"] as? String
            let snippet = (hitDict["snippet"] as? String) ?? ""
            let score = hitDict["score"] as? Double
            let version = hitDict["version"] as? String
            let language = hitDict["language"] as? String

            let locator = TextLocator(
                backend: .sefariaEmbedded,
                workKey: ref,
                position: .canonicalRef(ref)
            )

            return LibrarySearchHit(
                locator: locator,
                displayRef: ref,
                heRef: heRef,
                snippet: snippet,
                score: score,
                versionTitle: version,
                language: language
            )
        }

        let nextOffset: Int? = (start + hits.count < total) ? (start + hits.count) : nil

        return LibrarySearchPage(
            hits: hits,
            total: total,
            nextOffset: nextOffset
        )
    }
}
