import Foundation
import UIKit
/// An explicitly requested, bounded observation of UIKit's existing selection.
/// It neither selects text nor changes first responder, rendering or layout.
@MainActor enum ReaderNativeSelectionObservation {
    static func report(textView: UITextView, rendered: ArabicRenderResult?,
                       requestID: String, showHarakat: Bool) -> [String: Any] {
        var result: [String: Any] = [
            "schema": 1, "status": "UNAVAILABLE", "requestID": requestID,
            "processID": ProcessInfo.processInfo.processIdentifier,
            "observedUptime": ProcessInfo.processInfo.systemUptime,
            "textViewObject": ObjectIdentifier(textView).hashValue,
            "usesTextKit2BeforeObservation": textView.textLayoutManager != nil,
            "scope": "original UIKit selected UTF16 range and its original renderer mapping; no full-body or first-pixel claim"
        ]
        func rejected(_ reason: String) -> [String: Any] {
            result["status"] = "UNAVAILABLE"
            result["reason"] = reason
            result["usesTextKit2AfterObservation"] = textView.textLayoutManager != nil
            result.removeValue(forKey: "displayUTF8")
            result.removeValue(forKey: "sourceUTF8")
            return result
        }
        guard UUID(uuidString: requestID) != nil else { return rejected("invalid-request-id") }
        let diagnostics = textView.subviews.filter {
            $0.accessibilityIdentifier == ReaderRenderedHighlightInspector.diagnosticsAccessibilityIdentifier
        }
        guard diagnostics.count == 1,
              let json = diagnostics[0].accessibilityValue, json.utf8.count <= 65_536,
              let identity = RenderedHighlightSnapshot.fromJSONString(json),
              let locator = identity.locator, !locator.isEmpty, locator.utf8.count <= 1024,
              identity.renderGeneration > 0 else { return rejected("original-reader-identity-unavailable") }
        result["locator"] = locator
        result["renderGeneration"] = identity.renderGeneration
        guard let rendered else { return rejected("original-render-result-absent") }
        let display = (textView.text ?? "") as NSString
        guard display.isEqual(to: rendered.attributedString.string) else {
            return rejected("native-text-and-render-result-differ")
        }
        let source = rendered.sourceText as NSString
        let selected = textView.selectedRange
        result["displayUTF16Length"] = display.length
        result["sourceUTF16Length"] = source.length
        result["displayRangeLocation"] = selected.location
        result["displayRangeLength"] = selected.length
        result["showHarakat"] = showHarakat
        result["isFirstResponder"] = textView.isFirstResponder
        result["hasNativeTextRange"] = textView.selectedTextRange != nil
        guard selected.location != NSNotFound, selected.location >= 0, selected.length >= 0,
              selected.location <= display.length, selected.length <= display.length - selected.location else {
            return rejected("native-selection-outside-display")
        }
        guard selected.length > 0 else {
            result["status"] = "EMPTY"
            result["usesTextKit2AfterObservation"] = textView.textLayoutManager != nil
            return result
        }
        guard let nativeRange = textView.selectedTextRange,
              textView.offset(from: textView.beginningOfDocument, to: nativeRange.start) == selected.location,
              textView.offset(from: textView.beginningOfDocument, to: nativeRange.end) - selected.location == selected.length else {
            return rejected("native-selection-offsets-disagree")
        }
        guard selected.length <= 2048 else { return rejected("selected-display-cap") }
        let mapped = ReaderSelectionRangeMapper().mapSelection(
            displayedRange: selected, sourceText: rendered.sourceText, displayedText: display as String,
            mappingProvider: ClosureRangeMappingProvider { rendered.remapSourceRange($0) })
        guard case .success(let selection) = mapped else { return rejected("original-selection-mapping-rejected") }
        guard selection.sourceRange.length <= 4096 else { return rejected("selected-source-cap") }
        let displayedText = display.substring(with: selected)
        guard displayedText.utf8.count <= 8192, selection.selectedText.utf8.count <= 16_384 else {
            return rejected("selected-text-encoding-cap")
        }
        result["sourceRangeLocation"] = selection.sourceRange.location
        result["sourceRangeLength"] = selection.sourceRange.length
        result["displayUTF8"] = displayedText
        result["sourceUTF8"] = selection.selectedText
        result["status"] = "AVAILABLE"
        result["usesTextKit2AfterObservation"] = textView.textLayoutManager != nil
        guard let encoded = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              encoded.count <= 32_768 else { return rejected("encoded-selection-report-cap") }
        return result
    }
}
