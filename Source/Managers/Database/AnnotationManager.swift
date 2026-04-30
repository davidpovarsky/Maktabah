//
//  AnnotationManager.swift
//  maktab
//
//  Created by MacBook on 15/12/25.
//  Granular Tag UI Update
//

import AppKit
import Foundation
import SQLite

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

enum AnnotationNotificationKeys {
    static let changeType = "changeType"
    static let annotation = "annotation"
    static let annotationId = "annotationId"
    static let tagDiff = "tagDiff"
}

struct TagUpdateDiff {
    struct RemovedEntry {
        let annotationNode: AnnotationNode // node anotasi yang dihapus
        let tagNode: AnnotationNode // tag node induknya
        let tagNodeBecomesEmpty: Bool // apakah tag node ikut hilang dari root
        let oldIndex: Int // Index item yang dihapus dalam parentnya
    }

    struct AddedEntry {
        let annotationNode: AnnotationNode // node anotasi yang ditambahkan
        let tagNode: AnnotationNode // tag node induknya
        let tagNodeIsNew: Bool // apakah tag node baru dibuat
    }

    let removed: [RemovedEntry]
    let added: [AddedEntry]
    let updated: [AnnotationNode] // annotation node yang hanya di-update teks/warna
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
    private var cachedAllTagNames: [String]?

    private var _rootNode: AnnotationNode?
    private let treeQueue = DispatchQueue(label: "com.maktab.annotationManager.treeQueue", qos: .userInitiated)

    var rootNode: AnnotationNode? {
        treeQueue.sync { _rootNode }
    }

    // State Sorting
    private(set) var sortOption: AnnotationSortOption = .init(field: .createdAt, isAscending: false)
    private(set) var groupingMode: AnnotationGroupingMode = .book

    /// Serial queue to protect caches
    private let cacheQueue = DispatchQueue(label: "com.maktab.annotationManager.cacheQueue", qos: .userInitiated)

    private init() {}

    // MARK: - Private helper to post notification

