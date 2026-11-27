import Foundation
import UIKit

@main struct UIKitSelectionControls {
    @MainActor static func main() throws {
        var results: [[String: Any]] = []
        func check(_ name: String, _ body: () throws -> Bool) {
            do { results.append(["name": name, "passed": try body()]) }
            catch { results.append(["name": name, "passed": false, "error": String(describing: error)]) }
        }
        func make(_ source: String, display: String? = nil,
                  range: NSRange? = nil, events: [TextDeltaEvent] = []) -> (UITextView, ArabicRenderResult) {
            let text = display ?? source
            let view = UITextView(usingTextLayoutManager: true)
            view.text = text
            view.selectedRange = range ?? NSRange(location: 0, length: (text as NSString).length)
            let child = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
            child.accessibilityIdentifier = ReaderRenderedHighlightInspector.diagnosticsAccessibilityIdentifier
            child.accessibilityValue = RenderedHighlightSnapshot(searchHighlightCount: 0,
                annotationHighlightCount: 0, segmentSelectionCount: 0, totalHighlights: 0,
                locator: "otzaria|book:28|line:3", renderGeneration: 7, highlights: []).toJSONString()
            view.addSubview(child)
            return (view, ArabicRenderResult(sourceText: source, attributedString: NSAttributedString(string: text),
                replacementEvents: [], footnoteRanges: [], harakatEvents: events))
        }
        func report(_ pair: (UITextView, ArabicRenderResult), request: String = UUID().uuidString) -> [String: Any] {
            ReaderNativeSelectionObservation.report(textView: pair.0, rendered: pair.1,
                requestID: request, showHarakat: true)
        }
        check("original_UIKit_UTF16_combining_marks_and_surrogate_selection") {
            let text = "\u{202B}נַפְשִׁי 🕯️\u{202C}"
            let pair = make(text), before = pair.0.selectedRange
            let observation = report(pair)
            return observation["status"] as? String == "AVAILABLE"
                && observation["sourceRangeLocation"] as? Int == 0
                && observation["sourceRangeLength"] as? Int == (text as NSString).length
                && observation["sourceUTF8"] as? String == text
                && observation["displayUTF8"] as? String == text
                && pair.0.selectedRange == before
                && observation["usesTextKit2BeforeObservation"] as? Bool == true
                && observation["usesTextKit2AfterObservation"] as? Bool == true
        }
        check("original_delta_mapping_keeps_combining_sequence_in_source") {
            let pair = make("a\u{301}b", display: "ab", range: NSRange(location: 0, length: 1),
                            events: [TextDeltaEvent(oldOffset: 2, delta: -1)])
            let observation = report(pair)
            return observation["status"] as? String == "AVAILABLE"
                && observation["displayRangeLength"] as? Int == 1
                && observation["sourceRangeLength"] as? Int == 2
                && observation["sourceUTF8"] as? String == "a\u{301}"
        }
        check("empty_UIKit_selection_is_reported_without_fabricated_text") {
            let observation = report(make("אב", range: NSRange(location: 0, length: 0)))
            return observation["status"] as? String == "EMPTY" && observation["sourceUTF8"] == nil
                && observation["displayRangeLength"] as? Int == 0
        }
        check("invalid_request_id_refused") {
            let observation = report(make("אב"), request: "not-a-request-uuid")
            return observation["status"] as? String == "UNAVAILABLE"
                && observation["reason"] as? String == "invalid-request-id"
        }
        check("actual_request_process_and_reader_identity_preserved") {
            let id = UUID().uuidString, observation = report(make("אב"), request: id)
            return observation["requestID"] as? String == id
                && observation["processID"] as? Int32 == ProcessInfo.processInfo.processIdentifier
                && observation["locator"] as? String == "otzaria|book:28|line:3"
                && observation["renderGeneration"] as? Int == 7
        }
        check("missing_original_identity_refused") {
            let pair = make("אב"); pair.0.subviews.forEach {
                if $0.accessibilityIdentifier == ReaderRenderedHighlightInspector.diagnosticsAccessibilityIdentifier {
                    $0.removeFromSuperview()
                }
            }
            return report(pair)["reason"] as? String == "original-reader-identity-unavailable"
        }
        check("duplicate_original_identity_refused") {
            let pair = make("אב"), child = UIView()
            child.accessibilityIdentifier = ReaderRenderedHighlightInspector.diagnosticsAccessibilityIdentifier
            pair.0.addSubview(child)
            return report(pair)["reason"] as? String == "original-reader-identity-unavailable"
        }
        check("stale_native_text_against_render_result_refused") {
            let pair = make("אב"); pair.0.text = "גד"
            return report(pair)["reason"] as? String == "native-text-and-render-result-differ"
        }
        check("oversized_native_selection_refused_without_copying_payload") {
            let observation = report(make(String(repeating: "א", count: 2049)))
            return observation["reason"] as? String == "selected-display-cap"
                && observation["sourceUTF8"] == nil && observation["displayUTF8"] == nil
        }
        check("invalid_original_mapping_refused") {
            let pair = make("אב", display: "א", range: NSRange(location: 0, length: 1),
                            events: [TextDeltaEvent(oldOffset: 1, delta: -100)])
            return report(pair)["reason"] as? String == "original-selection-mapping-rejected"
        }
        check("bounded_JSON_escapes_do_not_escape_report_cap") {
            let source = String(repeating: "\u{1}", count: 4096)
            let display = String(repeating: "\u{1}", count: 2048)
            let pair = make(source, display: display, events: [TextDeltaEvent(oldOffset: 4096, delta: -2048)])
            let observation = report(pair)
            let data = try JSONSerialization.data(withJSONObject: observation)
            return data.count <= 32_768 && observation["status"] as? String == "UNAVAILABLE"
                && observation["sourceUTF8"] == nil && observation["displayUTF8"] == nil
        }
        check("original_mapper_rejects_out_of_bounds_and_split_surrogate") {
            let mapper = ReaderSelectionRangeMapper()
            if case .failure = mapper.mapSelection(displayedRange: NSRange(location: 2, length: 2), sourceText: "אב"),
               case .failure = mapper.mapSelection(displayedRange: NSRange(location: 1, length: 1), sourceText: "😀") {
                return true
            }
            return false
        }
        let failed = results.filter { $0["passed"] as? Bool != true }.count
        let output: [String: Any] = ["status": failed == 0 ? "APPLE_UIKIT_COMPONENT_CONTROLS_PASS_NOT_APP_UI" : "APPLE_UIKIT_COMPONENT_CONTROLS_FAILED",
            "scope": "Actual UIKit UITextView and exact original mapping/report source fragments; seeded component input; no Maktabah UI or full target build",
            "processID": ProcessInfo.processInfo.processIdentifier, "passed": results.count - failed,
            "failed": failed, "uiExecuted": 0, "controls": results]
        let data = try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        exit(failed == 0 ? 0 : 1)
    }
}
