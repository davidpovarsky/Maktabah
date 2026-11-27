#if DEBUG && canImport(UIKit)
import SwiftUI
import UIKit

/// Read-only test observation of the original TextKit view. No renderer hooks,
/// viewport mutations or acceptance elements are installed. A fresh request ID
/// prevents an old report from passing an assertion after a failed interaction.
struct ReaderViewportAcceptanceObserver: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        context.coordinator.start(view)
        return view
    }
    func updateUIView(_ view: UIView, context: Context) {}
    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) { coordinator.stop() }

    @MainActor final class Coordinator {
        private var timer: Timer?
        private weak var probe: UIView?
        private var prefix: String?
        private var lastRequest: String?

        func start(_ view: UIView) {
            guard let path = ProcessInfo.processInfo.environment["CHAVRUSA_READER_VIEWPORT_REPORT"], !path.isEmpty,
                  ProcessInfo.processInfo.environment["MAKTABAH_SMOKE_READY_FILE"] == nil else { return }
            probe = view
            // XCTest can relocate the app's container during installation.
            // Resolve this unique test basename inside the app's current real
            // Documents directory, rather than trusting a pre-install UUID.
            prefix = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(URL(fileURLWithPath: path).lastPathComponent).path
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.reportIfRequested() }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
        func stop() { timer?.invalidate(); timer = nil }

        private func reportIfRequested() {
            guard let prefix, let window = probe?.window,
                  let request = try? String(contentsOfFile: prefix + ".request", encoding: .utf8),
                  UUID(uuidString: request) != nil, request != lastRequest else { return }
            var matches: [iOSCustomIbarotTextView] = []
            func visit(_ view: UIView) {
                guard !view.isHidden, view.alpha > 0 else { return }
                if let text = view as? iOSCustomIbarotTextView,
                   text.accessibilityIdentifier == "reader-text",
                   text.convert(text.bounds, to: window).intersects(window.bounds) { matches.append(text) }
                for child in view.subviews { visit(child) }
            }
            visit(window)
            guard matches.count == 1, let text = matches.first else { return }
            // This existing method only observes the original source anchor.
            // Its optional old file exporter is deliberately NOT activated.
            let usesTextKit2BeforeObservation = text.textLayoutManager != nil
            text.updateViewportAccessibilityMetadata()
            let usesTextKit2AfterObservation = text.textLayoutManager != nil
            let fields = Dictionary((text.accessibilityHint ?? "").split(separator: ";").compactMap { field -> (String, String)? in
                let pair = field.split(separator: "=", maxSplits: 1)
                guard pair.count == 2 else { return nil }
                return (String(pair[0]), String(pair[1]))
            }, uniquingKeysWith: { first, _ in first })
            guard let source = fields["source"].flatMap(Int.init),
                  let offset = fields["offset"].flatMap(Double.init), offset.isFinite,
                  let object = fields["object"].flatMap(Int.init) else { return }
            var presentations: [[String: Any]] = []
            var visited = Set<ObjectIdentifier>()
            @MainActor func inspectController(_ controller: UIViewController) {
                guard visited.insert(ObjectIdentifier(controller)).inserted else { return }
                if let anchor = controller as? ReaderOverviewPresentationController {
                    presentations.append(anchor.acceptancePresentationSnapshot)
                }
                for child in controller.children { inspectController(child) }
                if let presented = controller.presentedViewController { inspectController(presented) }
            }
            if let root = window.rootViewController { inspectController(root) }
            var report: [String: Any] = ["source": source, "offset": offset, "object": object,
                                          "overviewPresentations": presentations,
                                          "usesTextKit2BeforeObservation": usesTextKit2BeforeObservation,
                                          "usesTextKit2AfterObservation": usesTextKit2AfterObservation,
                                          "contentHeight": Double(text.contentSize.height),
                                          "viewportHeight": Double(text.bounds.height),
                                          "contentOffsetY": Double(text.contentOffset.y),
                                          "topInset": Double(text.adjustedContentInset.top),
                                          "bottomInset": Double(text.adjustedContentInset.bottom),
                                          "requestID": request, "capturedAt": Date().timeIntervalSince1970]

            if ProcessInfo.processInfo.environment["CHAVRUSA_FULL_V32_SOURCE_OBSERVATION"] == "1" {
                // This opt-in sample is requested only after timing/resource epochs
                // end. It observes the original renderer; it never drives layout.
                var sample: [String: Any] = [
                    "schema": 1, "status": "UNAVAILABLE",
                    "processID": ProcessInfo.processInfo.processIdentifier,
                    "observedUptime": ProcessInfo.processInfo.systemUptime,
                    "scope": "bounded original source sample; not first pixel or full rendered-body proof"
                ]
                if let rendered = text.currentRenderResult {
                    let original = rendered.sourceText as NSString
                    sample["sourceUTF16Length"] = original.length
                    if source >= 0 && source < original.length {
                        let requested = NSRange(location: source, length: min(128, original.length - source))
                        let composed = original.rangeOfComposedCharacterSequences(for: requested)
                        // A single pathological grapheme must not bypass the cap.
                        // Check expansion before copying/encoding its characters.
                        if composed.location != NSNotFound, composed.location >= 0,
                           composed.length > 0, composed.length <= 256,
                           composed.location <= original.length,
                           composed.length <= original.length - composed.location {
                            let snippet = original.substring(with: composed)
                            if snippet.utf8.count <= 1024 {
                                sample["status"] = "AVAILABLE"
                                sample["rangeLocation"] = composed.location
                                sample["rangeLength"] = composed.length
                                sample["sourceUTF8"] = snippet
                            } else { sample["reason"] = "encoded-source-cap" }
                        } else { sample["reason"] = "composed-range-cap" }
                    } else { sample["reason"] = "source-index-outside-original" }
                } else { sample["reason"] = "original-render-result-absent" }
                // The complete optional object is bounded, including JSON escapes.
                if let encoded = try? JSONSerialization.data(withJSONObject: sample, options: [.sortedKeys]),
                   encoded.count <= 4096 {
                    report["fullV32SourceObservation"] = sample
                } else {
                    report["fullV32SourceObservation"] = [
                        "schema": 1, "status": "UNAVAILABLE", "reason": "encoded-report-cap"
                    ]
                }
            }

            if ProcessInfo.processInfo.environment["CHAVRUSA_READER_SELECTION_OBSERVATION"] == "1" {
                report["nativeSelectionObservation"] = ReaderNativeSelectionObservation.report(
                    textView: text, rendered: text.currentRenderResult, requestID: request,
                    showHarakat: text.state.showHarakat)
            }

            do {
                let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
                try data.write(to: URL(fileURLWithPath: prefix + ".viewport.json"), options: .atomic)
                lastRequest = request
            } catch {
                // A missing report fails the requesting XCTest. Observation
                // must never crash or change the reader under test.
            }
        }
    }
}

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
#endif
