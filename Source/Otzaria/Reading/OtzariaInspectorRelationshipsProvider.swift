import Foundation

enum OtzariaInspectorDocumentMapper {
    static func section(
        from unit: OtzariaReadingUnit,
        previousStartLineIndex: Int?,
        nextStartLineIndex: Int?
    ) -> LibraryTextSection {
        let locator = lineLocator(bookID: unit.bookId, lineIndex: unit.startLineIndex)
        return LibraryTextSection(
            locator: locator,
            displayRef: unit.title ?? unit.heRef ?? locator.persistenceKey,
            heRef: unit.heRef,
            segments: unit.lineAnchors.map { anchor in
                LibraryTextSegment(
                    locator: lineLocator(bookID: unit.bookId, lineIndex: anchor.lineIndex),
                    heRef: anchor.heRef,
                    primaryText: anchor.text,
                    translation: nil
                )
            },
            previous: previousStartLineIndex.map { lineLocator(bookID: unit.bookId, lineIndex: $0) },
            next: nextStartLineIndex.map { lineLocator(bookID: unit.bookId, lineIndex: $0) },
            versions: [TextVersionMetadata(
                title: "Otzaria local library",
                language: "he",
                actualLanguage: "he",
                sourceURL: nil,
                license: nil,
                notes: nil,
                isPrimary: true
            )],
            links: [],
            origin: .offline
        )
    }

    static func section(
        from unit: OtzariaReadingUnit,
        previous: OtzariaReadingUnitDescriptor?,
        next: OtzariaReadingUnitDescriptor?
    ) -> LibraryTextSection {
        section(
            from: unit,
            previousStartLineIndex: previous?.startLineIndex,
            nextStartLineIndex: next?.startLineIndex
        )
    }

    static func section(
        from unit: OtzariaReadingUnit,
        previous: OtzariaReadingUnit?,
        next: OtzariaReadingUnit?
    ) -> LibraryTextSection {
        section(
            from: unit,
            previousStartLineIndex: previous?.startLineIndex,
            nextStartLineIndex: next?.startLineIndex
        )
    }

    private static func lineLocator(bookID: Int, lineIndex: Int) -> TextLocator {
        TextLocator(backend: .otzaria, workKey: "book:\(bookID)", position: .legacyLine(lineIndex))
    }
}

struct OtzariaInspectorRelationshipsProvider: LibraryRelationshipsProviding, @unchecked Sendable {
    func links(for locator: TextLocator) async throws -> [LibraryRelatedSource] {
        #if os(iOS)
        let backgroundTask = Task.detached(priority: .userInitiated) { () -> [LibraryRelatedSource] in
            try Task.checkCancellation()
            guard locator.backend == .otzaria,
                  let bookID = Self.bookID(from: locator.workKey),
                  case .legacyLine(let lineIndex) = locator.position,
                  let unit = OtzariaMaktabahBridge.shared.getReadingUnit(
                    bookId: bookID,
                    containingLineIndex: lineIndex,
                    mode: OtzariaMaktabahBridge.shared.currentReadingUnitMode
                  ),
                  let anchor = unit.lineAnchors.first(where: { $0.lineIndex == lineIndex }) else {
                throw LibraryBackendError.invalidLocator
            }
            try Task.checkCancellation()
            let sources = try OtzariaMaktabahBridge.shared.fetchLinksForLine(anchor).map(Self.map)
            var seen = Set<String>()
            var deduplicated: [LibraryRelatedSource] = []
            for source in sources {
                let key = "\(source.locator.persistenceKey)|\(source.type)|\(source.category)"
                if seen.insert(key).inserted {
                    deduplicated.append(source)
                }
            }
            return deduplicated
        }

        return try await withTaskCancellationHandler(
            operation: { try await backgroundTask.value },
            onCancel: { backgroundTask.cancel() }
        )
        #else
        throw LibraryBackendError.capabilityUnavailable
        #endif
    }

    func topics(for locator: TextLocator) async throws -> [LibraryRelatedTopic] {
        guard locator.backend == .otzaria else { throw LibraryBackendError.invalidLocator }
        return []
    }

    static func map(_ source: OtzariaLinkedSource) -> LibraryRelatedSource {
        let category = source.connectionType.caseInsensitiveCompare("COMMENTARY") == .orderedSame
            ? "Commentary"
            : (source.linkedCategoryPath.isEmpty
                ? source.localizedConnectionType
                : source.linkedCategoryPath.joined(separator: " / "))
        let resolved = OtzariaCommentatorResolver.resolve(
            bookID: source.linkedBookId,
            bookTitle: source.bookTitle,
            heRef: source.heRef
        )
        return LibraryRelatedSource(
            locator: TextLocator(
                backend: .otzaria,
                workKey: "book:\(source.linkedBookId)",
                position: .legacyLine(source.linkedLineIndex)
            ),
            displayRef: source.bookTitle,
            heRef: source.heRef,
            category: category,
            type: source.connectionType,
            collectiveTitle: resolved.collectiveTitle,
            heCollectiveTitle: resolved.hebrewCollectiveTitle,
            primaryText: source.text,
            translation: nil,
            versionTitle: nil,
            heVersionTitle: nil,
            license: nil,
            anchorRefs: [source.heRef].compactMap { $0 }
        )
    }

