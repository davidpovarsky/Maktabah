    private func setEditingAnnotation(_ value: Annotation?) {
        nativePhoneTOCAttachment.originalStateWillChange()
        // One identity per original sheet entry, including reopening the same
        // unsaved value. Callback closures capture this value, never a live getter.
        if value != nil {
            let presentationID = UUID()
            if usesNativeStudySheet {
                guard nativeStudyPresentation.beginNote(id: presentationID) else { return }
            } else {
                // The compact inspector is already a system sheet. Its note
                // editor must be owned by that sheet, not a sibling presenter.
                fallbackNoteHost = showPanelSheet ? .compactStudy : .reader
            }
            nativeNoteEditorPresentationID = presentationID
        }
        editingAnnotation = value
    }
    private func setNoteErrorMessage(_ value: String?) {
        nativePhoneTOCAttachment.originalStateWillChange()
        noteErrorMessage = value
    }