    private func postChangeNotification(type: AnnotationChangeType, annotation: Annotation? = nil, annotationId: Int64? = nil, diff: TagUpdateDiff? = nil) {
        var userInfo: [String: Any] = [AnnotationNotificationKeys.changeType: type.rawValue]

        if let ann = annotation {
            userInfo[AnnotationNotificationKeys.annotation] = ann
            if type != .deleted { pushRecentColor(ann) }
        }
        if let id = annotationId {
            userInfo[AnnotationNotificationKeys.annotationId] = id
        }
        if let diff = diff {
            userInfo[AnnotationNotificationKeys.tagDiff] = diff
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
        guard let db else { throw NSError(domain: "DBNil", code: 1) }
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
        saved.pageArb = String(saved.page).convertToArabicDigits()
        saved.partArb = String(saved.part).convertToArabicDigits()
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
        guard let db else { throw NSError(domain: "DBNil", code: 1) }
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

        updateAnnotationInTree(updatedAnnotation)
    }

    // MARK: - Rename Tag

    /// Ganti nama tag.
    /// - Jika `newName` (setelah normalisasi) sama dengan tag lain yang sudah ada → **merge**:
    ///   semua anotasi dari tag lama dipindah ke tag yang sudah ada, tag lama dihapus.
    /// - Jika tidak → **simple rename**: hanya nama di DB & cache yang diperbarui.
    /// - Throws `NSError(domain:"EmptyTagName")` jika `newName` kosong setelah trim.
    func renameTag(from oldName: String, to newName: String) throws {
        guard let db else { throw NSError(domain: "DBNil", code: 1) }

        let trimmedNew = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldNormalized = normalizedTagName(oldName)
        let newNormalized = normalizedTagName(trimmedNew)

        guard !newNormalized.isEmpty else {
            throw NSError(
                domain: "EmptyTagName", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Tag name cannot be empty."])
        }
        // Tidak ada perubahan sama sekali
        if oldNormalized == newNormalized && oldName == trimmedNew { return }

        guard let oldRow = try db.pluck(tagsTable.filter(tagNormalizedName == oldNormalized)) else {
            return
        }
        let oldTagId = oldRow[tagId]

        // Annotation ID yang terpengaruh (sebelum transaksi)
        let affectedIds = try db.prepare(
            annotationTagsTable
                .filter(annotationTagTagId == oldTagId)
                .select(annotationTagAnnotationId)
        ).map { $0[annotationTagAnnotationId] }

        var updatedAnnotations: [Annotation] = []

        if let existingNewRow = try db.pluck(tagsTable.filter(tagNormalizedName == newNormalized)) {
            // ── MERGE: tag dengan normalizedName yang sama sudah ada ──
            let mergeTargetId = existingNewRow[tagId]
            let mergeTargetDisplay = existingNewRow[tagName]

            try db.transaction {
                for annId in affectedIds {
                    guard var ann = loadAnnotationById(annId) else { continue }
                    var tags = ann.tags.filter { normalizedTagName($0) != oldNormalized }
                    if !tags.contains(where: { normalizedTagName($0) == newNormalized }) {
                        tags.append(mergeTargetDisplay)
                    }
                    ann.tags = sanitizeTagNames(tags)
                    updatedAnnotations.append(ann)

                    // insert ke target tag, ignore jika sudah ada (dedup)
                    try db.run(
                        annotationTagsTable.insert(
                            or: .ignore,
                            annotationTagAnnotationId <- annId,
                            annotationTagTagId <- mergeTargetId
                        ))
                }
                try db.run(annotationTagsTable.filter(annotationTagTagId == oldTagId).delete())
                try db.run(tagsTable.filter(tagId == oldTagId).delete())
            }
        } else {
            // ── SIMPLE RENAME ──
            try db.transaction {
                for annId in affectedIds {
                    guard var ann = loadAnnotationById(annId) else { continue }
                    ann.tags = ann.tags.map {
                        normalizedTagName($0) == oldNormalized ? trimmedNew : $0
                    }
                    ann.tags = sanitizeTagNames(ann.tags)
                    updatedAnnotations.append(ann)
                }
                try db.run(
                    tagsTable.filter(tagId == oldTagId).update(
                        tagName <- trimmedNew,
                        tagNormalizedName <- newNormalized
                    ))
            }
        }

        // Terapkan perubahan batch yang akan menghasilkan UI update gradual
        // (menghindari buildAnnotationTree() yang mereload seluruh outlineView)
        applyBatchTagUpdates(updatedAnnotations)
    }

    func addTag(_ tag: String, toAnnotationIDs annotationIDs: [Int64]) throws {
        let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedTags = sanitizeTagNames([trimmedTag])
        guard let normalizedTag = sanitizedTags.first else { return }

        let uniqueIDs = Array(Set(annotationIDs)).sorted()
        guard !uniqueIDs.isEmpty else { return }
        guard let db else { throw NSError(domain: "DBNil", code: 1) }

        var updatedAnnotations: [Annotation] = []
        try db.transaction {
            for annotationID in uniqueIDs {
                guard var annotation = loadAnnotationById(annotationID) else { continue }
                let mergedTags = sanitizeTagNames(annotation.tags + [normalizedTag])
                guard mergedTags != annotation.tags else { continue }
                try replaceTags(mergedTags, for: annotationID, in: db)
                annotation.tags = mergedTags
                updatedAnnotations.append(annotation)
            }
        }

        applyBatchTagUpdates(updatedAnnotations)
    }

    func removeTag(_ tag: String, fromAnnotationIDs annotationIDs: [Int64]) throws {
        let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTarget = normalizedTagName(trimmedTag)
        guard !normalizedTarget.isEmpty else { return }

        let uniqueIDs = Array(Set(annotationIDs)).sorted()
        guard !uniqueIDs.isEmpty else { return }
        guard let db else { throw NSError(domain: "DBNil", code: 1) }

        var updatedAnnotations: [Annotation] = []
        try db.transaction {
            for annotationID in uniqueIDs {
                guard var annotation = loadAnnotationById(annotationID) else { continue }
                let filteredTags = annotation.tags.filter {
                    normalizedTagName($0) != normalizedTarget
                }
                let sanitizedTags = sanitizeTagNames(filteredTags)
                guard sanitizedTags != annotation.tags else { continue }
                try replaceTags(sanitizedTags, for: annotationID, in: db)
                annotation.tags = sanitizedTags
                updatedAnnotations.append(annotation)
            }
        }

        applyBatchTagUpdates(updatedAnnotations)
    }

    // MARK: - Delete annotation

    func deleteAnnotation(id: Int64) throws {
        guard let db else { throw NSError(domain: "DBNil", code: 1) }

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

    // MARK: - Delete Tag (hapus tag dari semua anotasi)

    /// Hapus tag dari DB dan semua anotasi yang memilikinya.
    /// Anotasi tidak dihapus — hanya kehilangan tag ini.
    func deleteTag(named tagNameToDelete: String) throws {
        guard let db else { throw NSError(domain: "DBNil", code: 1) }

        let normalized = normalizedTagName(tagNameToDelete)
        guard let tagRow = try db.pluck(tagsTable.filter(tagNormalizedName == normalized)) else {
            return
        }
        let deletedTagId = tagRow[tagId]

        // Ambil semua annotationId yang punya tag ini sebelum dihapus
        let affectedIds = try db.prepare(
            annotationTagsTable
                .filter(annotationTagTagId == deletedTagId)
                .select(annotationTagAnnotationId)
        ).map { $0[annotationTagAnnotationId] }

        // Hapus relasi & tag dari DB (dalam satu transaksi)
        try db.transaction {
            try db.run(annotationTagsTable.filter(annotationTagTagId == deletedTagId).delete())
            try db.run(tagsTable.filter(tagId == deletedTagId).delete())
        }

        // Update cache: strip tag yang dihapus dari setiap anotasi
        var updatedAnnotations: [Annotation] = []
        cacheQueue.sync {
            cachedAllTagNames = nil
            for annId in affectedIds {
                guard var ann = cacheById[annId] else { continue }
                ann.tags = ann.tags.filter { normalizedTagName($0) != normalized }
                cacheById[annId] = ann
                cacheTagsByAnnotationId[annId] = ann.tags

                let key = ContentKey(bkId: ann.bkId, contentId: ann.contentId)
                var cachedArr = cacheByContent[key] ?? []
                if let idx = cachedArr.firstIndex(where: { $0.id == annId }) {
                    cachedArr[idx] = ann
                    cacheByContent[key] = cachedArr
                }
                updatedAnnotations.append(ann)
            }
        }

        deleteTagFromTree(
            tagName: tagNameToDelete,
            normalizedName: normalized,
            updatedAnnotations: updatedAnnotations
        )
    }

    private func deleteTagFromTree(
        tagName: String,
        normalizedName _: String,
        updatedAnnotations: [Annotation]
    ) {
        treeQueue.async { [weak self] in
            guard let self, let root = _rootNode else { return }

            guard groupingMode == .tag else {
                // Book mode: tidak ada tag node di tree.
                // Cukup post .updated untuk masing-masing anotasi agar badge tag ter-refresh.
                for ann in updatedAnnotations {
                    postChangeNotification(type: .updated, annotation: ann)
                }
                return
            }

            guard
                let tagNode = root.children.first(where: {
                    $0.kind == .tag && $0.title == tagName
                }),
                let tagIndex = root.children.firstIndex(where: { $0 === tagNode })
            else {
                // Tidak ditemukan di tree — rebuild saja
                buildAnnotationTree()
                return
            }

            // Cukup satu entry untuk menghapus seluruh tag node dari root
            let removedEntries = [
                TagUpdateDiff.RemovedEntry(
                    annotationNode: tagNode, // Node yang dihapus adalah tagNode itu sendiri
                    tagNode: tagNode,         // Parent root disimbolkan lewat tagNodeBecomesEmpty
                    tagNodeBecomesEmpty: true,
                    oldIndex: tagIndex
                )
            ]

            // Hapus tag node dari root model
            root.children.remove(at: tagIndex)

            // Anotasi yang kini tidak punya tag → pindah ke Untagged
            let nowUntagged = updatedAnnotations.filter(\.tags.isEmpty)
            var addedEntries: [TagUpdateDiff.AddedEntry] = []

            if !nowUntagged.isEmpty {
                let isNewUntaggedNode: Bool
                let untaggedNode: AnnotationNode
                if let existing = root.children.first(where: { $0.kind == .untagged }) {
                    untaggedNode = existing
                    isNewUntaggedNode = false
                } else {
                    let fresh = AnnotationNode(title: "Untagged".localized, kind: .untagged)
                    root.children.append(fresh)
                    untaggedNode = fresh
                    isNewUntaggedNode = true
                }

                for (i, ann) in nowUntagged.enumerated() {
                    let displayTitle: String = {
                        if let note = ann.note, !note.isEmpty { return note }
                        return ann.context
                    }()
                    let newNode = AnnotationNode(
                        title: displayTitle, kind: .annotation, annotation: ann
                    )
                    let idx = untaggedNode.children.insertionIndex(
                        for: newNode, using: compareNodes
                    )
                    untaggedNode.children.insert(newNode, at: idx)

                    if isNewUntaggedNode {
                        // Hanya satu entry yang dibutuhkan: DataSource insert node baru
                        // (collapsed by default, node akan terlihat saat di-expand)
                        if i == 0 {
                            addedEntries.append(
                                .init(
                                    annotationNode: newNode,
                                    tagNode: untaggedNode,
                                    tagNodeIsNew: true
                                )
                            )
                        }
                    } else {
                        addedEntries.append(
                            .init(
                                annotationNode: newNode,
                                tagNode: untaggedNode,
                                tagNodeIsNew: false
                            )
                        )
                    }
                }
            }

            let diff = TagUpdateDiff(
                removed: removedEntries,
                added: addedEntries,
                updated: []
            )

            // Post notifikasi untuk memicu handleTagModeUpdate di DataSource.
            let representativeId = updatedAnnotations.first?.id ?? -1
            postChangeNotification(type: .updated, annotationId: representativeId, diff: diff)
        }
    }

    // MARK: - Load annotations for a book content

    func loadAnnotations(bkId: Int, contentId: Int) -> [Annotation] {
        let key = ContentKey(bkId: bkId, contentId: contentId)

        if let cached = cacheQueue.sync(execute: { cacheByContent[key] }) {
            return cached
        }

        guard let db else { return [] }
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

        guard let db else { return nil }
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
        guard let db else { return [] }
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
            guard let self else { return }

            let root = AnnotationNode(title: "All Annotations", kind: .root)
            let anns = loadAnnotations()
            switch groupingMode {
            case .book:
                populateBookTree(root: root, annotations: anns)
            case .tag:
                populateTagTree(root: root, annotations: anns)
            }

            sortNodeChildren(root)

            _rootNode = root

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
            guard let self else { return }
            sortOption = .init(field: field, isAscending: isAscending)
            guard let root = _rootNode else { return }
            sortNodeChildren(root)

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
        if lhs.annotation == nil, rhs.annotation == nil {
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
            guard groupingMode == .book else {
                addAnnotationToTagTree(annotation)
                return
            }
            guard let root = _rootNode else {
                postChangeNotification(type: .added, annotation: annotation)
                return
            }

            let bookNode = findOrCreateBookNode(for: annotation.bkId, in: root)

            let displayTitle: String = if let note = annotation.note, !note.isEmpty {
                note
            } else {
                annotation.context
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
            guard groupingMode == .book else {
                updateAnnotationInTagTree(annotation)
                return
            }
            guard let annotationId = annotation.id,
                  let node = findAnnotationNode(by: annotationId)
            else {
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
            guard groupingMode == .book else {
                let diff = removeAnnotationFromTagTree(id: id)
                postChangeNotification(type: .deleted, annotation: deletedAnnotation, annotationId: id, diff: diff)
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

    // MARK: - Tag Tree Manipulation (Granular)

    private func addAnnotationToTagTree(_ annotation: Annotation) {
        guard let root = _rootNode else {
            postChangeNotification(type: .added, annotation: annotation)
            return
        }

        let tags = sanitizeTagNames(annotation.tags)
        let displayTitle =
            (annotation.note != nil && !annotation.note!.isEmpty)
            ? annotation.note! : annotation.context
        var addedEntries: [TagUpdateDiff.AddedEntry] = []

        if tags.isEmpty {
            let isNew: Bool
            let untaggedNode: AnnotationNode
            if let existing = root.children.first(where: { $0.kind == .untagged }) {
                untaggedNode = existing
                isNew = false
            } else {
                let fresh = AnnotationNode(title: "Untagged".localized, kind: .untagged)
                root.children.append(fresh)
                untaggedNode = fresh
                isNew = true
            }

            let newNode = AnnotationNode(
                title: displayTitle, kind: .annotation, annotation: annotation)
            let idx = untaggedNode.children.insertionIndex(for: newNode, using: compareNodes)
            untaggedNode.children.insert(newNode, at: idx)
            addedEntries.append(
                .init(annotationNode: newNode, tagNode: untaggedNode, tagNodeIsNew: isNew))
        } else {
            for tag in tags {
                if let tagNode = root.children.first(where: { $0.kind == .tag && $0.title == tag })
                {
                    let newNode = AnnotationNode(
                        title: displayTitle, kind: .annotation, annotation: annotation)
                    let idx = tagNode.children.insertionIndex(for: newNode, using: compareNodes)
                    tagNode.children.insert(newNode, at: idx)
                    addedEntries.append(
                        .init(annotationNode: newNode, tagNode: tagNode, tagNodeIsNew: false))
                } else {
                    let tagNode = AnnotationNode(title: tag, kind: .tag)
                    let newNode = AnnotationNode(
                        title: displayTitle, kind: .annotation, annotation: annotation)
                    tagNode.children.append(newNode)

                    let insertIdx =
                        root.children.firstIndex(where: { node in
                            guard node.kind == .tag else { return node.kind == .untagged }
                            return tag.localizedCaseInsensitiveCompare(node.title)
                                == .orderedAscending
                        })
                        ?? (root.children.firstIndex(where: { $0.kind == .untagged })
                            ?? root.children.endIndex)

                    root.children.insert(tagNode, at: insertIdx)
                    addedEntries.append(
                        .init(annotationNode: newNode, tagNode: tagNode, tagNodeIsNew: true))
                }
            }
        }

        let diff = TagUpdateDiff(removed: [], added: addedEntries, updated: [])
        postChangeNotification(type: .added, annotation: annotation, diff: diff)
    }

    private func updateAnnotationInTagTree(_ annotation: Annotation) {
        guard let id = annotation.id, let root = _rootNode else {
            buildAnnotationTree()
            return
        }

        let displayTitle: String = {
            if let note = annotation.note, !note.isEmpty { return note }
            return annotation.context
        }()

        let newTags = Set(sanitizeTagNames(annotation.tags))

        var existingTagNodes: [AnnotationNode] = []
        for tagNode in root.children {
            if tagNode.children.contains(where: { $0.annotation?.id == id }) {
                existingTagNodes.append(tagNode)
            }
        }

        let existingTagNames = Set(existingTagNodes.compactMap { $0.kind == .tag ? $0.title : nil })
        let isCurrentlyUntagged = existingTagNodes.contains(where: { $0.kind == .untagged })

        var removedEntries: [TagUpdateDiff.RemovedEntry] = []
        var addedEntries: [TagUpdateDiff.AddedEntry] = []
        var updatedNodes: [AnnotationNode] = []

        // Hapus dari tag yang sudah tidak ada
        for tagNode in existingTagNodes
            where existingTagNames.subtracting(newTags).contains(tagNode.title)
        {
            // Capture annotation node SEBELUM dihapus
            if let annIdx = tagNode.children.firstIndex(where: { $0.annotation?.id == id }) {
                let annNode = tagNode.children[annIdx]
                let becomesEmpty = tagNode.children.count == 1
                let oldIndex = becomesEmpty ? (root.children.firstIndex(where: { $0 === tagNode }) ?? -1) : annIdx
                
                removedEntries.append(.init(
                    annotationNode: annNode,
                    tagNode: tagNode,
                    tagNodeBecomesEmpty: becomesEmpty,
                    oldIndex: oldIndex
                ))
                
                tagNode.children.remove(at: annIdx)
                if becomesEmpty {
                    root.children.removeAll { $0 === tagNode }
                }
            }
        }

        // Hapus dari untagged jika sekarang punya tag
        if isCurrentlyUntagged, !newTags.isEmpty {
            if let untaggedNode = root.children.first(where: { $0.kind == .untagged }) {
                if let annIdx = untaggedNode.children.firstIndex(where: { $0.annotation?.id == id }) {
                    let annNode = untaggedNode.children[annIdx]
                    let becomesEmpty = untaggedNode.children.count == 1
                    let oldIndex = becomesEmpty ? (root.children.firstIndex(where: { $0 === untaggedNode }) ?? -1) : annIdx

                    removedEntries.append(.init(
                        annotationNode: annNode,
                        tagNode: untaggedNode,
                        tagNodeBecomesEmpty: becomesEmpty,
                        oldIndex: oldIndex
                    ))
                    
                    untaggedNode.children.remove(at: annIdx)
                    if becomesEmpty {
                        root.children.removeAll { $0 === untaggedNode }
                    }
                }
            }
        }

        // Update node yang masih ada (tag tidak berubah, hanya teks/warna)
        for tagNode in root.children
            where existingTagNames.intersection(newTags).contains(tagNode.title)
        {
            if let node = tagNode.children.first(where: { $0.annotation?.id == id }) {
                node.title = displayTitle
                node.annotation = annotation
                updatedNodes.append(node)
            }
        }

        // Tambah ke tag baru
        for tag in newTags.subtracting(existingTagNames) {
            if let tagNode = root.children.first(where: { $0.kind == .tag && $0.title == tag }) {
                let newNode = AnnotationNode(
                    title: displayTitle, kind: .annotation, annotation: annotation
                )
                let idx = tagNode.children.insertionIndex(for: newNode, using: compareNodes)
                tagNode.children.insert(newNode, at: idx)
                addedEntries.append(.init(
                    annotationNode: newNode,
                    tagNode: tagNode,
                    tagNodeIsNew: false
                ))
            } else {
                let tagNode = AnnotationNode(title: tag, kind: .tag)
                let newNode = AnnotationNode(
                    title: displayTitle, kind: .annotation, annotation: annotation
                )
                tagNode.children.append(newNode)
                let insertIdx =
                    root.children.firstIndex(where: { node in
                        guard node.kind == .tag else { return node.kind == .untagged }
                        return tag.localizedCaseInsensitiveCompare(node.title) == .orderedAscending
                    })
                    ?? (root.children.firstIndex(where: { $0.kind == .untagged })
                        ?? root.children.endIndex)
                root.children.insert(tagNode, at: insertIdx)
                addedEntries.append(.init(
                    annotationNode: newNode,
                    tagNode: tagNode,
                    tagNodeIsNew: true
                ))
            }
        }

        // Masuk untagged jika sekarang tidak ada tag
        if newTags.isEmpty, !isCurrentlyUntagged {
            if let untaggedNode = root.children.first(where: { $0.kind == .untagged }) {
                let newNode = AnnotationNode(
                    title: displayTitle, kind: .annotation, annotation: annotation
                )
                let idx = untaggedNode.children.insertionIndex(for: newNode, using: compareNodes)
                untaggedNode.children.insert(newNode, at: idx)
                addedEntries.append(.init(
                    annotationNode: newNode,
                    tagNode: untaggedNode,
                    tagNodeIsNew: false
                ))
            } else {
                let untaggedNode = AnnotationNode(title: "Untagged".localized, kind: .untagged)
                let newNode = AnnotationNode(
                    title: displayTitle, kind: .annotation, annotation: annotation
                )
                untaggedNode.children.append(newNode)
                root.children.append(untaggedNode)
                addedEntries.append(.init(
                    annotationNode: newNode,
                    tagNode: untaggedNode,
                    tagNodeIsNew: true
                ))
            }
        }

        // Kirim notifikasi dengan diff
        let diff = TagUpdateDiff(
            removed: removedEntries,
            added: addedEntries,
            updated: updatedNodes
        )
        postChangeNotification(type: .updated, annotation: annotation, diff: diff)
    }

    @discardableResult
    private func removeAnnotationFromTagTree(id: Int64) -> TagUpdateDiff? {
        guard let root = _rootNode else { return nil }

        var removedEntries: [TagUpdateDiff.RemovedEntry] = []
        for tagNode in root.children {
            guard let annIdx = tagNode.children.firstIndex(where: { $0.annotation?.id == id }) else {
                continue
            }

            let annNode = tagNode.children[annIdx]
            let becomesEmpty = tagNode.children.count == 1
            let oldIndex = becomesEmpty ? (root.children.firstIndex(where: { $0 === tagNode }) ?? -1) : annIdx

            removedEntries.append(.init(
                annotationNode: annNode,
                tagNode: tagNode,
                tagNodeBecomesEmpty: becomesEmpty,
                oldIndex: oldIndex
            ))

            tagNode.children.remove(at: annIdx)
        }

        for entry in removedEntries where entry.tagNodeBecomesEmpty {
            root.children.removeAll { $0 === entry.tagNode }
        }

        return TagUpdateDiff(
            removed: removedEntries,
            added: [],
            updated: []
        )
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

    private func applyBatchTagUpdates(_ annotations: [Annotation]) {
        guard !annotations.isEmpty else { return }

        cacheQueue.sync {
            cachedAllTagNames = nil
            for annotation in annotations {
                guard let id = annotation.id else { continue }
                cacheById[id] = annotation
                cacheTagsByAnnotationId[id] = annotation.tags

                let key = ContentKey(bkId: annotation.bkId, contentId: annotation.contentId)
                var cachedAnnotations = cacheByContent[key] ?? []
                if let index = cachedAnnotations.firstIndex(where: { $0.id == id }) {
                    cachedAnnotations[index] = annotation
                } else {
                    let index = cachedAnnotations.insertionIndex(for: annotation) {
                        $0.range.location < $1.range.location
                    }
                    cachedAnnotations.insert(annotation, at: index)
                }
                cacheByContent[key] = cachedAnnotations
            }
        }

        treeQueue.async { [weak self] in
            guard let self else { return }
            if self.groupingMode == .book {
                for annotation in annotations {
                    guard let annotationId = annotation.id,
                          let node = self.findAnnotationNode(by: annotationId)
                    else {
                        self.postChangeNotification(type: .updated, annotation: annotation)
                        continue
                    }
                    if let note = annotation.note, !note.isEmpty {
                        node.title = note
                    } else {
                        node.title = annotation.context
                    }
                    node.annotation = annotation
                    self.postChangeNotification(type: .updated, annotation: annotation)
                }
            } else {
                self.performBatchTagTreeUpdate(annotations)
            }
        }
    }

    private func performBatchTagTreeUpdate(_ annotations: [Annotation]) {
        guard let root = _rootNode else { return }

        var removedEntries: [TagUpdateDiff.RemovedEntry] = []
        var addedEntries: [TagUpdateDiff.AddedEntry] = []
        var updatedNodes: [AnnotationNode] = []

        let updatedAnnsDict = Dictionary(uniqueKeysWithValues: annotations.compactMap { ann in ann.id.map { ($0, ann) } })

        for tagNode in root.children {
            var indicesToRemove: [Int] = []
            
            for (idx, child) in tagNode.children.enumerated() {
                guard let id = child.annotation?.id, let updatedAnn = updatedAnnsDict[id] else { continue }
                
                let newTags = Set(self.sanitizeTagNames(updatedAnn.tags))
                
                let displayTitle: String = {
                    if let note = updatedAnn.note, !note.isEmpty { return note }
                    return updatedAnn.context
                }()
                
                let shouldRemove: Bool
                if tagNode.kind == .untagged {
                    shouldRemove = !newTags.isEmpty
                } else {
                    shouldRemove = !newTags.contains(tagNode.title)
                }
                
                if shouldRemove {
                    indicesToRemove.append(idx)
                } else {
                    child.title = displayTitle
                    child.annotation = updatedAnn
                    updatedNodes.append(child)
                }
            }
            
            if !indicesToRemove.isEmpty {
                let becomesEmpty = indicesToRemove.count == tagNode.children.count
                let oldTagIndex = root.children.firstIndex(where: { $0 === tagNode }) ?? -1
                
                for idx in indicesToRemove {
                    removedEntries.append(.init(
                        annotationNode: tagNode.children[idx],
                        tagNode: tagNode,
                        tagNodeBecomesEmpty: becomesEmpty,
                        oldIndex: becomesEmpty ? oldTagIndex : idx
                    ))
                }
                
                for idx in indicesToRemove.reversed() {
                    tagNode.children.remove(at: idx)
                }
            }
        }

        root.children.removeAll { tagNode in
            tagNode.children.isEmpty && tagNode.kind != .root
        }

        for annotation in annotations {
            guard let id = annotation.id else { continue }
            let newTags = Set(self.sanitizeTagNames(annotation.tags))
            
            let displayTitle: String = {
                if let note = annotation.note, !note.isEmpty { return note }
                return annotation.context
            }()
            
            if newTags.isEmpty {
                if let untaggedNode = root.children.first(where: { $0.kind == .untagged }) {
                    if !untaggedNode.children.contains(where: { $0.annotation?.id == id }) {
                        let newNode = AnnotationNode(title: displayTitle, kind: .annotation, annotation: annotation)
                        let idx = untaggedNode.children.insertionIndex(for: newNode, using: compareNodes)
                        untaggedNode.children.insert(newNode, at: idx)
                        addedEntries.append(.init(annotationNode: newNode, tagNode: untaggedNode, tagNodeIsNew: false))
                    }
                } else {
                    let untaggedNode = AnnotationNode(title: String(localized: "Untagged"), kind: .untagged)
                    let newNode = AnnotationNode(title: displayTitle, kind: .annotation, annotation: annotation)
                    untaggedNode.children.append(newNode)
                    root.children.append(untaggedNode)
                    addedEntries.append(.init(annotationNode: newNode, tagNode: untaggedNode, tagNodeIsNew: true))
                }
            } else {
                for tag in newTags {
                    if let tagNode = root.children.first(where: { $0.kind == .tag && $0.title == tag }) {
                        if !tagNode.children.contains(where: { $0.annotation?.id == id }) {
                            let newNode = AnnotationNode(title: displayTitle, kind: .annotation, annotation: annotation)
                            let idx = tagNode.children.insertionIndex(for: newNode, using: compareNodes)
                            tagNode.children.insert(newNode, at: idx)
                            addedEntries.append(.init(annotationNode: newNode, tagNode: tagNode, tagNodeIsNew: false))
                        }
                    } else {
                        let tagNode = AnnotationNode(title: tag, kind: .tag)
                        let newNode = AnnotationNode(title: displayTitle, kind: .annotation, annotation: annotation)
                        tagNode.children.append(newNode)
                        
                        let insertIdx = root.children.firstIndex(where: { node in
                            guard node.kind == .tag else { return node.kind == .untagged }
                            return tag.localizedCaseInsensitiveCompare(node.title) == .orderedAscending
                        }) ?? (root.children.firstIndex(where: { $0.kind == .untagged }) ?? root.children.endIndex)
                        
                        root.children.insert(tagNode, at: insertIdx)
                        addedEntries.append(.init(annotationNode: newNode, tagNode: tagNode, tagNodeIsNew: true))
                    }
                }
            }
        }

        if !removedEntries.isEmpty || !addedEntries.isEmpty || !updatedNodes.isEmpty {
            let diff = TagUpdateDiff(
                removed: removedEntries,
                added: addedEntries,
                updated: updatedNodes
            )
            let representativeId = annotations.first?.id ?? -1
            postChangeNotification(type: .updated, annotation: annotations.first, annotationId: representativeId, diff: diff)
        }
    }

    // MARK: - Helper TextViewState

    private func pushRecentColor(_ annotation: Annotation) {
        if annotation.type == .highlight,
           let color = NSColor(hex: annotation.colorHex)
        {
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
                        tagsTable.filter(tagId == currentTagId)
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
        try db.run("""
        DELETE FROM tags
        WHERE id NOT IN (
            SELECT DISTINCT tagId
            FROM annotation_tags
        )
        """)
    }
}
