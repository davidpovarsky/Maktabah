import Foundation
import UIKit

// Explicit unexecuted application dependency boundaries for whole-file SDK
// typechecking. The running component controls use a real UIKit UITextView.
@MainActor final class SelectionControlTextState { var showHarakat = true }
@MainActor final class iOSCustomIbarotTextView: UITextView {
    var currentRenderResult: ArabicRenderResult?
    let state = SelectionControlTextState()
    func updateViewportAccessibilityMetadata() {}
}
@MainActor final class ReaderOverviewPresentationController: UIViewController {
    var acceptancePresentationSnapshot: [String: Any] { [:] }
}
enum ReaderRenderedHighlightInspector {
    static let diagnosticsAccessibilityIdentifier = "reader-rendered-highlight-diagnostics"
}