    private static func bookID(from workKey: String) -> Int? {
        guard workKey.hasPrefix("book:") else { return nil }
        return Int(workKey.dropFirst("book:".count))
    }
}

struct OtzariaCommentatorIdentity: Sendable, Equatable {
    let commentatorID: String
    let commentatorName: String
    let hebrewCommentatorName: String?
    let workTitle: String
    let hebrewWorkTitle: String?
    let collectiveTitle: String
    let hebrewCollectiveTitle: String?

    init(
        commentatorID: String,
        commentatorName: String,
        hebrewCommentatorName: String? = nil,
        workTitle: String,
        hebrewWorkTitle: String? = nil,
        collectiveTitle: String,
        hebrewCollectiveTitle: String? = nil
    ) {
        self.commentatorID = commentatorID
        self.commentatorName = commentatorName
        self.hebrewCommentatorName = hebrewCommentatorName
        self.workTitle = workTitle
        self.hebrewWorkTitle = hebrewWorkTitle
        self.collectiveTitle = collectiveTitle
        self.hebrewCollectiveTitle = hebrewCollectiveTitle
    }
}

enum OtzariaCommentatorResolver {
    static func resolve(
        bookID: Int?,
        bookTitle: String,
        heRef: String? = nil,
        authorNameFromDB: String? = nil
    ) -> OtzariaCommentatorIdentity {
        let trimmedTitle = bookTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedAuthor: String? = {
            if let dbAuthor = authorNameFromDB?.trimmingCharacters(in: .whitespacesAndNewlines), !dbAuthor.isEmpty {
                return dbAuthor
            }
            return extractAuthor(from: trimmedTitle)
        }()

        let workTitle = (heRef?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? trimmedTitle
        let heWorkTitle = isHebrewText(workTitle) ? workTitle : nil

        if let author = resolvedAuthor, !author.isEmpty {
            let normalizedAuthor = normalizeAuthorName(author)
            let heName = isHebrewText(normalizedAuthor) ? normalizedAuthor : nil
            return OtzariaCommentatorIdentity(
                commentatorID: "author:\(normalizedAuthor)",
                commentatorName: normalizedAuthor,
                hebrewCommentatorName: heName,
                workTitle: workTitle,
                hebrewWorkTitle: heWorkTitle,
                collectiveTitle: normalizedAuthor,
                hebrewCollectiveTitle: heName
            )
        }

        let fallbackID = bookID.map { "otzaria:book:\($0)" } ?? "title:\(trimmedTitle)"
        let heTitle = isHebrewText(trimmedTitle) ? trimmedTitle : nil
        return OtzariaCommentatorIdentity(
            commentatorID: fallbackID,
            commentatorName: trimmedTitle,
            hebrewCommentatorName: heTitle,
            workTitle: workTitle,
            hebrewWorkTitle: heWorkTitle,
            collectiveTitle: trimmedTitle,
            hebrewCollectiveTitle: heTitle
        )
    }

    static func extractAuthor(from title: String) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Check " על " separator (Hebrew)
        if let range = trimmed.range(of: " על ") {
            let prefix = String(trimmed[..<range.lowerBound])
            let author = normalizeAuthorName(prefix)
            if !author.isEmpty {
                return author
            }
        }

        // Check " on " separator (English)
        if let range = trimmed.range(of: " on ", options: .caseInsensitive) {
            var prefix = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let enPrefixes = ["Commentary of ", "Commentary on ", "Notes on ", "Chiddushei "]
            for p in enPrefixes {
                if prefix.lowercased().hasPrefix(p.lowercased()) {
                    prefix = String(prefix.dropFirst(p.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            if !prefix.isEmpty {
                return prefix
            }
        }

        // Check "חידושי " prefix without " על "
        if trimmed.hasPrefix("חידושי ") {
            let remainder = String(trimmed.dropFirst("חידושי ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if remainder.hasPrefix("אגדות ") {
                let author = String(remainder.dropFirst("אגדות ".count))
                return normalizeAuthorName(author)
            }
            if remainder.hasPrefix("הלכות ") {
                let author = String(remainder.dropFirst("הלכות ".count))
                return normalizeAuthorName(author)
            }
            return normalizeAuthorName(remainder)
        }

        // Check "פירוש " prefix
        if trimmed.hasPrefix("פירוש ") {
            let remainder = String(trimmed.dropFirst("פירוש ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return normalizeAuthorName(remainder)
        }

        // Check "ביאור " prefix
        if trimmed.hasPrefix("ביאור ") {
            let remainder = String(trimmed.dropFirst("ביאור ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return normalizeAuthorName(remainder)
        }

        return nil
    }

    static func normalizeAuthorName(_ raw: String) -> String {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixesToStrip = ["פירוש ", "ביאור ", "חידושי ", "הערות ", "הגהות ", "קונטרס ", "ספר "]
        for prefix in prefixesToStrip {
            if name.hasPrefix(prefix) {
                name = String(name.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        let hePrefixAcronyms = ["הרמב\"ן", "הריטב\"א", "הרשב\"א", "הר\"ן", "הרא\"ש", "הרמב\"ם", "המהרש\"א", "המהרש\"ל", "הגר\"א"]
        for acronym in hePrefixAcronyms {
            if name == acronym {
                name = String(acronym.dropFirst())
                break
            }
        }
        return name
    }

    private static func isHebrewText(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if (0x0590...0x05FF).contains(scalar.value) { return true }
        }
        return false
    }
}
