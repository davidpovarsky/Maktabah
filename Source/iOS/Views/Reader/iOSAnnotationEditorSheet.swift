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

    let defaultColors: [UIColor] = [
        UIColor(named: "HighlightText") ?? .yellow,
        UIColor.magenta,
        UIColor.systemPink,
        UIColor.systemPurple,
        UIColor.systemIndigo,
        UIColor.systemGreen,
    ]

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

                    if !isUnderline {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(defaultColors, id: \.self) { color in
                                    let hex = color.hexString()
                                    Circle()
                                        .fill(Color(color))
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: selectedColorHex == hex ? 2 : 0)
                                        )
                                        .onTapGesture {
                                            selectedColorHex = hex
                                        }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                ThemeSection("Tags (comma separated)") {
                    let isRTL = tagsText.isParagraphRTL
                    TextField("tag1, tag2...", text: $tagsText)
                        .multilineTextAlignment(isRTL ? .trailing : .leading)
                        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                }
            }
            .navigationTitle("Edit Annotation")
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
                selectedColorHex = annotation.colorHex
                isUnderline = annotation.type == .underline
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
        updated.colorHex = isUnderline ? UIColor.black.hexString() : selectedColorHex
        updated.type = isUnderline ? .underline : .highlight

        updated.tags = tagsText
            .replacingOccurrences(of: "،", with: ",")
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
