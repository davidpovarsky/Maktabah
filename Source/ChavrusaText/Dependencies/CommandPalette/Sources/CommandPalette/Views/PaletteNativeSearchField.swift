#if os(iOS)
import SwiftUI
import UIKit

/// Keep command keys on the actual first responder. A hosting controller's
/// commands can be consumed by its focused SwiftUI text field on iPadOS.
struct PaletteNativeSearchField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let placeholder: String
    let onSubmit: () -> Void
    let onEscape: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> PaletteCommandTextField {
        let field = PaletteCommandTextField()
        field.delegate = context.coordinator
        field.borderStyle = .none
        field.textColor = .label
        field.font = UIFontMetrics(forTextStyle: .title3).scaledFont(for: .systemFont(ofSize: 20))
        field.adjustsFontForContentSizeCategory = true
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.returnKeyType = .go
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ field: PaletteCommandTextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        field.placeholder = placeholder
        field.accessibilityLabel = placeholder
        field.semanticContentAttribute = context.environment.layoutDirection == .rightToLeft
            ? .forceRightToLeft : .forceLeftToRight
        field.onEscape = onEscape
        field.onMoveUp = onMoveUp
        field.onMoveDown = onMoveDown
        field.wantsFocus = isFocused
        field.updateFocus()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PaletteCommandTextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? max(44, uiView.intrinsicContentSize.width),
               height: uiView.intrinsicContentSize.height)
    }

    static func dismantleUIView(_ uiView: PaletteCommandTextField, coordinator: Coordinator) {
        uiView.resignFirstResponder()
    }

    @MainActor final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PaletteNativeSearchField
        init(parent: PaletteNativeSearchField) { self.parent = parent }
        @objc func changed(_ field: UITextField) { parent.text = field.text ?? "" }
        func textFieldDidBeginEditing(_ textField: UITextField) { parent.isFocused = true }
        func textFieldDidEndEditing(_ textField: UITextField) { parent.isFocused = false }
        func textFieldShouldReturn(_ textField: UITextField) -> Bool { parent.onSubmit(); return false }
    }
}

final class PaletteCommandTextField: UITextField {
    var wantsFocus = false
    var onEscape: (() -> Void)?
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?

    override func didMoveToWindow() { super.didMoveToWindow(); updateFocus() }

    func updateFocus() {
        guard window != nil else { return }
        if wantsFocus && !isFirstResponder {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil, self.wantsFocus else { return }
                self.becomeFirstResponder()
            }
        } else if !wantsFocus && isFirstResponder { resignFirstResponder() }
    }

    override var keyCommands: [UIKeyCommand]? {
        let escape = UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(cancelPalette))
        escape.wantsPriorityOverSystemBehavior = true
        return [escape,
                UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(moveUp)),
                UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(moveDown))]
            + (super.keyCommands ?? [])
    }

    // Text-input clients can deliver Escape as its control character instead
    // of a key command. It is a command, never part of the search query.
    override func insertText(_ text: String) {
        if text == "\u{1b}" { cancelPalette() } else { super.insertText(text) }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(cancelPalette) || action == #selector(moveUp) || action == #selector(moveDown) {
            return isFirstResponder
        }
        return super.canPerformAction(action, withSender: sender)
    }

    @objc private func cancelPalette() { resignFirstResponder(); onEscape?() }
    @objc private func moveUp() { onMoveUp?() }
    @objc private func moveDown() { onMoveDown?() }
}
#endif
