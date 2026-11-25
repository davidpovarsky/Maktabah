#if os(iOS)
import Foundation
import HanlinMiniAppsBridge

extension OtzariaMiniAppsDocument {
    @MainActor
    init(annotation: Annotation, draft: String, selection: NSRange?, isReaderSelection: Bool,
         editorID: UUID?, title: String) throws {
        guard let profile = AnnotationRepository.shared.dbURL else { throw OtzariaMiniAppsError.missingDocument }
        self.profile = profile.standardizedFileURL.resolvingSymlinksInPath().path
        annotationID = annotation.id
        annotationUUID = annotation.ckRecordId ?? UUID().uuidString
        bookID = annotation.bkId; contentID = annotation.contentId
        rangeLocation = annotation.range.location; rangeLength = annotation.range.length
        diacriticsLocation = annotation.rangeDiacritics.location; diacriticsLength = annotation.rangeDiacritics.length
        context = annotation.context; page = annotation.page; part = annotation.part
        color = annotation.colorHex; annotationType = annotation.type.rawValue; createdAt = annotation.createdAt
        originalNote = annotation.note; draftNote = draft; tags = annotation.tags
        locatorJSON = try annotation.backendLocator.map { String(decoding: try JSONEncoder().encode($0), as: UTF8.self) }
        self.title = title; self.isReaderSelection = isReaderSelection; self.editorID = editorID
        if let selection, let range = Range(selection, in: draft) {
            self.selection = .init(location: selection.location, length: selection.length, text: String(draft[range]))
        } else { self.selection = nil }
    }

    func annotation(note: String) throws -> Annotation {
        Annotation(id: annotationID, bkId: bookID, contentId: contentID,
            range: .init(location: rangeLocation, length: rangeLength),
            rangeDiacritics: .init(location: diacriticsLocation, length: diacriticsLength),
            colorHex: color, type: .from(int: annotationType), note: note, createdAt: createdAt,
            context: context, page: page, part: part, tags: tags, ckRecordId: annotationUUID,
            backendLocator: try locatorJSON.map { try JSONDecoder().decode(TextLocator.self, from: Data($0.utf8)) })
    }
}

/// Uses the original database handle, original row writer, original row mapper and
/// original CloudKit queue. The result receipt and text commit are one transaction.
enum OtzariaMiniAppsPersistence {
    struct Commit {
        let annotation: Annotation
        let replayed: Bool
    }

    static func apply(_ result: MiniAppResult, document: OtzariaMiniAppsDocument,
                      text: String, repository: AnnotationRepository = .shared) throws -> Commit {
        let connection = try repository.captureLocalEditorConnection()
        guard connection.databaseURL.standardizedFileURL.resolvingSymlinksInPath().path == document.profile else {
            throw OtzariaMiniAppsError.differentLibrary
        }
        let db = connection.database
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let identity = String(decoding: try encoder.encode(result), as: UTF8.self)
        let committed: OtzariaMiniAppsReceiptJournal.Commit<Annotation> = try OtzariaMiniAppsReceiptJournal.commit(requestID: result.requestID,
            resultJSON: identity, documentID: document.annotationUUID, database: db,
            validate: { try connection.lifetime.requireCurrent() },
            read: { id in
                guard let saved = try read(id: id, connection: connection),
                      saved.ckRecordId == document.annotationUUID else { return nil }
                return saved
            }, apply: {
            var saved: Annotation
            if let id = document.annotationID {
                guard var current = try read(id: id, connection: connection),
                      current.ckRecordId == document.annotationUUID,
                      current.bkId == document.bookID, current.contentId == document.contentID,
                      current.createdAt == document.createdAt, current.context == document.context,
                      current.note == document.originalNote else {
                    throw OtzariaMiniAppsError.changedDocument
                }
                // The original rich body owns its preview. A MiniApps plain-text
                // result cannot overwrite it through this direct SQLite seam.
                // Keep this check in the same receipt/edit transaction, so a
                // rejected result remains pending and no receipt is committed.
                try AnnotationLocalEditorPersistence.requirePlainWrite(database: db,
                    annotationID: id, originalRecordID: document.annotationUUID)
                // Preserve unrelated colors, tags and source anchors changed while away.
                current.note = text
                current.lastModified = Int64(Date().timeIntervalSince1970)
                try db.execute(query: """
                    UPDATE annotations SET note = ?, lastModified = ? WHERE id = ? AND ckRecordId = ?;
                    """, parameters: [text, current.lastModified ?? 0, id, document.annotationUUID])
                saved = current
            } else {
                var created = try document.annotation(note: text)
                created.lastModified = Int64(Date().timeIntervalSince1970)
                created.id = try repository.insertAnnotationRow(created, into: db)
                guard let id = created.id, id > 0 else { throw OtzariaMiniAppsError.missingDocument }
                // The original tag normalizer is reused on the captured handle.
                created.tags = repository.sanitizeTagNames(created.tags)
                for tag in created.tags {
                    let normalized = repository.normalizedTagName(tag)
                    try db.execute(query: "INSERT OR IGNORE INTO tags (name, normalizedName) VALUES (?, ?);",
                        parameters: [tag, normalized])
                    try db.execute(query: """
                        INSERT OR IGNORE INTO annotation_tags (annotationId, tagId)
                        SELECT ?, id FROM tags WHERE normalizedName = ?;
                        """, parameters: [id, normalized])
                }
                saved = created
            }
            guard let id = saved.id else { throw OtzariaMiniAppsError.missingDocument }
            try connection.syncPending.addPendingSync(ckRecordId: document.annotationUUID, operation: "upload")
            return (id: id, value: saved)
        })
        return .init(annotation: committed.value, replayed: committed.replayed)
    }

    private static func read(id: Int64, connection: AnnotationLocalEditorConnection) throws -> Annotation? {
        let db = connection.database
        guard var annotation = try db.fetch(query: "SELECT * FROM annotations WHERE id = ?;",
            parameters: [id], mapping: { connection.mapRow($0, []) }).first else { return nil }
        annotation.tags = try db.fetch(query: """
            SELECT t.name FROM tags t INNER JOIN annotation_tags at ON t.id = at.tagId
            WHERE at.annotationId = ? ORDER BY t.name COLLATE NOCASE ASC;
            """, parameters: [id]) { $0.string(at: 0) ?? "" }
        return annotation
    }
}
#endif
