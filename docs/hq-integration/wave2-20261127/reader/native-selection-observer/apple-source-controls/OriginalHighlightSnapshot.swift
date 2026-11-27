import Foundation
#if canImport(UIKit)
import UIKit
#endif

public struct RenderedHighlightItem: Codable, Sendable, Equatable {
    public let location: Int
    public let length: Int
    public let colorHex: String
    public let provenance: String // "search", "annotation", "selection", "other"

    public init(location: Int, length: Int, colorHex: String, provenance: String) {
        self.location = location
        self.length = length
        self.colorHex = colorHex
        self.provenance = provenance
    }
}

public struct RenderedHighlightSnapshot: Codable, Sendable, Equatable {
    public let searchHighlightCount: Int
    public let annotationHighlightCount: Int
    public let segmentSelectionCount: Int
    public let totalHighlights: Int
    public let locator: String?
    public let renderGeneration: Int
    public let highlights: [RenderedHighlightItem]

    public init(
        searchHighlightCount: Int,
        annotationHighlightCount: Int,
        segmentSelectionCount: Int,
        totalHighlights: Int,
        locator: String?,
        renderGeneration: Int,
        highlights: [RenderedHighlightItem]
    ) {
        self.searchHighlightCount = searchHighlightCount
        self.annotationHighlightCount = annotationHighlightCount
        self.segmentSelectionCount = segmentSelectionCount
        self.totalHighlights = totalHighlights
        self.locator = locator
        self.renderGeneration = renderGeneration
        self.highlights = highlights
    }

    public func toJSONString() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    public static func fromJSONString(_ string: String) -> RenderedHighlightSnapshot? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(RenderedHighlightSnapshot.self, from: data)
    }
}

