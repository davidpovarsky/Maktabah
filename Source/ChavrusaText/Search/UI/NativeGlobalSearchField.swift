import SwiftUI
import UIKit

/// A native search field placed in content: `.searchable` would create another navigation field.
struct NativeGlobalSearchField: UIViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UISearchTextField {
        let field = GlobalSearchTextField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.setSearchPlaceholder(String(localized: "Search Books", defaultValue: "חיפוש בטקסט הספרים"))
        field.accessibilityLabel = field.placeholder
        field.accessibilityIdentifier = "global-search-query"
        field.returnKeyType = .search
        field.enablesReturnKeyAutomatically = true
        field.clearButtonMode = .whileEditing
        field.textAlignment = .natural
        field.autocorrectionType = .no
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: UISearchTextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text, field.markedTextRange == nil { field.text = text }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISearchTextField, context: Context) -> CGSize? {
        CGSize(width: max(0, proposal.width ?? max(44, uiView.intrinsicContentSize.width)),
               height: max(44, uiView.intrinsicContentSize.height))
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NativeGlobalSearchField
        init(_ parent: NativeGlobalSearchField) { self.parent = parent }

        @objc func changed(_ field: UISearchTextField) {
            parent.text = field.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.text = textField.text ?? ""
            textField.resignFirstResponder()
            parent.onSubmit()
            return false
        }

        func textFieldShouldClear(_ textField: UITextField) -> Bool {
            parent.text = ""
            return true
        }
    }
}

/// Keep both editable text and its native placeholder on the current trait's
/// body font. UISearchTextField's internal placeholder label can otherwise keep
/// its earlier font while the surrounding SwiftUI layout changes Dynamic Type.
private final class GlobalSearchTextField: UISearchTextField {
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureDynamicType()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureDynamicType()
    }

    private func configureDynamicType() {
        adjustsFontForContentSizeCategory = true
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) {
            (field: GlobalSearchTextField, _: UITraitCollection) in
            field.updateScaledTypography()
        }
        updateScaledTypography()
    }

    func setSearchPlaceholder(_ value: String) {
        placeholder = value
        updateScaledTypography()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateScaledTypography()
    }

    private func updateScaledTypography() {
        let bodyFont = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traitCollection)
        font = bodyFont
        if let placeholder {
            attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [
                .font: bodyFont,
                .foregroundColor: UIColor.placeholderText
            ])
        }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width, height: max(44, max(size.height, ceil(font?.lineHeight ?? 0) + 20)))
    }
}
