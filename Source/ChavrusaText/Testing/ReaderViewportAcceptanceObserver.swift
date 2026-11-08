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
            text.updateViewportAccessibilityMetadata()
            let fields = Dictionary((text.accessibilityHint ?? "").split(separator: ";").compactMap { field -> (String, String)? in
                let pair = field.split(separator: "=", maxSplits: 1)
                guard pair.count == 2 else { return nil }
                return (String(pair[0]), String(pair[1]))
            }, uniquingKeysWith: { first, _ in first })
            guard let source = fields["source"].flatMap(Int.init),
                  let offset = fields["offset"].flatMap(Double.init), offset.isFinite,
                  let object = fields["object"].flatMap(Int.init) else { return }
            let report: [String: Any] = ["source": source, "offset": offset, "object": object,
                                          "reduceMotion": UIAccessibility.isReduceMotionEnabled,
                                          "isRestoringScroll": text.isRestoringScroll,
                                          "scrollOffsetY": text.contentOffset.y,
                                          "contentHeight": text.contentSize.height,
                                          "viewportHeight": text.bounds.height,
                                          "panTranslationY": text.panGestureRecognizer.translation(in: text).y,
                                          "requestID": request, "capturedAt": Date().timeIntervalSince1970]
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
#endif
