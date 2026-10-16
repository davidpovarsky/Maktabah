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
                    let isRTL = noteText.isParagraphRTL
                    TextEditor(text: $noteText)
                        .frame(minHeight: 100)
                        .multilineTextAlignment(isRTL ? .trailing : .leading)
                        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                        .accessibilityIdentifier("annotation-note-text")
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

                if let annotationID = annotation.id {
                    ThemeSection {
                        Button(role: .destructive, action: {
                            do {
                                try onDelete(annotationID)
                                dismiss()
                            } catch {
                                operationErrorMessage = error.localizedDescription
                            }
                        }) {
                            HStack {
                                Spacer()
                                Text("Delete Annotation")
                                Spacer()
                            }
                        }
                        .accessibilityIdentifier("annotation-delete")
                    }
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAnnotation()
                    }
                    .accessibilityIdentifier("annotation-save-toolbar")
                    .accessibilityLabel("Save")
                }
            }
            .onAppear {
                noteText = annotation.note ?? ""
                selectedColorHex = annotation.colorHex
                isUnderline = annotation.type == .underline
                tagsText = annotation.tags.joined(separator: ", ")
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
        var updated = annotation
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.note = trimmed.isEmpty ? nil : noteText
        updated.colorHex = isUnderline ? UIColor.black.hexString() : selectedColorHex
        updated.type = isUnderline ? .underline : .highlight

        updated.tags = tagsText
            .replacingOccurrences(of: "،", with: ",")
            .split(separator: ",")
            .compactMap { let t = String($0).trimmingCharacters(in: .whitespacesAndNewlines); return t.isEmpty ? nil : t }

        do {
            try onSave(updated)
            dismiss()
        } catch {
            operationErrorMessage = error.localizedDescription
        }
    }
}
