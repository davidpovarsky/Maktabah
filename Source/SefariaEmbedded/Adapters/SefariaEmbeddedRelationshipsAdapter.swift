//
//  SefariaEmbeddedRelationshipsAdapter.swift
//  Maktabah
//
//  Downstream-owned relationships adapter for embedded Sefaria-Mobile.
//  Conforms to LibraryRelationshipsProviding.
//

import Foundation

public final class SefariaEmbeddedRelationshipsAdapter: LibraryRelationshipsProviding, @unchecked Sendable {
    private let bridge: SefariaJSRPCBridge

    public init(bridge: SefariaJSRPCBridge = .shared) {
        self.bridge = bridge
    }

    public func links(for locator: TextLocator) async throws -> [LibraryRelatedSource] {
        guard case .canonicalRef(let ref) = locator.position else { return [] }

        let params: [String: Any] = ["ref": ref, "online": true]
        let paramsData = try JSONSerialization.data(withJSONObject: params)

        let response = try await bridge.call(
            method: "relationships.links",
            paramsData: paramsData,
            timeoutMs: 15000
        )

        guard response.isSuccess, let resultData = response.resultData else {
            return []
        }

        return parseRelatedSources(from: resultData, anchorLocator: locator)
    }

    public func topics(for locator: TextLocator) async throws -> [LibraryRelatedTopic] {
        return []
    }

    private func parseRelatedSources(from data: Data, anchorLocator: TextLocator) -> [LibraryRelatedSource] {
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return jsonArray.compactMap { dict -> LibraryRelatedSource? in
            guard let sourceRef = dict["sourceRef"] as? String ?? dict["ref"] as? String else {
                return nil
            }

            let heSourceRef = dict["sourceHeRef"] as? String ?? dict["heRef"] as? String
            let category = dict["category"] as? String ?? "Commentary"
            let heCategory = dict["heCategory"] as? String
            let collectiveTitle = dict["collectiveTitle"] as? String
            let heCollectiveTitle = dict["heCollectiveTitle"] as? String
            let indexTitle = dict["index_title"] as? String ?? sourceRef

            let targetLocator = TextLocator(
                backend: .sefariaEmbedded,
                workKey: indexTitle,
                position: .canonicalRef(sourceRef)
            )

            let anchorExpanded = (dict["anchorRefExpanded"] as? [String])?.first
                ?? (dict["anchorRef"] as? String)
                ?? (anchorLocator.position.description)

            return LibraryRelatedSource(
                locator: targetLocator,
                title: sourceRef,
                heTitle: heSourceRef,
                category: category,
                heCategory: heCategory,
                collectiveTitle: collectiveTitle,
                heCollectiveTitle: heCollectiveTitle,
                anchorRefExpanded: anchorExpanded,
                hebrewText: dict["he"] as? String,
                englishText: dict["text"] as? String
            )
        }
    }
}
