import SwiftUI
import UIKit

/// A native search field placed in content: `.searchable` would create another navigation field.
struct NativeGlobalSearchField: UIViewRepresentable {
    @Binding var text: String
    @Environment(\.maktabahNativeRoutingSession) private var nativeSession
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UISearchTextField {
        let field = GlobalSearchTextField()
        field.delegate = context.coordinator
        field.nativeAttachmentDidChange = { [weak coordinator = context.coordinator] field in
            coordinator?.nativeStateChanged(field)
        }
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
        context.coordinator.bindNativeField(field, session: nativeSession)
        if field.text != text, field.markedTextRange == nil { field.text = text }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISearchTextField, context: Context) -> CGSize? {
        CGSize(width: max(0, proposal.width ?? max(44, uiView.intrinsicContentSize.width)),
               height: max(44, uiView.intrinsicContentSize.height))
    }

    static func dismantleUIView(_ field: UISearchTextField, coordinator: Coordinator) {
        coordinator.unbindNativeField(field)
        (field as? GlobalSearchTextField)?.nativeAttachmentDidChange = nil
    }

    @MainActor final class Coordinator: NSObject, UITextFieldDelegate {
        private weak var nativeSession: MaktabahNativeSceneSession?
        private weak var nativeField: UISearchTextField?

        func bindNativeField(_ field: UISearchTextField, session: MaktabahNativeSceneSession?) {
            guard nativeField !== field || nativeSession !== session else { return }
            if let previous = nativeField { nativeSession?.detachSearchField(previous) }
            nativeField = field; nativeSession = session
            session?.attachSearchField(field)
        }

        func unbindNativeField(_ field: UISearchTextField) {
            guard nativeField === field else { return }
            nativeSession?.detachSearchField(field)
            nativeField = nil; nativeSession = nil
        }

        func nativeStateChanged(_ field: UISearchTextField) {
            guard nativeField === field else { return }
            nativeSession?.searchFieldStateDidChange(field)
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if let field = textField as? UISearchTextField { nativeStateChanged(field) }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if let field = textField as? UISearchTextField { nativeStateChanged(field) }
        }

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
    var nativeAttachmentDidChange: (@MainActor (UISearchTextField) -> Void)?
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
        nativeAttachmentDidChange?(self)
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

    override func layoutSubviews() {
        super.layoutSubviews()
        // UISearchTextField creates its placeholder UILabel lazily. Its font
        // must retain Dynamic Type metadata as well as tracking visual size;
        // updating attributedPlaceholder alone leaves that native label opted
        // out of the system accessibility text-size audit.
        guard let placeholder, let bodyFont = font else { return }
        var descendants = subviews
        while let view = descendants.popLast() {
            descendants.append(contentsOf: view.subviews)
            guard let label = view as? UILabel, label.text == placeholder else { continue }
            label.adjustsFontForContentSizeCategory = true
            if label.font != bodyFont { label.font = bodyFont }
        }
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width, height: max(44, max(size.height, ceil(font?.lineHeight ?? 0) + 20)))
    }
}
