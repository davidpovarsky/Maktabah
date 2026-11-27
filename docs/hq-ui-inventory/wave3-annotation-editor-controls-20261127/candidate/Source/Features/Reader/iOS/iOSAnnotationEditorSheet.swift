import SwiftUI

struct iOSAnnotationEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State var annotation: Annotation
    let onSave: (Annotation) throws -> Void
    let onDelete: (Int64) throws -> Void
    // Passive host observation only; Save/Cancel and persistence stay here.
    var onNativeTextView: ((UITextView?) -> Void)? = nil
    // Host-owned visibility observation mounts on the actual editor Form.
    // The editor's default presentation, editing and persistence remain unchanged.
    var nativeSurface: (@MainActor () -> AnyView)? = nil
    // Optional same-scene original List ownership; other presenters keep nil.
    var nativeControls: MaktabahNativeAnnotationEditorControls.Attachment? = nil
    @State private var nativeEditorViewID = UUID()
    @FocusState private var nativeTagsFocused: Bool

    @State private var noteText: String = ""
    @State private var selectedColorHex: String = ""
    @State private var isUnderline: Bool = false
    @State private var tagsText: String = ""
    @State private var operationErrorMessage: String?
    @State private var editorTextView: UITextView?
    @State private var hasInitialized: Bool = false
    @State private var hasRetainedMiniAppFiles = false
    #if os(iOS) && canImport(AnytypeOriginalEditor)
    @State private var originalEditorAvailability: AnnotationOriginalEditorAvailability = .checking
    @State private var originalEditorModal: AnnotationOriginalEditorModal?
    #endif

    private var allowsPlainEditing: Bool {
        #if os(iOS) && canImport(AnytypeOriginalEditor)
        AnnotationOriginalEditorProductionEntry.qualificationOwnsEntry
            || annotation.id == nil || originalEditorAvailability.allowsPlainEditing
        #else
        true
        #endif
    }
    @State private var miniAppsEditorID = UUID()

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
                    iOSAutoDirectionTextView(text: nativeEditorBinding($noteText), onCreated: {
                        nativeEditorStateWillChange()
                        self.editorTextView = $0
                        onNativeTextView?($0)
                    })
                        .frame(minHeight: 80)
                        .disabled(!allowsPlainEditing)
                        .modifier(MaktabahNativeAnnotationEditorControl(attachment: nativeControls,
                            viewID: nativeEditorViewID, anchor: .body, bodyTextView: { editorTextView }))
                }

                #if DEBUG && os(iOS) && targetEnvironment(simulator)
                AnnotationOriginalEditorQualificationEntry(annotation: annotation, draft: {
                    .init(noteText: noteText,
                          nativeText: editorTextView?.text,
                          lastEnteredText: AccessibleAutoDirectionTextView.lastEnteredText,
                          nativeEditorIsCurrent: editorTextView?.window != nil
                            && AccessibleAutoDirectionTextView.activeInstance === editorTextView,
                          selectedColorHex: selectedColorHex,
                          isUnderline: isUnderline, tagsText: tagsText)
                }, closeOriginalSheet: { nativeEditorStateWillChange(); dismiss() })
                #endif

                #if os(iOS) && canImport(AnytypeOriginalEditor)
                AnnotationOriginalEditorProductionEntry(annotation: annotation, draft: {
                    .init(text: noteText, nativeText: editorTextView?.text,
                          nativeEditorIsMounted: editorTextView?.window != nil,
                          selectedColorHex: selectedColorHex, isUnderline: isUnderline,
                          tagsText: tagsText)
                }, availability: nativeEditorBinding($originalEditorAvailability), present: { nativeEditorStateWillChange(); originalEditorModal = $0 })
                #endif

                ThemeSection {
                    Button(action: saveAnnotation) {
                        HStack {
                            Spacer()
                            Text("Save")
                                .bold()
                            Spacer()
                        }
                    }
                    .disabled(!allowsPlainEditing)
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

                    Button(role: .cancel, action: { nativeEditorStateWillChange(); dismiss() }) {
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
                    Toggle("Underline", isOn: nativeEditorBinding($isUnderline))
                        .modifier(MaktabahNativeAnnotationEditorControl(attachment: nativeControls,
                            viewID: nativeEditorViewID, anchor: .style))
                        .onChange(of: isUnderline) { _, newValue in
                            if newValue {
                                let underlineColor = UserDefaults.standard.recentUnderlineColors.first ?? .label
                                nativeEditorStateWillChange()
                                selectedColorHex = (underlineColor == .label) ? "#000000" : underlineColor.hexString()
                            } else {
                                let highlightColor = UserDefaults.standard.recentHighlightColors.first ?? .yellow
                                nativeEditorStateWillChange()
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
                                            nativeEditorStateWillChange()
                                            selectedColorHex = "#000000"
                                        } else {
                                            nativeEditorStateWillChange()
                                            selectedColorHex = color.hexString()
                                        }
                                    }
                            }
                        }
                        .padding(4)
                    }
                }

                .disabled(!allowsPlainEditing)

                ThemeSection("Tags (comma separated)") {
                    let isRTL = tagsText.isParagraphRTL
                    TextField("tag1, tag2...", text: nativeEditorBinding($tagsText))
                        .modifier(MaktabahNativeAnnotationEditorTagsFocus(enabled: nativeControls != nil,
                            focused: $nativeTagsFocused))
                        .modifier(MaktabahNativeAnnotationEditorControl(attachment: nativeControls,
                            viewID: nativeEditorViewID, anchor: .tags))
                        .multilineTextAlignment(isRTL ? .trailing : .leading)
                        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                }
                .disabled(!allowsPlainEditing)
                ThemeSection {
                    Button(role: .destructive, action: {
                        if let id = annotation.id {
                            nativeEditorStateWillChange()
                            try? onDelete(id)
                        }
                        nativeEditorStateWillChange(); dismiss()
                    }) {
                        HStack {
                            Spacer()
                            Text(.Annotation.deleteAnnotation)
                            Spacer()
                        }
                    }
                }
            }
            .background { nativeSurface?() }
            .modifier(MaktabahNativeAnnotationEditorForm(attachment: nativeControls,
                viewID: nativeEditorViewID, snapshot: {
                    .init(annotation: annotation, note: noteText, nativeNote: editorTextView?.text,
                        tags: tagsText, color: selectedColorHex, underline: isUnderline,
                        initialized: hasInitialized, allowsPlainEditing: allowsPlainEditing,
                        blocked: nativeEditorIsBlocked)
                }, bodyTextView: { editorTextView }, focusTags: { nativeTagsFocused = true }))
            .navigationTitle(.Annotation.editAnnotation)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if hasRetainedMiniAppFiles {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            nativeEditorStateWillChange()
                            OtzariaMiniAppsCoordinator.shared.shareRetainedFiles(
                                for: annotation, sourceView: editorTextView)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier("otzaria-note-share-files")
                        .accessibilityLabel(String(localized: "Share Mini App Files"))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        nativeEditorStateWillChange()
                        OtzariaMiniAppsCoordinator.shared.showEditor(annotation: annotation,
                            draft: editorTextView?.text ?? noteText,
                            selection: editorTextView?.selectedRange,
                            editorID: miniAppsEditorID, textView: editorTextView)
                    } label: {
                        Image(systemName: "square.grid.2x2")
                    }
                    .disabled(!allowsPlainEditing)
                    .accessibilityIdentifier("otzaria-note-miniapps")
                    .accessibilityLabel(String(localized: "Mini Apps"))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        nativeEditorStateWillChange(); dismiss()
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
                    .disabled(!allowsPlainEditing)
                    .accessibilityIdentifier("annotation-save-toolbar")
                    .accessibilityLabel("Save")
                }
            }
            #if os(iOS) && canImport(AnytypeOriginalEditor)
            // Own the expanded editor at the sheet root so scrolling or
            // removing a row from the Form cannot end its presentation.
            .fullScreenCover(item: nativeEditorBinding($originalEditorModal), onDismiss: { nativeEditorStateWillChange(); dismiss() }) { modal in
                modal.content.interactiveDismissDisabled(true)
            }
            #endif
            .onAppear {
                OtzariaMiniAppsCoordinator.shared.registerEditor(id: miniAppsEditorID,
                    currentText: { editorTextView?.window == nil ? nil : editorTextView?.text ?? noteText },
                    didCommit: { saved in
                        nativeEditorStateWillChange()
                        annotation = saved
                        hasRetainedMiniAppFiles = OtzariaMiniAppsCoordinator.shared.hasRetainedFiles(for: saved)
                        nativeEditorStateWillChange()
                        noteText = saved.note ?? ""
                        AccessibleAutoDirectionTextView.lastEnteredText = noteText
                        nativeEditorStateWillChange()
                        editorTextView?.text = noteText
                    })
                hasRetainedMiniAppFiles = OtzariaMiniAppsCoordinator.shared.hasRetainedFiles(for: annotation)
                guard !hasInitialized else { return }
                nativeEditorStateWillChange()
                hasInitialized = true
                nativeEditorStateWillChange()
                noteText = annotation.note ?? ""
                nativeEditorStateWillChange()
                isUnderline = annotation.type == .underline
                nativeEditorStateWillChange()
                selectedColorHex = annotation.colorHex
                if isUnderline && (selectedColorHex.isEmpty || selectedColorHex == "#000000") {
                    nativeEditorStateWillChange()
                    selectedColorHex = "#000000"
                }
                nativeEditorStateWillChange()
                tagsText = annotation.tags.joined(separator: ", ")
                AccessibleAutoDirectionTextView.lastEnteredText = annotation.note
                #if DEBUG
                (editorTextView as? AccessibleAutoDirectionTextView)?.checkSmokeNoteInput()
                #endif
            }
            .onReceive(NotificationCenter.default.publisher(for: .torahInspectorNotesDidChange)) { _ in
                hasRetainedMiniAppFiles = OtzariaMiniAppsCoordinator.shared.hasRetainedFiles(for: annotation)
            }
            .onDisappear {
                nativeEditorStateWillChange()
                OtzariaMiniAppsCoordinator.shared.unregisterEditor(id: miniAppsEditorID)
                onNativeTextView?(nil)
                if AccessibleAutoDirectionTextView.activeInstance === editorTextView {
                    AccessibleAutoDirectionTextView.activeInstance = nil
                }
            }
            .alert(
                String(localized: "Could Not Save Annotation"),
                isPresented: Binding(
                    get: { operationErrorMessage != nil },
                    set: { if !$0 { nativeEditorStateWillChange(); operationErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { nativeEditorStateWillChange(); operationErrorMessage = nil }
            } message: {
                Text(operationErrorMessage ?? "")
            }
        }
    }

    private var nativeEditorIsBlocked: Bool {
        #if os(iOS) && canImport(AnytypeOriginalEditor)
        operationErrorMessage != nil || originalEditorModal != nil
        #else
        operationErrorMessage != nil
        #endif
    }
    private func nativeEditorStateWillChange() {
        nativeControls?.controls.originalStateWillChange(viewID: nativeEditorViewID)
    }
    private func nativeEditorBinding<Value>(_ original: Binding<Value>) -> Binding<Value> {
        guard nativeControls != nil else { return original }
        return Binding(get: { original.wrappedValue }, set: {
            nativeEditorStateWillChange()
            original.wrappedValue = $0
        })
    }

    private func saveAnnotation() {
        nativeEditorStateWillChange()
        guard allowsPlainEditing else {
            nativeEditorStateWillChange()
            operationErrorMessage = String(localized: "Use the expanded editor to change this formatted note.",
                                           table: "OriginalAnnotationEditor")
            return
        }
        #if DEBUG
        (editorTextView as? AccessibleAutoDirectionTextView)?.checkSmokeNoteInput()
        #endif
        var updated = annotation
        // Empty input is an intentional edit. Only this sheet's native text
        // and binding own its draft; another window's global focus/AX state
        // must never choose the note body that is committed here.
        let rawCandidate = editorTextView?.text ?? noteText
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
            nativeEditorStateWillChange(); dismiss()
        } catch {
            #if DEBUG
            Self.appendDebugLog("[saveAnnotation] onSave threw error: \(error.localizedDescription)\n")
            #endif
            nativeEditorStateWillChange()
            operationErrorMessage = error.localizedDescription
        }
    }

    private func deleteAnnotation(_ id: Int64) {
        nativeEditorStateWillChange()
        #if DEBUG
        Self.appendDebugLog("[deleteAnnotation] id=\(id)\n")
        #endif
        do {
            try onDelete(id)
            #if DEBUG
            Self.appendDebugLog("[deleteAnnotation] onDelete succeeded\n")
            #endif
            nativeEditorStateWillChange(); dismiss()
        } catch {
            #if DEBUG
            Self.appendDebugLog("[deleteAnnotation] onDelete threw error: \(error.localizedDescription)\n")
            #endif
            nativeEditorStateWillChange()
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
        Self.lastEnteredText = stringValue
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
            // Accessibility describes this field, including a deliberate
            // empty value. Process-global text can belong to another window.
            return super.text ?? ""
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
        if uiView.text != text {
            uiView.text = text
            context.coordinator.updateParagraphAlignments(in: uiView)
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
