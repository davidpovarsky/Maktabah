//
//  SefariaEmbeddedTextAdapter.swift
//  Maktabah
//
//  Downstream-owned text adapter for embedded Sefaria-Mobile.
//  Conforms to LibraryTextProviding and LibraryMetadataProviding.
//

import Foundation

public final class SefariaEmbeddedTextAdapter: LibraryTextProviding, LibraryMetadataProviding, @unchecked Sendable {
    private let bridge: SefariaJSRPCBridge

    public init(bridge: SefariaJSRPCBridge = .shared) {
        self.bridge = bridge
    }

    public func section(at locator: TextLocator) async throws -> LibraryTextSection {
        guard case .canonicalRef(let ref) = locator.position else {
            throw LibraryBackendError.unsupportedLocation(locator)
        }

        let params: [String: Any] = [
            "ref": ref,
            "context": true,
            "fallbackOnDefaultVersions": true,
        ]
        let paramsData = try JSONSerialization.data(withJSONObject: params)

        let response = try await bridge.call(
            method: "text.load",
            paramsData: paramsData,
            timeoutMs: 20000
        )

        guard response.isSuccess, let resultData = response.resultData else {
            let errorMsg = response.error?.message ?? "Failed to load text section for \(ref)"
            throw LibraryBackendError.readingFailed(errorMsg)
        }

        return try parseTextSection(from: resultData, originalLocator: locator)
    }

    public func versions(for workKey: String) async throws -> [TextVersionMetadata] {
        let params = ["ref": workKey]
        let paramsData = try? JSONEncoder().encode(params)
        let response = try await bridge.call(method: "text.versions", paramsData: paramsData)
        guard response.isSuccess, let resultData = response.resultData else {
            return []
        }

        guard let jsonArray = try? JSONSerialization.jsonObject(with: resultData) as? [[String: Any]] else {
            return []
        }

        return jsonArray.compactMap { dict -> TextVersionMetadata? in
            guard let title = dict["versionTitle"] as? String else { return nil }
            return TextVersionMetadata(
                title: title,
                heTitle: dict["versionTitleInHebrew"] as? String,
                language: dict["language"] as? String ?? "en",
                isSource: dict["isSource"] as? Bool ?? false
            )
        }
    }

    public func related(to locator: TextLocator) async throws -> [TextLocator] {
        guard case .canonicalRef(let ref) = locator.position else { return [] }
        let params = ["ref": ref, "online": true] as [String: Any]
        let paramsData = try? JSONSerialization.data(withJSONObject: params)
        let response = try await bridge.call(method: "relationships.links", paramsData: paramsData)
        guard response.isSuccess, let resultData = response.resultData else {
            return []
        }

        guard let jsonArray = try? JSONSerialization.jsonObject(with: resultData) as? [[String: Any]] else {
            return []
        }

        return jsonArray.compactMap { dict -> TextLocator? in
            guard let sourceRef = dict["sourceRef"] as? String ?? dict["ref"] as? String else { return nil }
            let workKey = (dict["index_title"] as? String) ?? sourceRef
            return TextLocator(backend: .sefariaEmbedded, workKey: workKey, position: .canonicalRef(sourceRef))
        }
    }

    private func parseTextSection(from data: Data, originalLocator: TextLocator) throws -> LibraryTextSection {
        guard let jsonObj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LibraryBackendError.readingFailed("Invalid JSON response from text.load")
        }

        let content = (jsonObj["textContent"] as? [String: Any]) ?? jsonObj

        let ref = content["ref"] as? String ?? originalLocator.workKey
        let heRef = content["heRef"] as? String
        let sectionRef = content["sectionRef"] as? String ?? ref
        let heSectionRef = content["heSectionRef"] as? String ?? heRef

        let sectionLocator = TextLocator(
            backend: .sefariaEmbedded,
            workKey: originalLocator.workKey,
            position: .canonicalRef(sectionRef)
        )

        let nextRef = content["next"] as? String
        let prevRef = content["prev"] as? String

        let nextLocator = nextRef.map { TextLocator(backend: .sefariaEmbedded, workKey: originalLocator.workKey, position: .canonicalRef($0)) }
        let prevLocator = prevRef.map { TextLocator(backend: .sefariaEmbedded, workKey: originalLocator.workKey, position: .canonicalRef($0)) }

        // Segments parsing
        var segments: [LibraryTextSegment] = []
        let hebrewSegments = (content["he"] as? [String]) ?? (content["he"] as? String).map { [$0] } ?? []
        let englishSegments = (content["text"] as? [String]) ?? (content["text"] as? String).map { [$0] } ?? []

        let segmentCount = max(hebrewSegments.count, englishSegments.count)
        for i in 0..<segmentCount {
            let he = i < hebrewSegments.count ? hebrewSegments[i] : ""
            let en = i < englishSegments.count ? englishSegments[i] : ""
            let segmentRef = "\(sectionRef):\(i + 1)"
            let segmentLocator = TextLocator(backend: .sefariaEmbedded, workKey: originalLocator.workKey, position: .canonicalRef(segmentRef))

            segments.append(LibraryTextSegment(
                locator: segmentLocator,
                index: i,
                hebrewText: he,
                englishText: en
            ))
        }

        return LibraryTextSection(
            locator: sectionLocator,
            title: sectionRef,
            heTitle: heSectionRef,
            segments: segments,
            nextSectionLocator: nextLocator,
            previousSectionLocator: prevLocator
        )
    }
}
