//
//  AnnotationManager.swift
//  maktab
//
//  Created by MacBook on 15/12/25.
//  Granular UI Update
//

import Foundation
import SQLite
import AppKit

// MARK: - Notification Names
extension Notification.Name {
    static let annotationDidChange = Notification.Name("annotationDidChange")
    static let annotationDidDeleteFromOutline = Notification.Name("annotationDeletedFromOutlineView")
    static let annotationTreeDidUpdate = Notification.Name("annotationTreeDidUpdate")
}

// MARK: - Notification UserInfo Keys
enum AnnotationChangeType: String {
    case added
    case updated
    case deleted
}

struct AnnotationNotificationKeys {
    static let changeType = "changeType"
    static let annotation = "annotation"
    static let annotationId = "annotationId"
}

final class AnnotationManager {

    // MARK: - Table & columns
    private(set) var annotationsTable = Table("annotations")
    private(set) var annId = Expression<Int64>("id")
    private(set) var annBkId = Expression<Int>("bkId")
    private(set) var annContentId = Expression<Int>("contentId")
    private(set) var annStart = Expression<Int>("startIndex")
    private(set) var annStartDiac = Expression<Int>("startIndexDiac")
    private(set) var annLength = Expression<Int>("length")
    private(set) var annLengthDiac = Expression<Int>("lengthDiac")
    private(set) var annColor = Expression<String>("color")
    private(set) var annType = Expression<Int>("type")
    private(set) var annNote = Expression<String?>("note")
    private(set) var annCreatedAt = Expression<Int64>("createdAt")
    private(set) var annContext = Expression<String>("context")
    private(set) var annPage = Expression<Int>("page")
    private(set) var annPart = Expression<Int>("part")
    private(set) var tagsTable = Table("tags")
    private(set) var tagId = Expression<Int64>("id")
    private(set) var tagName = Expression<String>("name")
    private(set) var tagNormalizedName = Expression<String>("normalizedName")
    private(set) var annotationTagsTable = Table("annotation_tags")
    private(set) var annotationTagAnnotationId = Expression<Int64>("annotationId")
    private(set) var annotationTagTagId = Expression<Int64>("tagId")

    private(set) var db: Connection?

    static let shared = AnnotationManager()

    // MARK: - Caches
    private var cacheById: [Int64: Annotation] = [:]
    private var cacheByContent: [ContentKey: [Annotation]] = [:]
    private var cacheTagsByAnnotationId: [Int64: [String]] = [:]
    private var cachedAllTagNames: [String]? = nil

    private var _rootNode: AnnotationNode?
    private let treeQueue = DispatchQueue(label: "com.maktab.annotationManager.treeQueue", qos: .userInitiated)

    var rootNode: AnnotationNode? {
        get {
            return treeQueue.sync { _rootNode }
        }
    }

    // State Sorting
    private(set) var sortOption: AnnotationSortOption = .init(field: .createdAt, isAscending: false)
    private(set) var groupingMode: AnnotationGroupingMode = .book

    // Serial queue to protect caches
    private let cacheQueue = DispatchQueue(label: "com.maktab.annotationManager.cacheQueue", qos: .userInitiated)

    private init() {}

