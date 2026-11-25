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

    /// Read the durable original-host receipt before starting native work.
    /// A later user edit does not make an already committed result run again.
    static func committed(_ result: MiniAppResult, document: OtzariaMiniAppsDocument,
                          repository: AnnotationRepository = .shared) throws -> Commit? {
        let connection = try repository.captureLocalEditorConnection()
        guard connection.databaseURL.standardizedFileURL.resolvingSymlinksInPath().path == document.profile else {
            throw OtzariaMiniAppsError.differentLibrary
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let identity = String(decoding: try encoder.encode(result), as: UTF8.self)
        var saved: Annotation?
        try connection.database.transaction {
            try connection.lifetime.requireCurrent()
            let exists = try connection.database.fetch(query:
                "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'miniapps_result_receipts';"
            ) { $0.int64(at: 0) }.first == 1
            guard exists else { return }
            let prior = try connection.database.fetch(query: """
                SELECT result_json, annotation_id, annotation_uuid FROM miniapps_result_receipts WHERE request_id = ?;
                """, parameters: [result.requestID.uuidString]) {
                    ($0.string(at: 0) ?? "", $0.int64(at: 1), $0.string(at: 2) ?? "")
                }.first
            guard let prior else { return }
            guard prior.0.utf8.elementsEqual(identity.utf8),
                  prior.2 == document.annotationUUID,
                  document.annotationID == nil || document.annotationID == prior.1,
                  let annotation = try read(id: prior.1, connection: connection),
                  annotation.ckRecordId == document.annotationUUID else {
                throw MiniAppBridgeError.conflictingResult
            }
            try connection.lifetime.requireCurrent()
            saved = annotation
        }
        return saved.map { .init(annotation: $0, replayed: true) }
    }

    static func savedAnnotation(document: OtzariaMiniAppsDocument,
                                repository: AnnotationRepository = .shared) throws -> Annotation {
        let connection = try repository.captureLocalEditorConnection()
        guard connection.databaseURL.standardizedFileURL.resolvingSymlinksInPath().path == document.profile else {
            throw OtzariaMiniAppsError.differentLibrary
        }
        var saved: Annotation?
        try connection.database.transaction {
            try connection.lifetime.requireCurrent()
            guard let id = document.annotationID,
                  let current = try read(id: id, connection: connection),
                  current.ckRecordId == document.annotationUUID,
                  current.bkId == document.bookID, current.contentId == document.contentID,
                  current.createdAt == document.createdAt, current.context == document.context,
                  current.note.map({ Array($0.utf8) }) == document.originalNote.map({ Array($0.utf8) }) else {
                throw OtzariaMiniAppsError.changedDocument
            }
            try connection.lifetime.requireCurrent()
            saved = current
        }
        guard let saved else { throw OtzariaMiniAppsError.missingDocument }
        return saved
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

#if canImport(AnytypeOriginalEditor)
extension AnnotationLocalEditorPersistence {
    /// The native rich body, original revision CAS, pending sync entry and
    /// exact MiniApps result receipt commit on the one captured SQLite handle.
    /// An interrupted transport ACK can therefore never repeat a native edit.
    func commitMiniApps(_ intent: AnnotationLocalEditorIntent,
                        resultJSON: String) throws -> AnnotationLocalEditorCommitted {
        let result = try JSONDecoder().decode(MiniAppResult.self, from: Data(resultJSON.utf8))
        guard let documentID = intent.snapshot.annotation.ckRecordId,
              UUID(uuidString: documentID) == annotationUUID,
              result.requestID == intent.mutationID, result.status == .success,
              result.operation == .insert || result.operation == .replaceSelection
                || result.operation == .replaceDocument else {
            throw MiniAppBridgeError.conflictingResult
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let identity = String(decoding: try encoder.encode(result), as: UTF8.self)
        guard identity.utf8.elementsEqual(resultJSON.utf8) else {
            throw MiniAppBridgeError.conflictingResult
        }
        let committed: OtzariaMiniAppsReceiptJournal.Commit<AnnotationLocalEditorCommitted> =
            try OtzariaMiniAppsReceiptJournal.commit(requestID: intent.mutationID,
                resultJSON: identity, documentID: documentID,
                database: connection.database,
                validate: { try self.connection.requireCurrent(owner: self.owner) },
                read: { id in
                    guard id == self.annotationID else { return nil }
                    return try self.commit(intent)
                }, apply: {
                    let saved = try self.commit(intent)
                    guard saved.snapshot.annotation.id == self.annotationID,
                          saved.snapshot.annotationUUID == self.annotationUUID else {
                        throw AnnotationLocalEditorError.wrongOwner
                    }
                    return (id: self.annotationID, value: saved)
                })
        return committed.value
    }
}
#endif
#endif
