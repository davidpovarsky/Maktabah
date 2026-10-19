import Foundation

public struct OtzariaReadingUnitDescriptor: Sendable, Hashable, Identifiable {
    public let id: String
    public let bookId: Int
    public let mode: OtzariaUnitMode
    public let includeDescendants: Bool
    public let tocEntryId: Int?
    public let title: String?
    public let level: Int?
    public let startLineIndex: Int
    public let endLineIndex: Int
    public let sourceLineIndices: [Int]
    public let heRef: String?
    public let previousStartLineIndex: Int?
    public let nextStartLineIndex: Int?

    public init(
        id: String,
        bookId: Int,
        mode: OtzariaUnitMode = .paragraph,
        includeDescendants: Bool = false,
        tocEntryId: Int?,
        title: String?,
        level: Int?,
        startLineIndex: Int,
        endLineIndex: Int,
        sourceLineIndices: [Int],
        heRef: String?,
        previousStartLineIndex: Int? = nil,
        nextStartLineIndex: Int? = nil
    ) {
        self.id = id
        self.bookId = bookId
        self.mode = mode
        self.includeDescendants = includeDescendants
        self.tocEntryId = tocEntryId
        self.title = title
        self.level = level
        self.startLineIndex = startLineIndex
        self.endLineIndex = endLineIndex
        self.sourceLineIndices = sourceLineIndices
        self.heRef = heRef
        self.previousStartLineIndex = previousStartLineIndex
        self.nextStartLineIndex = nextStartLineIndex
    }

    public func withNavigation(
        previousStartLineIndex: Int?,
        nextStartLineIndex: Int?
    ) -> OtzariaReadingUnitDescriptor {
        OtzariaReadingUnitDescriptor(
            id: id,
            bookId: bookId,
            mode: mode,
            includeDescendants: includeDescendants,
            tocEntryId: tocEntryId,
            title: title,
            level: level,
            startLineIndex: startLineIndex,
            endLineIndex: endLineIndex,
            sourceLineIndices: sourceLineIndices,
            heRef: heRef,
            previousStartLineIndex: previousStartLineIndex,
            nextStartLineIndex: nextStartLineIndex
        )
    }
}
