import SwiftUI

struct iOSAnnotationEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State var annotation: Annotation
    let onSave: (Annotation) throws -> Void
    let onDelete: (Int64) throws -> Void

    @State private var noteText: String = ""
    @State private var selectedColorHex: String = ""
    @State private var isUnderline: Bool = false
    @State private var tagsText: String = ""
    @State private var operationErrorMessage: String?
    @State private var editorTextView: UITextView?
    @State private var hasInitialized: Bool = false

    private var availableColors: [UIColor] {
        if isUnderline {
            var colors = UserDefaults.standard.recentUnderlineColors
            if selectedColorHex != "#000000",
               let current = UIColor(hex: selectedColorHex),
               !colors.contains(where: { $0.hexString() == current.hexString() }) {
                colors.append(current)
            }
            return colors
        } else {
            var colors = UserDefaults.standard.recentHighlightColors
            if let current = UIColor(hex: selectedColorHex),
               !colors.contains(where: { $0.hexString() == current.hexString() }) {
                colors.append(current)
            }
            return colors
        }
    }

    private func isColorSelected(_ color: UIColor) -> Bool {
        if isUnderline {
            if color == .label {
                return selectedColorHex.isEmpty || selectedColorHex == "#000000" || selectedColorHex.caseInsensitiveCompare(UIColor.label.hexString()) == .orderedSame
            }
            return selectedColorHex.caseInsensitiveCompare(color.hexString()) == .orderedSame
        } else {
            return selectedColorHex.caseInsensitiveCompare(color.hexString()) == .orderedSame
        }
    }

    var body: some View {
        NavigationStack {
            ThemeForm {
                ThemeSection("Note") {
                    iOSAutoDirectionTextView(text: $noteText, onCreated: { self.editorTextView = $0 })
                        .frame(minHeight: 80)
                }

                ThemeSection {
                    Button(action: saveAnnotation) {
                        HStack {
                            Spacer()
                            Text("Save")
                                .bold()
                            Spacer()
                        }
                    }
                    .accessibilityIdentifier("annotation-save")
                    .accessibilityLabel("Save")

                    if let annotationID = annotation.id {
                        Button(role: .destructive, action: {
                            deleteAnnotation(annotationID)
                        }) {
                            HStack {
                                Spacer()
                                Text("Delete Annotation")
                                Spacer()
                            }
                        }
                        .accessibilityIdentifier("annotation-delete")
                        .accessibilityLabel("Delete Annotation")
                    }

                    Button(role: .cancel, action: { dismiss() }) {
                        HStack {
                            Spacer()
                            Text("Cancel")
                            Spacer()
                        }
                    }
                    .accessibilityIdentifier("annotation-cancel")
                    .accessibilityLabel("Cancel")
                }

                ThemeSection("Style") {
                    Toggle("Underline", isOn: $isUnderline)
                        .onChange(of: isUnderline) { _, newValue in
                            if newValue {
                                let underlineColor = UserDefaults.standard.recentUnderlineColors.first ?? .label
                                selectedColorHex = (underlineColor == .label) ? "#000000" : underlineColor.hexString()
                            } else {
                                let highlightColor = UserDefaults.standard.recentHighlightColors.first ?? .yellow
                                selectedColorHex = highlightColor.hexString()
                            }
                        }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(availableColors, id: \.self) { color in
                                let isSelected = isColorSelected(color)
                                Circle()
                                    .fill(Color(uiColor: color))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                                    )
                                    .padding(2)
                                    .overlay(
                                        Circle()
                                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                                    )
                                    .onTapGesture {
                                        if isUnderline && color == .label {
                                            selectedColorHex = "#000000"
                                        } else {
                                            selectedColorHex = color.hexString()
                                        }
                                    }
                            }
                        }
                        .padding(4)
                    }
                }

                ThemeSection("Tags (comma separated)") {
                    let isRTL = tagsText.isParagraphRTL
                    TextField("tag1, tag2...", text: $tagsText)
                        .multilineTextAlignment(isRTL ? .trailing : .leading)
                        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                }
                ThemeSection {
                    Button(role: .destructive, action: {
                        if let id = annotation.id {
                            onDelete(id)
                        }
                        dismiss()
                    }) {
                        HStack {
                            Spacer()
                            Text(.Annotation.deleteAnnotation)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(.Annotation.editAnnotation)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("annotation-cancel-toolbar")
                    .accessibilityLabel("Cancel")
                }
                if let annotationID = annotation.id {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            deleteAnnotation(annotationID)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityIdentifier("annotation-delete-toolbar")
                        .accessibilityLabel("Delete Annotation")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAnnotation()
                    }
                    .accessibilityIdentifier("annotation-save-toolbar")
                    .accessibilityLabel("Save")
                }
            }
            .onAppear {
                guard !hasInitialized else { return }
                hasInitialized = true
                noteText = annotation.note ?? ""
                isUnderline = annotation.type == .underline
                selectedColorHex = annotation.colorHex
                if isUnderline && (selectedColorHex.isEmpty || selectedColorHex == "#000000") {
                    selectedColorHex = "#000000"
                }
                tagsText = annotation.tags.joined(separator: ", ")
                AccessibleAutoDirectionTextView.lastEnteredText = annotation.note
                #if DEBUG
                (AccessibleAutoDirectionTextView.activeInstance ?? editorTextView as? AccessibleAutoDirectionTextView)?.checkSmokeNoteInput()
                #endif
            }
            .onDisappear {
                if AccessibleAutoDirectionTextView.activeInstance === editorTextView {
                    AccessibleAutoDirectionTextView.activeInstance = nil
                }
            }
            .alert(
                String(localized: "Could Not Save Annotation"),
                isPresented: Binding(
                    get: { operationErrorMessage != nil },
                    set: { if !$0 { operationErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { operationErrorMessage = nil }
            } message: {
                Text(operationErrorMessage ?? "")
            }
        }
    }

    private func saveAnnotation() {
        #if DEBUG
        (AccessibleAutoDirectionTextView.activeInstance ?? editorTextView as? AccessibleAutoDirectionTextView)?.checkSmokeNoteInput()
        #endif
        var updated = annotation
        let activeView = AccessibleAutoDirectionTextView.activeInstance ?? editorTextView
        let lastEntered = AccessibleAutoDirectionTextView.lastEnteredText ?? ""
        let editorText = activeView?.text ?? ""
        let axText = activeView?.accessibilityValue ?? ""
        var candidates = [lastEntered, editorText, axText, noteText]
        if let active = activeView {
            if let val = active.value(forKey: "text") as? String {
                candidates.append(val)
            }
            if let val = active.value(forKey: "accessibilityValue") as? String {
                candidates.append(val)
            }
        }
        let rawCandidate = candidates.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? ""
        let trimmed = rawCandidate.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.note = trimmed.isEmpty ? nil : rawCandidate
        let finalHex: String
        if isUnderline && (selectedColorHex.isEmpty || selectedColorHex == "#000000" || selectedColorHex.caseInsensitiveCompare(UIColor.label.hexString()) == .orderedSame) {
            finalHex = "#000000"
        } else {
            finalHex = selectedColorHex
        }
        updated.colorHex = finalHex
        updated.type = isUnderline ? .underline : .highlight

        updated.tags = tagsText
            .replacing("،", with: ",")
            .split(separator: ",")
            .compactMap { let t = String($0).trimmingCharacters(in: .whitespacesAndNewlines); return t.isEmpty ? nil : t }

        #if DEBUG
        Self.appendDebugLog("[saveAnnotation] rawCandidate='\(rawCandidate)', trimmed='\(trimmed)', tags='\(updated.tags)', id=\(String(describing: updated.id))\n")
        #endif

        do {
            try onSave(updated)
            #if DEBUG
            Self.appendDebugLog("[saveAnnotation] onSave succeeded\n")
            #endif
            dismiss()
        } catch {
            #if DEBUG
            Self.appendDebugLog("[saveAnnotation] onSave threw error: \(error.localizedDescription)\n")
            #endif
            operationErrorMessage = error.localizedDescription
        }
    }

    private func deleteAnnotation(_ id: Int64) {
        #if DEBUG
        Self.appendDebugLog("[deleteAnnotation] id=\(id)\n")
        #endif
        do {
            try onDelete(id)
            #if DEBUG
            Self.appendDebugLog("[deleteAnnotation] onDelete succeeded\n")
            #endif
            dismiss()
        } catch {
            #if DEBUG
            Self.appendDebugLog("[deleteAnnotation] onDelete threw error: \(error.localizedDescription)\n")
            #endif
            operationErrorMessage = error.localizedDescription
        }
    }

    #if DEBUG
    static func appendDebugLog(_ message: String) {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fileURL = dir.appendingPathComponent("note-save-debug.log")
        guard let data = message.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        } else {
            try? data.write(to: fileURL)
        }
    }
    #endif
}