    // MARK: - Private helper to post notification
    private func postChangeNotification(type: AnnotationChangeType, annotation: Annotation? = nil, annotationId: Int64? = nil) {
        var userInfo: [String: Any] = [AnnotationNotificationKeys.changeType: type.rawValue]

        if let ann = annotation {
            userInfo[AnnotationNotificationKeys.annotation] = ann
            if type != .deleted { pushRecentColor(ann) }
        }
        if let id = annotationId {
            userInfo[AnnotationNotificationKeys.annotationId] = id
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .annotationDidChange,
                object: self,
                userInfo: userInfo
            )
        }
    }

    private var dbURL: URL?
    
    func setupAnnotations(at folderURL: URL?) throws {
        guard let folderURL else { throw NSError(domain: "maktabah", code: 404) }
        
        let fm = FileManager.default
        
        if !fm.fileExists(atPath: folderURL.path) {
            try fm.createDirectory(
                at: folderURL,
                withIntermediateDirectories: true
            )
        }
        
        dbURL = folderURL.appendingPathComponent("Annotations.sqlite")
        connect()
        clearAllCaches()
        invalidateTree()
        try setupAnnotationsDatabase()
    }

    // MARK: - Setup DB in Application Support
    func setupAnnotationsDatabase() throws {
        try db?.run(annotationsTable.create(ifNotExists: true) { t in
            t.column(annId, primaryKey: .autoincrement)
            t.column(annBkId)
            t.column(annContentId)
            t.column(annStart)
            t.column(annLength)
            t.column(annStartDiac)
            t.column(annLengthDiac)
            t.column(annColor)
            t.column(annType)
            t.column(annNote)
            t.column(annCreatedAt)
            t.column(annContext)
            t.column(annPart)
            t.column(annPage)
        })
        
        try db?.run(annotationsTable.createIndex(
            annBkId, annContentId, ifNotExists: true
        ))

        try db?.run(tagsTable.create(ifNotExists: true) { t in
            t.column(tagId, primaryKey: .autoincrement)
            t.column(tagName)
            t.column(tagNormalizedName, unique: true)
        })

        try db?.run(annotationTagsTable.create(ifNotExists: true) { t in
            t.column(annotationTagAnnotationId)
            t.column(annotationTagTagId)
        })

        try db?.run(annotationTagsTable.createIndex(
            annotationTagAnnotationId,
            annotationTagTagId,
            unique: true,
            ifNotExists: true
        ))
    }
    
    func connect() {
        if let dbURL {
            do {
                db = try Connection(dbURL.path)
            } catch {
                ReusableFunc.showAlert(title: "Error", message: "")
            }
        }
    }

    // MARK: - Add annotation
    @discardableResult
    func addAnnotation(_ annotation: Annotation) throws -> Int64 {
        guard let db = db else { throw NSError(domain: "DBNil", code: 1) }
        var rowId: Int64 = 0
        try db.transaction {
            let insert = annotationsTable.insert(
                annBkId <- annotation.bkId,
                annContentId <- annotation.contentId,
                annStart <- annotation.range.location,
                annLength <- annotation.range.length,
                annStartDiac <- annotation.rangeDiacritics.location,
                annLengthDiac <- annotation.rangeDiacritics.length,
                annColor <- annotation.colorHex,
                annType <- annotation.type.rawValue,
                annNote <- annotation.note,
                annCreatedAt <- annotation.createdAt,
                annContext <- annotation.context,
                annPart <- annotation.part,
                annPage <- annotation.page
            )
            rowId = try db.run(insert)
            try self.replaceTags(self.sanitizeTagNames(annotation.tags), for: rowId, in: db)
        }

        // Update caches
        var saved = annotation
        saved.id = rowId
        saved.tags = sanitizeTagNames(annotation.tags)
        cacheQueue.sync {
            cacheById[rowId] = saved
            cacheTagsByAnnotationId[rowId] = saved.tags
            let key = ContentKey(bkId: saved.bkId, contentId: saved.contentId)
            var arr = cacheByContent[key] ?? []
            // Optimization using insertionIndex helper for basic range sort
            let idx = arr.insertionIndex(for: saved) { $0.range.location < $1.range.location }
            arr.insert(saved, at: idx)
            cacheByContent[key] = arr
        }

        addAnnotationToTree(saved)
        return rowId
    }

    // MARK: - Update annotation
    func updateAnnotation(_ annotation: Annotation) throws {
        guard let db = db else { throw NSError(domain: "DBNil", code: 1) }
        guard let id = annotation.id else { throw NSError(domain: "NoID", code: 2) }
        let row = annotationsTable.filter(annId == id)
        let normalizedTags = sanitizeTagNames(annotation.tags)
        try db.transaction {
            try db.run(row.update(
                annColor <- annotation.colorHex,
                annType <- annotation.type.rawValue,
                annNote <- annotation.note
            ))
            try self.replaceTags(normalizedTags, for: id, in: db)
        }

        // Update caches
        var updatedAnnotation = annotation
        updatedAnnotation.tags = normalizedTags
        cacheQueue.sync {
            cacheById[id] = updatedAnnotation
            cacheTagsByAnnotationId[id] = normalizedTags
            let key = ContentKey(bkId: updatedAnnotation.bkId, contentId: updatedAnnotation.contentId)
            var arr = cacheByContent[key] ?? []
            if let idx = arr.firstIndex(where: { $0.id == id }) {
                arr[idx] = updatedAnnotation
            } else {
                let idx = arr.insertionIndex(for: updatedAnnotation) { $0.range.location < $1.range.location }
                arr.insert(updatedAnnotation, at: idx)
            }
            cacheByContent[key] = arr
        }

        if groupingMode == .tag {
            buildAnnotationTree()
            postChangeNotification(type: .updated, annotation: updatedAnnotation)
        } else {
            updateAnnotationInTree(updatedAnnotation)
        }
    }

    // MARK: - Delete annotation
    func deleteAnnotation(id: Int64) throws {
        guard let db = db else { throw NSError(domain: "DBNil", code: 1) }

        // Get annotation before deleting (untuk notification)
        let annotationToDelete = loadAnnotationById(id)

        try db.transaction {
            let row = annotationsTable.filter(annId == id)
            try db.run(annotationTagsTable.filter(annotationTagAnnotationId == id).delete())
            try db.run(row.delete())
            try self.deleteUnusedTags(in: db)
        }

        // Update caches
        cacheQueue.sync {
            cacheById.removeValue(forKey: id)
            cacheTagsByAnnotationId.removeValue(forKey: id)
            for (key, anns) in cacheByContent {
                if let idx = anns.firstIndex(where: { $0.id == id }) {
                    var copy = anns
                    copy.remove(at: idx)
                    cacheByContent[key] = copy
                }
            }
        }

        removeAnnotationFromTree(id: id, deletedAnnotation: annotationToDelete)
    }

    // MARK: - Load annotations for a book content
    func loadAnnotations(bkId: Int, contentId: Int) -> [Annotation] {
        let key = ContentKey(bkId: bkId, contentId: contentId)

        if let cached = cacheQueue.sync(execute: { cacheByContent[key] }) {
            return cached
        }

        guard let db = db else { return [] }
        var result: [Annotation] = []
        do {
            let query = annotationsTable.filter(annBkId == bkId && annContentId == contentId).order(annStart)
            for row in try db.prepare(query) {
                let id = row[annId]
                let start = row[annStart]
                let length = row[annLength]
                let startDiac = row[annStartDiac]
                let lengthDiac = row[annLengthDiac]
                let color = row[annColor]
                let type = row[annType]
                let note = row[annNote]
                let created = row[annCreatedAt]
                let context = row[annContext]
                let page = row[annPage]
                let part = row[annPart]
                let ann = Annotation(
                    id: id,
                    bkId: bkId,
                    contentId: contentId,
                    range: NSRange(location: start, length: length),
                    rangeDiacritics: NSRange(location: startDiac, length: lengthDiac),
                    colorHex: color,
                    type: AnnotationMode.from(int: type),
                    note: note,
                    createdAt: created,
                    context: context,
                    page: page,
                    part: part,
                    pageArb: String(page).convertToArabicDigits(),
                    partArb: String(part).convertToArabicDigits(),
                    tags: loadTags(for: id)
                )
                result.append(ann)
            }

            cacheQueue.sync {
                cacheByContent[key] = result
                for ann in result {
                    if let id = ann.id { cacheById[id] = ann }
                }
            }
        } catch {
            print("loadAnnotations error:", error)
        }
        return result
    }

    // MARK: - Load single annotation by id
    func loadAnnotationById(_ id: Int64) -> Annotation? {
        if let cached = cacheQueue.sync(execute: { cacheById[id] }) {
            return cached
        }

        guard let db = db else { return nil }
        do {
            let query = annotationsTable.filter(annId == id)
            if let row = try db.pluck(query) {
                let page = row[annPage]
                let part = row[annPart]
                let ann = Annotation(
                    id: row[annId],
                    bkId: row[annBkId],
                    contentId: row[annContentId],
                    range: NSRange(location: row[annStart], length: row[annLength]),
                    rangeDiacritics: NSRange(location: row[annStartDiac], length: row[annLengthDiac]),
                    colorHex: row[annColor],
                    type: AnnotationMode.from(int: row[annType]),
                    note: row[annNote],
                    createdAt: row[annCreatedAt],
                    context: row[annContext],
                    page: page,
                    part: part,
                    pageArb: String(page).convertToArabicDigits(),
                    partArb: String(part).convertToArabicDigits(),
                    tags: loadTags(for: id)
                )
                cacheQueue.sync {
                    cacheById[id] = ann
                    let key = ContentKey(bkId: ann.bkId, contentId: ann.contentId)
                    var arr = cacheByContent[key] ?? []
                    if !arr.contains(where: { $0.id == ann.id }) {
                        let idx = arr.insertionIndex(for: ann) { $0.range.location < $1.range.location }
                        arr.insert(ann, at: idx)
                        cacheByContent[key] = arr
                    }
                }
                return ann
            }
        } catch {
            print("loadAnnotationById error:", error)
        }
        return nil
    }

    // MARK: - Cache helpers
    func clearAllCaches() {
        cacheQueue.sync {
            cacheById.removeAll()
            cacheByContent.removeAll()
            cacheTagsByAnnotationId.removeAll()
            cachedAllTagNames = nil
        }
    }

    // MARK: - DISPLAY ALL ANNOTATIONS
    func loadAnnotations() -> [Annotation] {
        guard let db = db else { return [] }
        var result: [Annotation] = []
        do {
            let query = annotationsTable.order(annStart)
            for row in try db.prepare(query) {
                let id = row[annId]
                let bkId = row[annBkId]
                let start = row[annStart]
                let length = row[annLength]
                let startDiac = row[annStartDiac]
                let lengthDiac = row[annLengthDiac]
                let contentId = row[annContentId]
                let color = row[annColor]
                let type = row[annType]
                let note = row[annNote]
                let created = row[annCreatedAt]
                let page = row[annPage]
                let part = row[annPart]
                let ann = Annotation(
                    id: id,
                    bkId: bkId,
                    contentId: contentId,
                    range: NSRange(location: start, length: length),
                    rangeDiacritics: NSRange(location: startDiac, length: lengthDiac),
                    colorHex: color,
                    type: AnnotationMode.from(int: type),
                    note: note,
                    createdAt: created,
                    context: row[annContext],
                    page: page,
                    part: part,
                    pageArb: String(page).convertToArabicDigits(),
                    partArb: String(part).convertToArabicDigits(),
                    tags: loadTags(for: id)
                )
                result.append(ann)
            }
        } catch {
            print("loadAnnotations error:", error)
        }
        return result
    }

    // MARK: - Build Tree
    func buildAnnotationTree() {
        treeQueue.async { [weak self] in
            guard let self = self else { return }

            let root = AnnotationNode(title: "All Annotations", kind: .root)
            let anns = self.loadAnnotations()
            switch self.groupingMode {
            case .book:
                self.populateBookTree(root: root, annotations: anns)
            case .tag:
                self.populateTagTree(root: root, annotations: anns)
            }

            self.sortNodeChildren(root)

            self._rootNode = root

            // Post notification bahwa tree sudah ready
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .annotationTreeDidUpdate,
                    object: self
                )
            }
        }
    }

    // MARK: - Tree Manipulation
    func updateSorting(field: AnnotationSortField, isAscending: Bool) {
        treeQueue.async { [weak self] in
            guard let self = self else { return }
            self.sortOption = .init(field: field, isAscending: isAscending)
            guard let root = self._rootNode else { return }
            self.sortNodeChildren(root)
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .annotationTreeDidUpdate, object: self)
            }
        }
    }

    private func sortNodeChildren(_ node: AnnotationNode) {
        if !node.children.isEmpty {
            node.children.sort(by: compareNodes)
        }
        for child in node.children {
            sortNodeChildren(child)
        }
    }

    private func compareNodes(_ lhs: AnnotationNode, _ rhs: AnnotationNode) -> Bool {
        // KASUS 1: Anotasi (Item di dalam buku)
        if let left = lhs.annotation, let right = rhs.annotation {
            let orderedAscending: Bool
            switch sortOption.field {
            case .createdAt:
                orderedAscending = left.createdAt == right.createdAt 
                    ? left.context.localizedCaseInsensitiveCompare(right.context) == .orderedAscending
                    : left.createdAt < right.createdAt
            case .context:
                let contextOrder = left.context.localizedCaseInsensitiveCompare(right.context)
                orderedAscending = contextOrder == .orderedSame 
                    ? left.createdAt < right.createdAt 
                    : contextOrder == .orderedAscending
            case .page:
                orderedAscending = left.page == right.page 
                    ? left.createdAt < right.createdAt 
                    : left.page < right.page
            case .part:
                if left.part == right.part {
                    orderedAscending = left.page == right.page 
                        ? left.createdAt < right.createdAt 
                        : left.page < right.page
                } else {
                    orderedAscending = left.part < right.part
                }
            }
            return sortOption.isAscending ? orderedAscending : !orderedAscending
        }

        // KASUS 2: Buku (Parent Nodes)
        if lhs.annotation == nil && rhs.annotation == nil {
            if sortOption.field == .createdAt {
                let leftLatest = lhs.children.compactMap { $0.annotation?.createdAt }.max() ?? 0
                let rightLatest = rhs.children.compactMap { $0.annotation?.createdAt }.max() ?? 0
                if leftLatest != rightLatest {
                    let orderedAscending = leftLatest < rightLatest
                    return sortOption.isAscending ? orderedAscending : !orderedAscending
                }
            }
            // Selain Date Created: SELALU urutkan Buku berdasarkan Judul A-Z
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    func addAnnotationToTree(_ annotation: Annotation) {
        treeQueue.async { [weak self] in
            guard let self else { return }
            guard self.groupingMode == .book else {
                self.buildAnnotationTree()
                self.postChangeNotification(type: .added, annotation: annotation)
                return
            }
            guard let root = _rootNode else {
                postChangeNotification(type: .added, annotation: annotation)
                return
            }

            let bookNode = self.findOrCreateBookNode(for: annotation.bkId, in: root)

            let displayTitle: String
            if let note = annotation.note, !note.isEmpty {
                displayTitle = note
            } else {
                displayTitle = annotation.context
            }

            let annotationNode = AnnotationNode(
                title: displayTitle,
                kind: .annotation,
                annotation: annotation
            )
            
            // Optimization: Use insertionIndex instead of append + sort
            let index = bookNode.children.insertionIndex(for: annotationNode, using: compareNodes)
            bookNode.children.insert(annotationNode, at: index)
            
            // Jika sorting berdasarkan Date, posisi bookNode di root mungkin perlu bergeser
            if sortOption.field == .createdAt {
                if let oldIndex = root.children.firstIndex(where: { $0 === bookNode }) {
                    root.children.remove(at: oldIndex)
                }
                let newIndex = root.children.insertionIndex(for: bookNode, using: compareNodes)
                root.children.insert(bookNode, at: newIndex)
            }

            postChangeNotification(type: .added, annotation: annotation)
        }
    }

    func updateAnnotationInTree(_ annotation: Annotation) {
        treeQueue.async { [weak self] in
            guard let self else { return }
            guard self.groupingMode == .book else {
                self.buildAnnotationTree()
                self.postChangeNotification(type: .updated, annotation: annotation)
                return
            }
            guard let annotationId = annotation.id,
                  let node = self.findAnnotationNode(by: annotationId) else {
                postChangeNotification(type: .updated, annotation: annotation)
                return
            }

            if let note = annotation.note, !note.isEmpty {
                node.title = note
            } else {
                node.title = annotation.context
            }
            node.annotation = annotation

            postChangeNotification(type: .updated, annotation: annotation)
        }
    }

    func removeAnnotationFromTree(id: Int64, deletedAnnotation: Annotation?) {
        treeQueue.async { [weak self] in
            guard let self else { return }
            guard self.groupingMode == .book else {
                self.buildAnnotationTree()
                self.postChangeNotification(type: .deleted, annotation: deletedAnnotation, annotationId: id)
                return
            }
            guard let root = _rootNode else {
                postChangeNotification(type: .deleted, annotation: deletedAnnotation, annotationId: id)
                return
            }

            for bookNode in root.children {
                if let index = bookNode.children.firstIndex(where: { $0.annotation?.id == id }) {
                    bookNode.children.remove(at: index)
                    
                    if bookNode.children.isEmpty {
                        if let bookIndex = root.children.firstIndex(where: { $0 === bookNode }) {
                            root.children.remove(at: bookIndex)
                        }
                    }
                    break
                }
            }

            postChangeNotification(type: .deleted, annotation: deletedAnnotation, annotationId: id)
        }
    }

    // MARK: - Private Helpers
    private func findOrCreateBookNode(for bkId: Int, in root: AnnotationNode) -> AnnotationNode {
        if let existing = root.children.first(where: { node in
            guard let firstChild = node.children.first,
                  let annotation = firstChild.annotation else { return false }
            return annotation.bkId == bkId
        }) {
            return existing
        }

        guard let book = LibraryDataManager.shared.getBook([bkId]).first else {
            let fallbackNode = AnnotationNode(title: "Unknown Book", kind: .book)
            // Optimization: Insert using insertionIndex
            let idx = root.children.insertionIndex(for: fallbackNode, using: compareNodes)
            root.children.insert(fallbackNode, at: idx)
            return fallbackNode
        }

        let bookNode = AnnotationNode(title: book.book, kind: .book)
        // Optimization: Insert using insertionIndex
        let idx = root.children.insertionIndex(for: bookNode, using: compareNodes)
        root.children.insert(bookNode, at: idx)

        return bookNode
    }

    private func findAnnotationNode(by id: Int64) -> AnnotationNode? {
        guard let root = _rootNode else { return nil }

        for bookNode in root.children {
            if let found = bookNode.children.first(where: { $0.annotation?.id == id }) {
                return found
            }
        }
        return nil
    }

    // MARK: - Invalidate Cache
    func invalidateTree() {
        treeQueue.async { [weak self] in
            self?._rootNode = nil
        }
    }

    func updateGroupingMode(_ mode: AnnotationGroupingMode) {
        groupingMode = mode
        invalidateTree()
        buildAnnotationTree()
    }

    // MARK: - Helper TextViewState
    fileprivate func pushRecentColor(_ annotation: Annotation) {
        if annotation.type == .highlight,
           let color = NSColor(hex: annotation.colorHex) {
            TextViewState.shared.pushRecentHighlightColor(color)
        }
    }

    private func populateBookTree(root: AnnotationNode, annotations: [Annotation]) {
        let grouped = Dictionary(grouping: annotations, by: { $0.bkId })
        let sortedBooks = grouped.keys
            .compactMap { LibraryDataManager.shared.getBook([$0]).first }

        for book in sortedBooks {
            let annsForBook = grouped[book.id] ?? []
            let bookNode = AnnotationNode(title: book.book, kind: .book)

            for ann in annsForBook {
                let child = AnnotationNode(
                    title: displayTitle(for: ann),
                    kind: .annotation,
                    annotation: ann
                )
                bookNode.children.append(child)
            }

            root.children.append(bookNode)
        }
    }

    private func populateTagTree(root: AnnotationNode, annotations: [Annotation]) {
        var grouped: [String: [Annotation]] = [:]
        var untagged: [Annotation] = []

        for annotation in annotations {
            let tags = sanitizeTagNames(annotation.tags)
            if tags.isEmpty {
                untagged.append(annotation)
                continue
            }

            for tag in tags {
                grouped[tag, default: []].append(annotation)
            }
        }

        for tag in grouped.keys.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }) {
            let tagNode = AnnotationNode(title: tag, kind: .tag)
            for annotation in grouped[tag] ?? [] {
                tagNode.children.append(
                    AnnotationNode(
                        title: displayTitle(for: annotation),
                        kind: .annotation,
                        annotation: annotation
                    )
                )
            }
            root.children.append(tagNode)
        }

        if !untagged.isEmpty {
            let untaggedNode = AnnotationNode(title: "Untagged".localized, kind: .untagged)
            for annotation in untagged {
                untaggedNode.children.append(
                    AnnotationNode(
                        title: displayTitle(for: annotation),
                        kind: .annotation,
                        annotation: annotation
                    )
                )
            }
            root.children.append(untaggedNode)
        }
    }

    private func displayTitle(for annotation: Annotation) -> String {
        if let note = annotation.note, !note.isEmpty {
            return note
        }
        return annotation.context
    }

    private func sanitizeTagNames(_ tags: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for tag in tags {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let normalized = normalizedTagName(trimmed)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { continue }
            result.append(trimmed)
        }

        return result
    }

    private func normalizedTagName(_ name: String) -> String {
        name
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    /// Semua nama tag unik yang ada di DB, diurutkan case-insensitive.
    func allTagNames() -> [String] {
        if let cached = cacheQueue.sync(execute: { cachedAllTagNames }) {
            return cached
        }
        guard let db else { return [] }
        do {
            let names = try db.prepare(tagsTable.select(tagName).order(tagName.collate(.nocase)))
                .map { $0[tagName] }
            cacheQueue.sync { cachedAllTagNames = names }
            return names
        } catch {
            return []
        }
    }

    private func loadTags(for annotationId: Int64) -> [String] {
        if let cached = cacheQueue.sync(execute: { cacheTagsByAnnotationId[annotationId] }) {
            return cached
        }

        guard let db else { return [] }
        let query = annotationTagsTable
            .join(tagsTable, on: annotationTagsTable[annotationTagTagId] == tagsTable[tagId])
            .filter(annotationTagsTable[annotationTagAnnotationId] == annotationId)
            .order(tagsTable[tagName].collate(.nocase))

        do {
            let tags = try db.prepare(query).map { $0[tagsTable[tagName]] }
            cacheQueue.sync {
                cacheTagsByAnnotationId[annotationId] = tags
            }
            return tags
        } catch {
            print("loadTags error:", error)
            return []
        }
    }

    private func replaceTags(_ tags: [String], for annotationId: Int64, in db: Connection) throws {
        try db.run(annotationTagsTable.filter(annotationTagAnnotationId == annotationId).delete())

        for tag in tags {
            let normalized = normalizedTagName(tag)
            let existing = try db.pluck(tagsTable.filter(tagNormalizedName == normalized))
            let currentTagId: Int64

            if let existing {
                currentTagId = existing[tagId]
                if existing[tagName] != tag {
                    try db.run(
                        tagsTable.filter(self.tagId == currentTagId)
                            .update(tagName <- tag)
                    )
                }
            } else {
                currentTagId = try db.run(
                    tagsTable.insert(
                        tagName <- tag,
                        tagNormalizedName <- normalized
                    )
                )
            }

            try db.run(
                annotationTagsTable.insert(
                    or: .ignore,
                    annotationTagAnnotationId <- annotationId,
                    annotationTagTagId <- currentTagId
                )
            )
        }

        // Invalidate flat tag cache — struktur tag mungkin berubah
        cacheQueue.sync { cachedAllTagNames = nil }

        try deleteUnusedTags(in: db)
    }

    private func deleteUnusedTags(in db: Connection) throws {
        let usedTagIds = Set(try db.prepare(annotationTagsTable.select(annotationTagTagId)).map { $0[annotationTagTagId] })
        for row in try db.prepare(tagsTable.select(tagId)) {
            let currentId = row[tagId]
            if !usedTagIds.contains(currentId) {
                try db.run(tagsTable.filter(tagId == currentId).delete())
            }
        }
    }
}
