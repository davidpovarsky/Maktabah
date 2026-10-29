//
//  SefariaEmbeddedTextAdapter.swift
//  Maktabah
//
//  Downstream-owned adapter providing full reading units, structured segments,
//  and version metadata directly from Sefaria-Mobile's offlineOnline.loadText().
//

import Foundation

public final class SefariaEmbeddedTextAdapter: LibraryTextProviding, LibraryMetadataProviding, Sendable {
    public static let shared = SefariaEmbeddedTextAdapter()

    private init() {}

    // MARK: - LibraryTextProviding

    public func section(at locator: TextLocator) async throws -> LibraryTextSection {
        try await SefariaRuntimeManager.shared.ensureReady()

        let canonicalRef: String
        switch locator.position {
        case .canonicalRef(let ref):
            canonicalRef = ref
        default:
            canonicalRef = locator.workKey
        }

        let params: [String: Any] = [
            "ref": canonicalRef,
            "context": true,
            "fallbackOnDefaultVersions": true,
        ]

        let paramsData = try JSONSerialization.data(withJSONObject: params)
        let paramsJson = String(data: paramsData, encoding: .utf8)

        let response = try await SefariaJSRPCBridge.shared.call(
            method: "text.load",
            paramsJson: paramsJson,
            timeoutMs: 15000
        )

        guard response.isSuccess,
              let resultJson = response.resultJson,
              let data = resultJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw response.error ?? LibraryBackendError.invalidResponse("Sefaria loadText returned invalid payload")
        }

        let textContent = (json["textContent"] as? [String: Any]) ?? json
        let sectionRef = (textContent["sectionRef"] as? String) ?? canonicalRef
        let heSectionRef = textContent["heSectionRef"] as? String

        // Segments from textContent.content: [{ segmentNumber, he, text }]
        let rawContent = (textContent["content"] as? [[String: Any]]) ?? []
        var segments: [LibraryTextSegment] = []

        for (idx, segDict) in rawContent.enumerated() {
            let segNum = (segDict["segmentNumber"] as? String) ?? "\(idx + 1)"
            let heText = (segDict["he"] as? String) ?? ""
            let enText = (segDict["text"] as? String)
            let segRef = "\(sectionRef):\(segNum)"

            let segLocator = TextLocator(
                backend: .sefariaEmbedded,
                workKey: locator.workKey,
                position: .canonicalRef(segRef)
            )

            segments.append(LibraryTextSegment(
                locator: segLocator,
                heRef: nil,
                primaryText: heText,
                translation: enText
            ))
        }

        // If content array was missing, check legacy he/text string arrays
        if segments.isEmpty {
            let heArray = (textContent["he"] as? [String]) ?? []
            let enArray = (textContent["text"] as? [String]) ?? []
            let count = max(heArray.count, enArray.count)

            for i in 0..<count {
                let he = i < heArray.count ? heArray[i] : ""
                let en = i < enArray.count ? enArray[i] : nil
                let segLocator = TextLocator(
                    backend: .sefariaEmbedded,
                    workKey: locator.workKey,
                    position: .canonicalRef("\(sectionRef):\(i + 1)")
                )
                segments.append(LibraryTextSegment(
                    locator: segLocator,
                    heRef: nil,
                    primaryText: he,
                    translation: en
                ))
            }
        }

        let prevRef = textContent["prev"] as? String
        let nextRef = textContent["next"] as? String

        let previousLocator = prevRef.map {
            TextLocator(backend: .sefariaEmbedded, workKey: locator.workKey, position: .canonicalRef($0))
        }
        let nextLocator = nextRef.map {
            TextLocator(backend: .sefariaEmbedded, workKey: locator.workKey, position: .canonicalRef($0))
        }

        let rawLinks = (json["links"] as? [[String: Any]]) ?? []
        let links: [LibraryTextLink] = rawLinks.compactMap { linkDict in
            guard let sourceRef = linkDict["sourceRef"] as? String else { return nil }
            let linkLocator = TextLocator(
                backend: .sefariaEmbedded,
                workKey: sourceRef,
                position: .canonicalRef(sourceRef)
            )
            return LibraryTextLink(
                locator: linkLocator,
                category: linkDict["category"] as? String,
                sourceTitle: sourceRef
            )
        }

        let sectionLocator = TextLocator(
            backend: .sefariaEmbedded,
            workKey: locator.workKey,
            position: .canonicalRef(sectionRef)
        )

        return LibraryTextSection(
            locator: sectionLocator,
            displayRef: sectionRef,
            heRef: heSectionRef,
            segments: segments,
            previous: previousLocator,
            next: nextLocator,
            versions: [],
            links: links,
            origin: .offline
        )
    }

    // MARK: - LibraryMetadataProviding

    public func versions(for workKey: String) async throws -> [TextVersionMetadata] {
        try await SefariaRuntimeManager.shared.ensureReady()
        let params = ["ref": workKey]
        let paramsData = try JSONSerialization.data(withJSONObject: params)
        let paramsJson = String(data: paramsData, encoding: .utf8)

        let response = try await SefariaJSRPCBridge.shared.call(
            method: "text.versions",
            paramsJson: paramsJson
        )

        guard response.isSuccess,
              let resultJson = response.resultJson,
              let data = resultJson.data(using: .utf8),
              let versionsArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return versionsArray.compactMap { dict in
            guard let title = dict["versionTitle"] as? String else { return nil }
            let lang = (dict["language"] as? String) ?? "he"
            return TextVersionMetadata(
                id: "\(title)|\(lang)",
                title: title,
                heTitle: dict["versionTitleInHebrew"] as? String,
                language: lang,
                license: dict["license"] as? String,
                source: dict["versionSource"] as? String
            )
        }
    }
}
