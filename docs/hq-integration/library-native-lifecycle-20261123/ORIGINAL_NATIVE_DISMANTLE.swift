    static func dismantleUIView(_ field: PaletteTextField, coordinator: Coordinator) {
        #if DEBUG
        field.recordEscapeObservation(.dismantleBefore)
        #endif
        field.delegate = nil
        field.onEscape = nil
        field.onUp = nil
        field.onDown = nil
        field.resignFirstResponder()
        #if DEBUG
        field.recordEscapeObservation(.dismantleAfter)
        #endif
    }
