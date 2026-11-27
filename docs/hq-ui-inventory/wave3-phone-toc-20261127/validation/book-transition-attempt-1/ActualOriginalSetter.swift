    var selectedBook: BooksData? {
        willSet {
            // Original presentation ownership metadata. Every setter, including
            // an equal-value write, advances; exhaustion can never recycle it.
            if let revision = selectedBookPresentationRevision, revision < .max {
                selectedBookPresentationRevision = revision + 1
            } else {
                selectedBookPresentationRevision = nil
            }
        }
        didSet { selectedBookPresentationMode = selectedBook.map { _ in currentMode } }
    }
    private(set) var selectedBookPresentationRevision: UInt64? = 0
    private(set) var selectedBookPresentationMode: AppMode?
