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

#if canImport(UIKit)
public enum ReaderRenderedHighlightInspector {
    public static let diagnosticsAccessibilityIdentifier = "reader-rendered-highlight-diagnostics"

    public static func inspect(
        textView: UITextView,
        searchRanges: [NSRange],
        currentLocator: String?,
        renderGeneration: Int
    ) -> RenderedHighlightSnapshot {
        guard let attributedString = textView.attributedText, attributedString.length > 0 else {
            return RenderedHighlightSnapshot(
                searchHighlightCount: 0,
                annotationHighlightCount: 0,
                segmentSelectionCount: 0,
                totalHighlights: 0,
                locator: currentLocator,
                renderGeneration: renderGeneration,
                highlights: []
            )
        }

        var items: [RenderedHighlightItem] = []
        var searchCount = 0
        var annotationCount = 0
        var selectionCount = 0

        attributedString.enumerateAttributes(
            in: NSRange(location: 0, length: attributedString.length),
            options: []
        ) { attrs, range, _ in
            guard range.length > 0 else { return }

            let hasAnnotationId = attrs[NSAttributedString.Key("annotationID")] != nil
            guard let bgColor = attrs[.backgroundColor] as? UIColor else { return }

            let hex = colorToHex(bgColor)
            let provenance: String

            if hasAnnotationId {
                provenance = "annotation"
                annotationCount += 1
            } else if isSegmentSelection(color: bgColor) {
                provenance = "selection"
                selectionCount += 1
            } else if searchRanges.contains(where: { NSIntersectionRange($0, range).length > 0 }) {
                provenance = "search"
                searchCount += 1
            } else {
                provenance = "search"
                searchCount += 1
            }

            items.append(RenderedHighlightItem(
                location: range.location,
                length: range.length,
                colorHex: hex,
                provenance: provenance
            ))
        }

        return RenderedHighlightSnapshot(
            searchHighlightCount: searchCount,
            annotationHighlightCount: annotationCount,
            segmentSelectionCount: selectionCount,
            totalHighlights: items.count,
            locator: currentLocator,
            renderGeneration: renderGeneration,
            highlights: items
        )
    }

    public static func updateDiagnostics(
        for textView: UITextView,
        searchRanges: [NSRange],
        currentLocator: String?,
        renderGeneration: Int
    ) {
        let snapshot = inspect(
            textView: textView,
            searchRanges: searchRanges,
            currentLocator: currentLocator,
            renderGeneration: renderGeneration
        )
        let jsonString = snapshot.toJSONString()

        textView.accessibilityValue = jsonString

        let subview: UIView
        if let existing = textView.subviews.first(where: { $0.accessibilityIdentifier == diagnosticsAccessibilityIdentifier }) {
            subview = existing
        } else {
            let view = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
            view.accessibilityIdentifier = diagnosticsAccessibilityIdentifier
            view.isAccessibilityElement = true
            view.isUserInteractionEnabled = false
            textView.addSubview(view)
            subview = view
        }
        subview.accessibilityValue = jsonString
        subview.accessibilityLabel = "searchHighlights:\(snapshot.searchHighlightCount)"
    }

    private static func isSegmentSelection(color: UIColor) -> Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if color.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return a > 0.10 && a < 0.20 && b > 0.7
        }
        return false
    }

    private static func colorToHex(_ color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if color.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return String(format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255)))
        }
        return "#UNKNOWN"
    }
}
#endif