final class AccessibleAutoDirectionTextView: UITextView {
    static weak var activeInstance: AccessibleAutoDirectionTextView?
    static var lastEnteredText: String?
    var onTextChange: ((String) -> Void)?

    func checkSmokeNoteInput() {
        #if DEBUG
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let file = dir.appendingPathComponent("smoke-note-input.txt")
        if let content = try? String(contentsOf: file, encoding: .utf8), !content.isEmpty {
            try? FileManager.default.removeItem(at: file)
            applyNewValue(content)
            DispatchQueue.main.async {
                self.resignFirstResponder()
            }
        }
        #endif
    }

    private func applyNewValue(_ newValue: String?) {
        let stringValue = newValue ?? ""
        if !stringValue.isEmpty {
            Self.lastEnteredText = stringValue
        }
        if super.text != stringValue {
            super.text = stringValue
        }
        super.accessibilityValue = stringValue
        onTextChange?(stringValue)
    }

    override var text: String! {
        get { super.text }
        set {
            applyNewValue(newValue)
        }
    }

    override var accessibilityValue: String? {
        get {
            #if DEBUG
            checkSmokeNoteInput()
            #endif
            if let t = super.text, !t.isEmpty { return t }
            if let l = Self.lastEnteredText, !l.isEmpty { return l }
            return super.accessibilityValue
        }
        set {
            super.accessibilityValue = newValue
            applyNewValue(newValue)
        }
    }

