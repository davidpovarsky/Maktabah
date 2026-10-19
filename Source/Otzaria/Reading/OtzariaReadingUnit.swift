import Foundation

struct OtzariaReadingUnit: Identifiable, Equatable {
    let id: String
    let bookId: Int
    let mode: OtzariaUnitMode
    let tocEntryId: Int?
    let title: String?
    let level: Int?
    let startLineIndex: Int
    let endLineIndex: Int
    let sourceLineIndices: [Int]
    let lineAnchors: [OtzariaLineAnchor]
    let html: String
    let plainText: String
    let heRef: String?

    init(
        id: String,
        bookId: Int,
        mode: OtzariaUnitMode = .paragraph,
        tocEntryId: Int?,
        title: String?,
        level: Int?,
        startLineIndex: Int,
        endLineIndex: Int,
        sourceLineIndices: [Int],
        lineAnchors: [OtzariaLineAnchor],
        html: String,
        plainText: String,
        heRef: String?
    ) {
        self.id = id
        self.bookId = bookId
        self.mode = mode
        self.tocEntryId = tocEntryId
        self.title = title
        self.level = level
        self.startLineIndex = startLineIndex
        self.endLineIndex = endLineIndex
        self.sourceLineIndices = sourceLineIndices
        self.lineAnchors = lineAnchors
        self.html = html
        self.plainText = plainText
        self.heRef = heRef
    }
}

struct OtzariaUnitLevelOption: Identifiable, Equatable {
    let id: String
    let title: String
    let level: Int?
    let mode: OtzariaUnitMode
}

public enum OtzariaUnitMode: String, Equatable, Codable, Sendable {
    case line
    case paragraph
    case chapter

    public var storageValue: String {
        switch self {
        case .line: return "line"
        case .paragraph: return "paragraph"
        case .chapter: return "chapter"
        }
    }

    public init(storageValue: String) {
        switch storageValue {
        case "line", "sourceLine":
            self = .line
        case "chapter":
            self = .chapter
        case "paragraph", "leaf", "automatic":
            self = .paragraph
        default:
            if storageValue.hasPrefix("tocLevel:") {
                self = .chapter
            } else {
                self = .paragraph
            }
        }
    }
}

#if os(iOS)
extension ReaderViewModel {
    var otzariaAvailableUnitModes: [OtzariaUnitLevelOption] {
        guard OtzariaBackendActivation.isActive,
              let currentBook else {
            return []
        }
        return OtzariaMaktabahBridge.shared.getAvailableReadingUnitModes(bookId: currentBook.id)
    }

    var otzariaUnitMode: OtzariaUnitMode {
        get { OtzariaMaktabahBridge.shared.currentReadingUnitMode }
        set { OtzariaMaktabahBridge.shared.currentReadingUnitMode = newValue }
    }

    func setOtzariaUnitMode(_ mode: OtzariaUnitMode) {
        guard OtzariaBackendActivation.isActive,
              let currentBook else {
            return
        }

        let anchorLineIndex = currentContentId
        otzariaUnitMode = mode

        OtzariaFileLogger.shared.log(
            "[ReaderViewModel] set unit mode bookId=\(currentBook.id) mode=\(mode.storageValue) anchorLineIndex=\(anchorLineIndex)"
        )

        guard let content = bookConnection.getContent(
            bkid: String(currentBook.id),
            contentId: anchorLineIndex
        ) else {
            OtzariaFileLogger.shared.log(
                "[ReaderViewModel] set unit mode reload failed bookId=\(currentBook.id) mode=\(mode.storageValue) anchorLineIndex=\(anchorLineIndex)"
            )
            return
        }

        updateContentState(with: content)
    }
}
#endif
