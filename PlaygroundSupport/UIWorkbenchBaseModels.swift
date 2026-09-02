import Foundation

public enum ViewModelState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
}

enum LibraryFilterMode: Int {
    case all
    case favorites
    case history
    case downloaded
}

enum SearchMode: Int, CaseIterable, Identifiable {
    case phrase
    case contains
    case or

    var id: Int { rawValue }
}

enum RowiDisplayMode: Int, CaseIterable, Identifiable {
    case tilmidz = 0
    case syaikh = 1
    case takdil = 2
    case mulakhosh = 3

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .tilmidz: "التلاميذ"
        case .syaikh: "الشيوخ"
        case .takdil: "الجرح والتعديل"
        case .mulakhosh: "ملخص"
        }
    }
}

enum AnnotationSearchScope: Int, CaseIterable, Identifiable, Sendable {
    case all = 0
    case book = 1
    case context = 2
    case note = 3
    case tag = 4

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .all: "All".localized
        case .book: "Book".localized
        case .context: "Context".localized
        case .note: "Note".localized
        case .tag: "Tag".localized
        }
    }
}

struct SwiftUIAnnotationNode: Identifiable {
    let id: String
    let title: String
    let kind: AnnotationNodeKind
    let annotation: Annotation?
    var children: [SwiftUIAnnotationNode]?

    init(
        id: String,
        title: String,
        kind: AnnotationNodeKind,
        annotation: Annotation?,
        children: [SwiftUIAnnotationNode]? = nil
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.annotation = annotation
        self.children = children
    }

    static func id(from node: AnnotationNode) -> String {
        if node.kind == .annotation,
           let annotation = node.annotation,
           let annotationId = annotation.id {
            return "ann-\(annotationId)"
        }
        return "group-\(node.kind)-\(node.title)"
    }

    init(from node: AnnotationNode, parentId: String? = nil) {
        let baseId = Self.id(from: node)
        id = parentId != nil && node.kind == .annotation ? "\(parentId!)-\(baseId)" : baseId
        title = node.title
        kind = node.kind
        annotation = node.annotation
        children = node.children.isEmpty
            ? nil
            : node.children.map { SwiftUIAnnotationNode(from: $0, parentId: id) }
    }
}

enum AnnotationChangeType {
    case added
    case updated
    case deleted
}

enum AnnotationNotificationKeys {
    static let annotation = "annotation"
    static let annotationId = "annotationId"
    static let tagDiff = "tagDiff"
    static let oldParentIndex = "oldParentIndex"
    static let newParentIndex = "newParentIndex"
    static let changeType = "changeType"
}

struct TagUpdateDiff {
    struct Entry {
        let tagNode: AnnotationNode
        let annotationNode: AnnotationNode
        let tagNodeBecomesEmpty: Bool
    }

    var removed: [Entry] = []
    var added: [Entry] = []
    var updated: [AnnotationNode] = []
}

struct PlaygroundHighlightPattern {
    let combinedPattern: String
}

struct PlaygroundOfflineBookMetadata {}
struct PlaygroundOfflineAuthorRow {}

final class PlaygroundHistoryEntry {
    var lastContentId: Int?
    init(lastContentId: Int? = nil) { self.lastContentId = lastContentId }
}