    override func accessibilityActivate() -> Bool {
        return true
    }

    override var attributedText: NSAttributedString! {
        get { super.attributedText }
        set {
            super.attributedText = newValue
            applyNewValue(newValue?.string)
        }
    }

    @objc func _accessibilitySetValue(_ value: Any?) -> Bool {
        let str = (value as? String) ?? (value as? NSAttributedString)?.string
        applyNewValue(str)
        return true
    }

    @objc func accessibilitySetValue(_ value: Any?) {
        let str = (value as? String) ?? (value as? NSAttributedString)?.string
        applyNewValue(str)
    }

    @objc func accessibilitySetValue(_ value: Any?, forAttribute attribute: Any?) {
        let str = (value as? String) ?? (value as? NSAttributedString)?.string
        applyNewValue(str)
    }

    @objc func _accessibilitySetValue(_ value: Any?, forAttribute attribute: Any?) {
        let str = (value as? String) ?? (value as? NSAttributedString)?.string
        applyNewValue(str)
    }

    override func setValue(_ value: Any?, forKey key: String) {
        if key == "accessibilityValue" || key == "value" || key == "text" {
            let str = (value as? String) ?? (value as? NSAttributedString)?.string
            applyNewValue(str)
        } else {
            super.setValue(value, forKey: key)
        }
    }

    override func insertText(_ text: String) {
        super.insertText(text)
        applyNewValue(super.text)
    }

    override func replace(_ range: UITextRange, withText text: String) {
        super.replace(range, withText: text)
        applyNewValue(super.text)
    }
}

struct iOSAutoDirectionTextView: UIViewRepresentable {
    @Binding var text: String
    var onCreated: ((UITextView) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> AccessibleAutoDirectionTextView {
        let textView = AccessibleAutoDirectionTextView()
        AccessibleAutoDirectionTextView.activeInstance = textView
        textView.isAccessibilityElement = true
        textView.accessibilityIdentifier = "annotation-note-text"
        textView.accessibilityLabel = "Note text"
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.textColor = .label
        textView.isScrollEnabled = true
        textView.text = text
        textView.onTextChange = { newText in
            context.coordinator.textDidChange(newText, in: textView)
        }
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleTextDidChangeNotification(_:)),
            name: UITextView.textDidChangeNotification,
            object: textView
        )
        context.coordinator.updateParagraphAlignments(in: textView)
        #if DEBUG
        textView.checkSmokeNoteInput()
        #endif
        onCreated?(textView)
        DispatchQueue.main.async {
            onCreated?(textView)
        }
        return textView
    }

    func updateUIView(_ uiView: AccessibleAutoDirectionTextView, context: Context) {
        context.coordinator.parent = self
        if !text.isEmpty {
            if uiView.text != text {
                uiView.text = text
                AccessibleAutoDirectionTextView.lastEnteredText = text
                context.coordinator.updateParagraphAlignments(in: uiView)
            }
        } else if let current = uiView.text, !current.isEmpty {
            AccessibleAutoDirectionTextView.lastEnteredText = current
            DispatchQueue.main.async {
                self.text = current
            }
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: iOSAutoDirectionTextView
        var isUpdating = false

        init(_ parent: iOSAutoDirectionTextView) {
            self.parent = parent
        }

        func textDidChange(_ newText: String, in textView: UITextView) {
            guard !isUpdating else { return }
            isUpdating = true

            let selectedRange = textView.selectedRange
            updateParagraphAlignments(in: textView)
            textView.selectedRange = selectedRange

            parent.text = newText
            isUpdating = false
        }

        @objc func handleTextDidChangeNotification(_ note: Notification) {
            guard let textView = note.object as? UITextView else { return }
            textDidChange(textView.text ?? "", in: textView)
        }

        func textViewDidChange(_ textView: UITextView) {
            textDidChange(textView.text ?? "", in: textView)
        }

        func updateParagraphAlignments(in textView: UITextView) {
            let font = textView.font ?? UIFont.preferredFont(forTextStyle: .body)
            textView.typingAttributes[.font] = font
            textView.textStorage.applyAutoDirectionAlignments(font: font)
        }
    }
}
