//
//  SefariaEmbeddedRelationshipsAdapter.swift
//  Maktabah
//
//  Downstream-owned relationships adapter resolving commentaries, links, and topics
//  via Sefaria-Mobile's offlineOnline.loadRelated().
//

import Foundation

final class SefariaEmbeddedRelationshipsAdapter: LibraryRelationshipsProviding, Sendable {
    static let shared = SefariaEmbeddedRelationshipsAdapter()

    private init() {}

    func links(for locator: TextLocator) async throws -> [LibraryRelatedSource] {
        try await SefariaRuntimeManager.shared.ensureReady()

        let canonicalRef: String
        switch locator.position {
        case .canonicalRef(let ref):
            canonicalRef = ref
        default:
            canonicalRef = locator.workKey
        }

        let params = ["ref": canonicalRef, "online": true]
        let paramsData = try JSONSerialization.data(withJSONObject: params)
        let paramsJson = String(data: paramsData, encoding: .utf8)

        let response = try await SefariaJSRPCBridge.shared.call(
            method: "relationships.links",
            paramsJson: paramsJson
        )

        guard response.isSuccess,
              let resultJson = response.resultJson,
              let data = resultJson.data(using: .utf8) else {
            return []
        }

        var rawLinks: [[String: Any]] = []

        if let linksArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            rawLinks = linksArray
        } else if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let linksArray = dict["links"] as? [[String: Any]] {
            rawLinks = linksArray
        }

        return rawLinks.compactMap { linkDict in
            guard let sourceRef = (linkDict["sourceRef"] as? String) ?? (linkDict["ref"] as? String) else {
                return nil
            }
            let sourceHeRef = (linkDict["sourceHeRef"] as? String) ?? (linkDict["heRef"] as? String)
            let category = (linkDict["category"] as? String) ?? "Commentary"
            let type = (linkDict["type"] as? String) ?? category
            let anchorRef = linkDict["anchorRef"] as? String

            var collectiveEn: String? = nil
            var collectiveHe: String? = nil
            if let collDict = linkDict["collectiveTitle"] as? [String: Any] {
                collectiveEn = collDict["en"] as? String
                collectiveHe = collDict["he"] as? String
            } else if let collStr = linkDict["collectiveTitle"] as? String {
                collectiveEn = collStr
            }

            let sourceLocator = TextLocator(
                backend: .sefariaEmbedded,
                workKey: sourceRef,
                position: .canonicalRef(sourceRef)
            )

            return LibraryRelatedSource(
                locator: sourceLocator,
                displayRef: sourceRef,
                heRef: sourceHeRef,
                category: category,
                type: type,
                collectiveTitle: collectiveEn,
                heCollectiveTitle: collectiveHe,
                primaryText: linkDict["he"] as? String,
                translation: linkDict["text"] as? String,
                versionTitle: linkDict["versionTitle"] as? String,
                heVersionTitle: linkDict["heVersionTitle"] as? String,
                license: linkDict["license"] as? String,
                anchorRefs: anchorRef != nil ? [anchorRef!] : []
            )
        }
    }

    func topics(for locator: TextLocator) async throws -> [LibraryRelatedTopic] {
        try await SefariaRuntimeManager.shared.ensureReady()

        let canonicalRef: String
        switch locator.position {
        case .canonicalRef(let ref):
            canonicalRef = ref
        default:
            canonicalRef = locator.workKey
        }

        let params = ["ref": canonicalRef, "online": true]
        let paramsData = try JSONSerialization.data(withJSONObject: params)
        let paramsJson = String(data: paramsData, encoding: .utf8)

        let response = try await SefariaJSRPCBridge.shared.call(
            method: "relationships.links",
            paramsJson: paramsJson
        )

        guard response.isSuccess,
              let resultJson = response.resultJson,
              let data = resultJson.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let topicsArray = dict["topics"] as? [[String: Any]] else {
            return []
        }

        return topicsArray.compactMap { topicDict in
            guard let slug = (topicDict["topic"] as? String) ?? (topicDict["slug"] as? String) else {
                return nil
            }
            let titleEn = (topicDict["title"] as? String) ?? (topicDict["en"] as? String)
            let titleHe = (topicDict["he"] as? String)

            return LibraryRelatedTopic(
                slug: slug,
                titleHe: titleHe,
                titleEn: titleEn
            )
        }
    }
}
