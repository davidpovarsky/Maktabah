//
//  SefariaEmbeddedSearchAdapter.swift
//  Maktabah
//
//  Downstream-owned adapter providing full-text search via original Sefaria-Mobile
//  @sefaria/search engine with exact queryProps (start, size, type).
//

import Foundation

final class SefariaEmbeddedSearchAdapter: LibrarySearchProviding, Sendable {
    static let shared = SefariaEmbeddedSearchAdapter()

    private init() {}

    // MARK: - LibrarySearchProviding

    func search(_ request: LibrarySearchRequest) async throws -> LibrarySearchPage {
        try await executeSearch(request)
    }

    func search(request: LibrarySearchRequest) async throws -> LibrarySearchPage {
        try await executeSearch(request)
    }

    private func executeSearch(_ request: LibrarySearchRequest) async throws -> LibrarySearchPage {
        try await SefariaRuntimeManager.shared.ensureSearchReady()

        let params: [String: Any] = [
            "query": request.query,
            "offset": request.offset,
            "limit": request.limit > 0 ? request.limit : 20,
            "type": "text",
            "field": "exact",
            "appliedFilters": request.filters,
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
        let total: Int
        if let totalInt = json["total"] as? Int {
            total = totalInt
        } else if let totalDict = json["total"] as? [String: Any], let val = totalDict["value"] as? Int {
            total = val
        } else {
            total = rawHits.count
        }
        let start = (json["start"] as? Int) ?? request.offset

        let hits: [LibrarySearchHit] = try rawHits.map { hitDict in
            guard let ref = hitDict["ref"] as? String,
                  let workKey = hitDict["workKey"] as? String, !workKey.isEmpty else {
                throw LibraryBackendError.invalidResponse("Sefaria search hit is missing its canonical identity")
            }
            let heRef = hitDict["heRef"] as? String
            let snippet = (hitDict["snippet"] as? String) ?? ""
            let score = hitDict["score"] as? Double
            let version = hitDict["version"] as? String
            let language = LibraryLanguage.normalized(hitDict["language"] as? String)
            let locator = TextLocator(
                backend: .sefariaEmbedded,
                workKey: workKey,
                position: .canonicalRef(ref)
            )

            return LibrarySearchHit(
                locator: locator,
                displayRef: ref,
                heRef: heRef,
                snippet: snippet,
                score: score,
                versionTitle: version,
                language: language,
                workTitle: hitDict["title"] as? String,
                heWorkTitle: hitDict["heTitle"] as? String
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
