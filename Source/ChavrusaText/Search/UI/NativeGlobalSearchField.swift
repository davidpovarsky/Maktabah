import SwiftUI
import UIKit

/// A native search field placed in content: `.searchable` would create another navigation field.
struct NativeGlobalSearchField: UIViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UISearchTextField {
        let field = UISearchTextField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.placeholder = String(localized: "Search Books", defaultValue: "חיפוש בטקסט הספרים")
        field.accessibilityLabel = field.placeholder
        field.accessibilityIdentifier = "global-search-query"
        field.returnKeyType = .search
        field.enablesReturnKeyAutomatically = true
        field.clearButtonMode = .whileEditing
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
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
