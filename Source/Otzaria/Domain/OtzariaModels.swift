import Foundation

struct OtzariaLibraryCategory: Identifiable, Hashable, Sendable {
    let id: Int
    let parentId: Int?
    let title: String
    let level: Int
    let orderIndex: Int
}

struct OtzariaBook: Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let categoryId: Int
    let orderIndex: Int
    let totalLines: Int
    let shortDescription: String?
    let filePath: String?
    let fileType: String?
    let isBaseBook: Bool
    let hasTeamim: Bool
    let hasNekudot: Bool
    let hasLinks: Bool

    var subtitle: String {
        if let shortDescription, !shortDescription.isEmpty {
            return shortDescription
        }
        if totalLines > 0 {
            return "\(totalLines) שורות"
        }
        return filePath ?? ""
    }
}

struct OtzariaAuthor: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let bookCount: Int
}

struct OtzariaBookLine: Identifiable, Hashable, Sendable {
    let id: Int
    let bookId: Int
    let lineIndex: Int
    let content: String
    let heRef: String?

    var text: String { content.otsariaPlainText }
    var isHeading: Bool { content.otsariaLooksLikeHTMLHeading }
}

struct OtzariaTOCEntry: Identifiable, Hashable, Sendable {
    let id: Int
    let bookId: Int
    let parentId: Int?
    let title: String
    let level: Int
    let lineId: Int?
    let lineIndex: Int?
    let hasChildren: Bool

    var menuTitle: String {
        String(repeating: "  ", count: max(0, min(level, 4))) + title
    }
}

struct OtzariaLinkedSource: Identifiable, Hashable, Sendable {
    let id: Int
    let connectionType: String
    let linkedLineId: Int
    let linkedBookId: Int
    let linkedLineIndex: Int
    let bookTitle: String
    let bookPath: String?
    let linkedCategoryId: Int?
    let linkedCategoryPath: [String]
    let linkedBookOrderIndex: Int?
    let heRef: String?
    let content: String
    let rawConnectionType: String
    let matchedSide: Int
    let sourceBookId: Int
    let targetBookId: Int
    let linkedBookIsBaseBook: Bool
    let linkedBookDependenceType: String?

    init(
        id: Int,
        connectionType: String,
        linkedLineId: Int,
        linkedBookId: Int,
        linkedLineIndex: Int,
        bookTitle: String,
        bookPath: String?,
        linkedCategoryId: Int?,
        linkedCategoryPath: [String],
        linkedBookOrderIndex: Int?,
        heRef: String?,
        content: String,
        rawConnectionType: String? = nil,
        matchedSide: Int = 0,
        sourceBookId: Int? = nil,
        targetBookId: Int? = nil,
        linkedBookIsBaseBook: Bool = false,
        linkedBookDependenceType: String? = nil
    ) {
        self.id = id
        self.connectionType = connectionType
        self.linkedLineId = linkedLineId
        self.linkedBookId = linkedBookId
        self.linkedLineIndex = linkedLineIndex
        self.bookTitle = bookTitle
        self.bookPath = bookPath
        self.linkedCategoryId = linkedCategoryId
        self.linkedCategoryPath = linkedCategoryPath
        self.linkedBookOrderIndex = linkedBookOrderIndex
        self.heRef = heRef
        self.content = content
        self.rawConnectionType = rawConnectionType ?? connectionType
        self.matchedSide = matchedSide
        self.sourceBookId = sourceBookId ?? (matchedSide == 0 ? 0 : linkedBookId)
        self.targetBookId = targetBookId ?? (matchedSide == 0 ? linkedBookId : 0)
        self.linkedBookIsBaseBook = linkedBookIsBaseBook
        self.linkedBookDependenceType = linkedBookDependenceType
    }

    var text: String { content.otsariaPlainText }

    var localizedConnectionType: String {
        switch connectionType {
        case "COMMENTARY": return "מפרשים"
        case "SOURCE": return "מקורות"
        case "TARGUM": return "תרגום"
        case "REFERENCE": return "מראי מקום"
        case "OTHER": return "אחר"
        default: return connectionType
        }
    }

    var systemImage: String {
        switch connectionType {
        case "COMMENTARY": return "text.quote"
        case "TARGUM": return "character.book.closed"
        case "REFERENCE": return "link"
        case "SOURCE": return "doc.text"
        default: return "arrow.triangle.branch"
        }
    }
}

struct OtzariaSourceSection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let items: [OtzariaLinkedSource]
}

struct OtzariaLibraryNode: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let systemImage: String
    let book: OtzariaBook?
    let children: [OtzariaLibraryNode]?

    var isBook: Bool { book != nil }
}
