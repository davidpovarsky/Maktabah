#if os(iOS)
import Foundation
import TorahInspectorCore

@MainActor
final class MaktabahTorahInspectorSession {
    private let coordinator: BackendCoordinator
    private let otzaria: OtzariaMaktabahBridge
    private let preferredMode: LibraryReaderTextMode
    private weak var readerViewModel: ReaderViewModel?
    private var locatorsByReference: [String: TextLocator] = [:]
    private var otzariaUnitsByReference: [String: OtzariaReadingUnit] = [:]
    private var otzariaUnitsLRU: [String] = []
    private let otzariaUnitsCapacity = 20
    private var otzariaUnitLinksByReference: [String: [TorahLinkedSource]] = [:]
    private var otzariaUnitLinksLRU: [String] = []
    private let otzariaUnitLinksCapacity = 30

    convenience init() {
        self.init(
            coordinator: .shared,
            preferredMode: UserDefaults.standard.libraryReaderTextMode
        )
    }

    convenience init(
        viewModel: ReaderViewModel,
        preferredMode: LibraryReaderTextMode = UserDefaults.standard.libraryReaderTextMode
    ) {
        self.init(
            coordinator: .shared,
            otzaria: .shared,
            preferredMode: preferredMode,
            viewModel: viewModel
        )
    }

    init(
        coordinator: BackendCoordinator,
        otzaria: OtzariaMaktabahBridge = .shared,
        preferredMode: LibraryReaderTextMode = UserDefaults.standard.libraryReaderTextMode,
        viewModel: ReaderViewModel? = nil
    ) {
        self.coordinator = coordinator
        self.otzaria = otzaria
        self.preferredMode = preferredMode
        self.readerViewModel = viewModel
    }

    lazy var repository = TorahInspectorRepository(
        textFetcher: { [weak self] reference, providerID in
            guard let self else { throw TorahError.missingProvider }
            return try await self.document(for: reference, providerID: providerID)
        },
        linksFetcher: { [weak self] reference, providerID in
            guard let self else { throw TorahError.missingProvider }
            return try await self.links(for: reference, providerID: providerID)
        },
        topicsFetcher: { [weak self] reference, providerID in
            guard let self else { throw TorahError.missingProvider }
            return try await self.topics(for: reference, providerID: providerID)
        },
        notesFetcher: { [weak self] selection in
            guard let self else { throw TorahError.missingProvider }
            return await self.notes(for: selection)
        }
    )

    func selection(
        sefariaLocator: TextLocator?,
        otzariaLine: OtzariaLineAnchor?
    ) -> TorahInspectorSelection? {
        if let locator = sefariaLocator,
           let sectionLocator = readerViewModel?.backendSection?.locator,
           locator != sectionLocator {
            let reference = Self.reference(for: locator)
            let sectionReference = Self.reference(for: sectionLocator)
            remember(locator, for: reference)
            remember(sectionLocator, for: sectionReference)
            return TorahInspectorSelection(
                providerID: locator.backend.rawValue,
                canonicalRef: sectionReference,
                preferredSegmentRef: reference,
                scope: .segment
            )
        }
        if let line = otzariaLine,
           let unit = otzaria.cachedReadingUnit(
            bookId: line.bookId,
            contentId: line.lineIndex,
            mode: otzaria.currentReadingUnitMode
           ) ?? otzaria.getReadingUnit(
            bookId: line.bookId,
            containingLineIndex: line.lineIndex,
            mode: otzaria.currentReadingUnitMode
           ) {
            return otzariaSelection(unit: unit, selectedLineIndex: line.lineIndex)
        }
        return currentUnitSelection()
    }

    func locator(for selection: TorahInspectorSelection) -> TextLocator? {
        locator(
            for: selection.preferredSegmentRef ?? selection.canonicalRef,
            providerID: selection.providerID
        )
    }

    private func currentUnitSelection() -> TorahInspectorSelection? {
        guard let viewModel = readerViewModel else { return nil }
        if coordinator.activeBackendID == .sefaria,
           let locator = viewModel.backendSection?.locator {
            let reference = Self.reference(for: locator)
            remember(locator, for: reference)
            return TorahInspectorSelection(
                providerID: BackendID.sefaria.rawValue,
                canonicalRef: reference,
                scope: .section
            )
        }
        guard coordinator.activeBackendID == .otzaria,
              let bookID = viewModel.currentBook?.id,
              let unit = otzaria.cachedReadingUnit(
                bookId: bookID,
                contentId: viewModel.currentContentId,
                mode: otzaria.currentReadingUnitMode
              ) ?? otzaria.getReadingUnit(
                bookId: bookID,
                containingLineIndex: viewModel.currentContentId,
                mode: otzaria.currentReadingUnitMode
              ) else { return nil }
        return otzariaSelection(unit: unit, selectedLineIndex: nil)
    }

    private func otzariaSelection(
        unit: OtzariaReadingUnit,
        selectedLineIndex: Int?
    ) -> TorahInspectorSelection {
        let sectionLocator = TextLocator(
            backend: .otzaria,
            workKey: "book:\(unit.bookId)",
            position: .legacyLine(unit.startLineIndex)
        )
        let sectionReference = Self.unitReference(for: unit)
        remember(sectionLocator, for: sectionReference)
        remember(unit, for: sectionReference)
        guard let selectedLineIndex else {
            return TorahInspectorSelection(
                providerID: BackendID.otzaria.rawValue,
                canonicalRef: sectionReference,
                scope: .section
            )
        }
        let selectedLocator = TextLocator(
            backend: .otzaria,
            workKey: "book:\(unit.bookId)",
            position: .legacyLine(selectedLineIndex)
        )
        let selectedReference = Self.reference(for: selectedLocator)
        remember(selectedLocator, for: selectedReference)
        return TorahInspectorSelection(
            providerID: BackendID.otzaria.rawValue,
            canonicalRef: sectionReference,
            preferredSegmentRef: selectedReference,
            scope: .segment
        )
    }

    private func document(for reference: String, providerID: String?) async throws -> TorahTextDocument {
        let locator = try activeLocator(for: reference, providerID: providerID)
        switch locator.backend {
        case .sefaria:
            do {
                let section = try await coordinator.section(at: locator)
                return try map(section, requestedReference: reference)
            } catch LibraryBackendError.unavailableOffline {
                throw TorahError.storage(String(localized: "This source is unavailable offline."))
            }
        case .otzaria:
            return try mapOtzariaDocument(locator: locator, requestedReference: reference)
        }
    }

    private func links(for reference: String, providerID: String?) async throws -> [TorahLinkedSource] {
        let locator = try activeLocator(for: reference, providerID: providerID)
        let key = cacheKey(providerID: locator.backend.rawValue, reference: reference)
        if locator.backend == .otzaria, let cached = otzariaUnitLinksByReference[key] {
            return cached
        }

        if locator.backend == .sefaria {
            let sources = try await coordinator.links(for: locator)
            let mappedSources: [TorahLinkedSource] = sources.map { source in
                let sourceReference = Self.reference(for: source.locator)
                remember(source.locator, for: sourceReference)
                let collectiveTitle = source.collectiveTitle
                let hebrewCollectiveTitle = source.heCollectiveTitle
                let commentatorID: String?
                let commentatorName: String?
                let hebrewCommentatorName: String?
                if let collective = source.collectiveTitle ?? source.heCollectiveTitle, !collective.isEmpty {
                    commentatorID = "author:\(collective.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))"
                    commentatorName = source.heCollectiveTitle ?? source.collectiveTitle
                    hebrewCommentatorName = source.heCollectiveTitle
                } else {
                    commentatorID = nil
                    commentatorName = nil
                    hebrewCommentatorName = nil
                }
                return TorahLinkedSource(
                    sourceRef: sourceReference,
                    sourceHebrewRef: preferredMode != .translation ? source.heRef : nil,
                    category: source.category,
                    type: source.type,
                    collectiveTitle: collectiveTitle,
                    hebrewCollectiveTitle: hebrewCollectiveTitle,
                    commentatorID: commentatorID,
                    commentatorName: commentatorName,
                    hebrewCommentatorName: hebrewCommentatorName,
                    workTitle: source.heRef ?? source.versionTitle ?? source.displayRef,
                    hebrewWorkTitle: source.heRef,
                    hebrewText: source.primaryText?.readerPlainText,
                    englishText: source.translation?.readerPlainText,
                    versionTitle: source.versionTitle,
                    hebrewVersionTitle: source.heVersionTitle,
                    license: source.license,
                    canonicalBookID: "\(source.locator.backend.rawValue):\(source.locator.workKey)",
                    anchorRefs: source.anchorRefs,
                    relationshipKind: Self.relationshipKind(category: source.category, type: source.type),
                    semanticCategory: Self.semanticCategory(category: source.category, type: source.type),
                    rawProviderPayload: source.locator.persistenceKey
                )
            }
            return mappedSources
        }

        // Otzaria backend: execute heavy SQLite queries, author lookup, and mapping off MainActor
        let initialGeneration = coordinator.generation
        let bridge = self.otzaria
        let currentMode = bridge.currentReadingUnitMode
        let preferredMode = self.preferredMode

        var resolvedBookID: Int?
        var resolvedLineIndices: [Int]?
        var resolvedUnit: OtzariaReadingUnit?

        if reference.hasPrefix("otzaria:unit:") {
            if let cached = otzariaUnitsByReference[key] {
                resolvedUnit = cached
            } else if let bookID = Self.otzariaBookID(from: locator.workKey),
                      case .legacyLine(let lineIndex) = locator.position {
                resolvedUnit = bridge.cachedReadingUnit(bookId: bookID, contentId: lineIndex, mode: currentMode)
                resolvedBookID = bookID
                resolvedLineIndices = [lineIndex]
            }
        } else if let bookID = Self.otzariaBookID(from: locator.workKey),
                  case .legacyLine(let lineIndex) = locator.position {
            resolvedBookID = bookID
            resolvedLineIndices = [lineIndex]
        }

        let isUnitRef = reference.hasPrefix("otzaria:unit:")
        let cachedUnit = resolvedUnit

        let backgroundResult = try await Task.detached(priority: .userInitiated) { () -> (sources: [TorahLinkedSource], locators: [(String, TextLocator)], unitToRemember: OtzariaReadingUnit?) in
            try Task.checkCancellation()

            let rawSources: [OtzariaLinkedSource]
            var builtUnit: OtzariaReadingUnit? = cachedUnit

            if isUnitRef {
                let unit: OtzariaReadingUnit?
                if let built = builtUnit {
                    unit = built
                } else if let bkid = resolvedBookID, let lineIndex = resolvedLineIndices?.first {
                    unit = bridge.getReadingUnit(bookId: bkid, containingLineIndex: lineIndex, mode: currentMode)
                    builtUnit = unit
                } else {
                    unit = nil
                }

                if let unit {
                    rawSources = try bridge.getLinksMetadataForReadingUnit(unit)
                } else {
                    rawSources = []
                }
            } else if let bkid = resolvedBookID, let lines = resolvedLineIndices {
                rawSources = try bridge.getLinksMetadataForLineIndices(bookID: bkid, sourceLineIndices: lines)
            } else {
                rawSources = []
            }

            try Task.checkCancellation()

            let librarySources = rawSources.map(OtzariaInspectorRelationshipsProvider.map)
            let bookIds = Array(Set(librarySources.compactMap { source -> Int? in
                guard source.locator.backend == .otzaria else { return nil }
                return Self.otzariaBookID(from: source.locator.workKey)
            }))
            let authorNamesByBookId = bridge.authorNames(forBookIds: bookIds)

            try Task.checkCancellation()

            var locatorsToRemember: [(String, TextLocator)] = []
            let mapped = librarySources.map { source -> TorahLinkedSource in
                let sourceReference = Self.reference(for: source.locator)
                locatorsToRemember.append((sourceReference, source.locator))

                let usesHebrewReference = preferredMode != .translation
                let bookID = Self.otzariaBookID(from: source.locator.workKey)
                let authorFromDB = bookID.flatMap { authorNamesByBookId[$0] }
                let identity = OtzariaCommentatorResolver.resolve(
                    bookID: bookID,
                    bookTitle: source.displayRef,
                    heRef: source.heRef,
                    authorNameFromDB: authorFromDB
                )

                return TorahLinkedSource(
                    sourceRef: sourceReference,
                    sourceHebrewRef: usesHebrewReference ? source.heRef : nil,
                    category: source.category,
                    type: source.type,
                    collectiveTitle: identity.collectiveTitle,
                    hebrewCollectiveTitle: identity.hebrewCollectiveTitle,
                    commentatorID: identity.commentatorID,
                    commentatorName: identity.commentatorName,
                    hebrewCommentatorName: identity.hebrewCommentatorName,
                    workTitle: identity.workTitle,
                    hebrewWorkTitle: identity.hebrewWorkTitle,
                    hebrewText: source.primaryText?.readerPlainText,
                    englishText: source.translation?.readerPlainText,
                    versionTitle: source.versionTitle,
                    hebrewVersionTitle: source.heVersionTitle,
                    license: source.license,
                    canonicalBookID: "\(source.locator.backend.rawValue):\(source.locator.workKey)",
                    anchorRefs: source.anchorRefs,
                    relationshipKind: Self.relationshipKind(category: source.category, type: source.type),
                    semanticCategory: Self.semanticCategory(category: source.category, type: source.type),
                    rawProviderPayload: source.locator.persistenceKey
                )
            }

            return (mapped, locatorsToRemember, builtUnit)
        }.value

        guard !Task.isCancelled, coordinator.generation == initialGeneration else {
            return []
        }

        for (sourceReference, loc) in backgroundResult.locators {
            remember(loc, for: sourceReference)
        }
        if let unit = backgroundResult.unitToRemember {
            remember(unit, for: reference)
        }
        remember(links: backgroundResult.sources, for: key)
        return backgroundResult.sources
    }

    private func topics(for reference: String, providerID: String?) async throws -> [TorahLinkedTopic] {
        let locator = try activeLocator(for: reference, providerID: providerID)
        return try await coordinator.topics(for: locator).map {
            TorahLinkedTopic(slug: $0.slug, titleHe: $0.titleHe, titleEn: $0.titleEn)
        }
    }

    private func notes(for selection: TorahInspectorSelection) -> [TorahInspectorNote] {
        guard let viewModel = readerViewModel,
              let selectedLocator = locator(for: selection),
              selectedLocator.backend == coordinator.activeBackendID else { return [] }
        let selectedRange = viewModel.selectedSegmentRange
        var allByID: [Int64: Annotation] = [:]
        var unpersisted: [Annotation] = []
        for ann in viewModel.currentAnnotations {
            if let id = ann.id {
                allByID[id] = ann
            } else {
                unpersisted.append(ann)
            }
        }
        if let bkId = viewModel.currentBook?.id {
            for ann in AnnotationManager.shared.loadAnnotations(bkId: bkId) {
                if let id = ann.id {
                    allByID[id] = ann
                }
            }
        }
        for ann in AnnotationManager.shared.loadAnnotations() {
            if let id = ann.id {
                allByID[id] = ann
            }
        }
        for ann in viewModel.currentAnnotations {
            if let id = ann.id {
                allByID[id] = ann
            } else {
                unpersisted.append(ann)
            }
        }
        let candidateAnnotations = Array(allByID.values) + unpersisted
        return candidateAnnotations.compactMap { annotation in
            let annLoc = annotation.backendLocator
                ?? (annotation.bkId < 0 ? LegacyIdentityRegistry.shared.locator(for: annotation.bkId) : nil)
                ?? (annotation.bkId == viewModel.currentBook?.id ? viewModel.currentBook?.backendLocator : nil)

            let hasMatchingLocator: Bool
            if let annLoc {
                let annRef = Self.reference(for: annLoc)
                let matchesDirect = annLoc.persistenceKey == selectedLocator.persistenceKey
                    || (annLoc.backend == selectedLocator.backend && annLoc.workKey == selectedLocator.workKey && annLoc.position == selectedLocator.position)
                let matchesPreferred = selection.preferredSegmentRef.map { pref in
                    annLoc.position == .canonicalRef(pref) || annRef == pref
                } ?? false
                let matchesCanonical = (annRef == selection.canonicalRef)
                let matchesWorkKey = (annLoc.backend == selectedLocator.backend && annLoc.workKey == selectedLocator.workKey)
                hasMatchingLocator = matchesDirect || matchesPreferred || matchesCanonical
                    || (matchesWorkKey && selection.scope == .segment && (annRef == (selection.preferredSegmentRef ?? selection.canonicalRef)))
            } else {
                hasMatchingLocator = false
            }
            let isInsideSelectedUnit = annLoc.map {
                contains($0, in: selection)
            } ?? false
            let isSameBookOrBackend = (annLoc?.backend == selectedLocator.backend && annLoc?.workKey == selectedLocator.workKey)
                || (annLoc == nil && annotation.bkId == viewModel.currentBook?.id)
            let overlapsSelectedRange = isSameBookOrBackend && (selectedRange.map {
                NSIntersectionRange(annotation.range, $0).length > 0
                    || NSIntersectionRange(annotation.rangeDiacritics, $0).length > 0
            } ?? false)
            guard hasMatchingLocator || isInsideSelectedUnit || overlapsSelectedRange,
                  let noteBody = annotation.note?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !noteBody.isEmpty else { return nil }
            return TorahInspectorNote(
                id: annotation.id.map(String.init) ?? "\(annotation.createdAt)",
                selectedText: annotation.context.isEmpty ? (selection.preferredSegmentRef ?? selection.canonicalRef) : annotation.context,
                note: noteBody,
                tag: annotation.tags.first
            )
        }
    }

    private func contains(
        _ locator: TextLocator,
        in selection: TorahInspectorSelection
    ) -> Bool {
        guard locator.backend.rawValue == selection.providerID else { return false }
        switch (locator.backend, locator.position) {
        case (.otzaria, .legacyLine(let lineIndex)):
            guard let unit = otzariaUnitsByReference[cacheKey(
                providerID: selection.providerID,
                reference: selection.canonicalRef
            )] else { return false }
            return locator.workKey == "book:\(unit.bookId)"
                && (unit.startLineIndex...unit.endLineIndex).contains(lineIndex)
        case (.sefaria, .canonicalRef(let reference)):
            let section = SefariaRef.canonicalInput(selection.canonicalRef)
            let candidate = SefariaRef.canonicalInput(reference)
            return candidate == section || candidate.hasPrefix(section + ":")
                || section == candidate || section.hasPrefix(candidate + ":")
        default:
            return false
        }
    }

    private func map(
        _ section: LibraryTextSection,
        requestedReference: String,
        hebrewSectionRef: String? = nil,
        rawProviderPayload: String? = nil
    ) throws -> TorahTextDocument {
        let mappedSegments = section.segments.enumerated().compactMap { index, segment -> TorahTextSegment? in
            let text = LibraryPresentationPolicy.text(
                source: segment.primaryText,
                translation: segment.translation,
                mode: preferredMode
            )
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            let reference = Self.reference(for: segment.locator)
            remember(segment.locator, for: reference)
            let heRef = preferredMode == .translation ? nil : (segment.heRef?.isEmpty == false ? segment.heRef : "שורה \(index + 1)")
            return TorahTextSegment(
                canonicalRef: reference,
                hebrewRef: heRef,
                text: text.readerPlainText,
                ordinal: index + 1
            )
        }
        guard !mappedSegments.isEmpty else { throw TorahError.noText }
        if let previous = section.previous { remember(previous, for: Self.reference(for: previous)) }
        if let next = section.next { remember(next, for: Self.reference(for: next)) }
        let version = preferredMode == .translation
            ? section.versions.first(where: {
                LibraryTextDirection.inferred(from: $0.actualLanguage ?? $0.language) == .leftToRight
            }) ?? section.versions.first(where: \.isPrimary) ?? section.versions.first
            : section.versions.first(where: \.isPrimary) ?? section.versions.first
        let sectionReference = Self.reference(for: section.locator)
        remember(section.locator, for: sectionReference)
        return TorahTextDocument(
            providerID: section.locator.backend.rawValue,
            requestedRef: requestedReference,
            canonicalRef: sectionReference,
            hebrewRef: preferredMode == .translation ? nil : section.heRef,
            sectionRef: sectionReference,
            hebrewSectionRef: preferredMode == .translation ? nil : (hebrewSectionRef ?? section.heRef),
            segments: mappedSegments,
            previousSectionRef: section.previous.map { Self.reference(for: $0) },
            nextSectionRef: section.next.map { Self.reference(for: $0) },
            version: TorahTextVersionMetadata(
                language: version?.language ?? "he",
                actualLanguage: version?.actualLanguage,
                versionTitle: version?.title ?? section.locator.backend.displayName,
                license: version?.license,
                direction: (version?.actualLanguage ?? version?.language) == "he" ? "rtl" : "ltr"
            ),
            rawProviderPayload: rawProviderPayload ?? "{\"origin\":\"\(section.origin.rawValue)\"}"
        )
    }

    private func mapOtzariaDocument(
        locator: TextLocator,
        requestedReference: String
    ) throws -> TorahTextDocument {
        guard let bookID = Self.otzariaBookID(from: locator.workKey),
              case .legacyLine(let lineIndex) = locator.position else {
            throw TorahError.invalidReference
        }

        // Fast on-demand commentary expansion for single-line segments without loading the full chapter
        if !requestedReference.hasPrefix("otzaria:unit:") {
            if let lineData = try otzaria.fetchLineContent(bookId: bookID, lineIndex: lineIndex) {
                let plain = lineData.content.otsariaPlainText
                let segment = TorahTextSegment(
                    locator: locator,
                    canonicalRef: requestedReference,
                    primaryText: plain,
                    hebrewRef: lineData.heRef,
                    hebrewText: plain,
                    englishText: nil,
                    category: .commentary,
                    rawProviderPayload: "{\"bookId\":\(bookID),\"lineIndex\":\(lineIndex)}"
                )
                let bookTitle = otzaria.bookMetadata(for: bookID)?.title ?? "Commentary"
                return TorahTextDocument(
                    providerID: BackendID.otzaria.rawValue,
                    requestedRef: requestedReference,
                    canonicalRef: requestedReference,
                    hebrewRef: lineData.heRef ?? bookTitle,
                    sectionRef: requestedReference,
                    hebrewSectionRef: lineData.heRef ?? bookTitle,
                    segments: [segment],
                    previousSectionRef: nil,
                    nextSectionRef: nil,
                    version: TorahTextVersionMetadata(
                        language: "he",
                        actualLanguage: "he",
                        versionTitle: bookTitle,
                        license: nil,
                        direction: "rtl"
                    ),
                    rawProviderPayload: "{\"bookId\":\(bookID),\"lineIndex\":\(lineIndex)}"
                )
            }
        }

        guard let unit = otzaria.getReadingUnit(
            bookId: bookID,
            containingLineIndex: lineIndex,
            mode: otzaria.currentReadingUnitMode
        ) else { throw TorahError.invalidReference }

        let previous = otzaria.getPreviousReadingUnitDescriptor(
            bookId: bookID,
            beforeLineIndex: unit.startLineIndex,
            mode: otzaria.currentReadingUnitMode
        )
        let next = otzaria.getNextReadingUnitDescriptor(
            bookId: bookID,
            afterLineIndex: unit.endLineIndex,
            mode: otzaria.currentReadingUnitMode
        )
        let section = OtzariaInspectorDocumentMapper.section(from: unit, previous: previous, next: next)
        return try map(
            section,
            requestedReference: requestedReference,
            hebrewSectionRef: unit.title ?? unit.heRef,
            rawProviderPayload: "{\"bookId\":\(bookID),\"unitId\":\"\(unit.id)\"}"
        )
    }

    private func activeLocator(for reference: String, providerID: String?) throws -> TextLocator {
        guard let providerID,
              let backend = BackendID(rawValue: providerID),
              backend == coordinator.activeBackendID else {
            throw TorahError.missingProvider
        }
        guard let locator = locator(for: reference, providerID: providerID), locator.backend == backend else {
            throw TorahError.invalidReference
        }
        return locator
    }

    private func locator(for reference: String, providerID: String) -> TextLocator? {
        if let remembered = locatorsByReference[cacheKey(providerID: providerID, reference: reference)] {
            return remembered
        }
        switch BackendID(rawValue: providerID) {
        case .sefaria:
            let knownTitles = LibraryDataManager.shared.booksById.values.map(\.book)
            let workKey: String
            if let resolved = SefariaRef.workKey(from: reference, knownTitles: knownTitles) {
                workKey = resolved
            } else if let match = reference.range(of: #"\s+\d+.*$"#, options: .regularExpression) {
                workKey = String(reference[..<match.lowerBound])
            } else {
                workKey = reference
            }
            return TextLocator(backend: .sefaria, workKey: workKey, position: .canonicalRef(reference))
        case .otzaria:
            let parts = reference.split(separator: ":", omittingEmptySubsequences: false)
            if parts.count >= 6, parts[0] == "otzaria", parts[1] == "unit", parts[2] == "v1",
               let bookID = Int(parts[3]), let startLine = Int(parts[5]) {
                return TextLocator(
                    backend: .otzaria,
                    workKey: "book:\(bookID)",
                    position: .legacyLine(startLine)
                )
            }
            guard parts.count == 4, parts[0] == "otzaria", parts[1] == "v1",
                  let bookID = Int(parts[2]), let lineIndex = Int(parts[3]) else { return nil }
            return TextLocator(
                backend: .otzaria,
                workKey: "book:\(bookID)",
                position: .legacyLine(lineIndex)
            )
        case nil:
            return nil
        }
    }

    private func remember(_ locator: TextLocator, for reference: String) {
        locatorsByReference[cacheKey(providerID: locator.backend.rawValue, reference: reference)] = locator
    }

    private func remember(_ unit: OtzariaReadingUnit, for reference: String) {
        let key = cacheKey(providerID: BackendID.otzaria.rawValue, reference: reference)
        otzariaUnitsByReference[key] = unit
        otzariaUnitsLRU.removeAll { $0 == key }
        otzariaUnitsLRU.append(key)
        while otzariaUnitsLRU.count > otzariaUnitsCapacity {
            let oldest = otzariaUnitsLRU.removeFirst()
            otzariaUnitsByReference.removeValue(forKey: oldest)
        }
    }

    private func remember(links: [TorahLinkedSource], for key: String) {
        otzariaUnitLinksByReference[key] = links
        otzariaUnitLinksLRU.removeAll { $0 == key }
        otzariaUnitLinksLRU.append(key)
        while otzariaUnitLinksLRU.count > otzariaUnitLinksCapacity {
            let oldest = otzariaUnitLinksLRU.removeFirst()
            otzariaUnitLinksByReference.removeValue(forKey: oldest)
        }
    }

    private func cacheKey(providerID: String, reference: String) -> String {
        "\(providerID):\(reference)"
    }

    private static func reference(for locator: TextLocator) -> String {
        switch (locator.backend, locator.position) {
        case (.sefaria, .canonicalRef(let reference)):
            return reference
        case (.otzaria, .legacyLine(let lineIndex)):
            return "otzaria:v1:\(otzariaBookID(from: locator.workKey) ?? 0):\(lineIndex)"
        default:
            return locator.persistenceKey
        }
    }

    private static func unitReference(for unit: OtzariaReadingUnit) -> String {
        "otzaria:unit:v1:\(unit.bookId):\(unit.id):\(unit.startLineIndex):\(unit.endLineIndex)"
    }

    private static func otzariaBookID(from workKey: String) -> Int? {
        guard workKey.hasPrefix("book:") else { return nil }
        return Int(workKey.dropFirst("book:".count))
    }

    private static func relationshipKind(
        category: String,
        type: String
    ) -> TorahRelationshipKind {
        let tokens = "\(category) \(type)".lowercased()
        if tokens.contains("quoting commentary") { return .quotingCommentary }
        return tokens.contains("commentary") ? .commentary : .link
    }

    private static func semanticCategory(
        category: String,
        type: String
    ) -> TorahSourceCategory {
        let tokens = "\(category) \(type)".lowercased()
        if tokens.contains("quoting commentary") { return .quotingCommentary }
        if tokens.contains("commentary") { return .commentary }
        if tokens.contains("tanakh") { return .tanakh }
        if tokens.contains("talmud") { return .talmud }
        if tokens.contains("midrash") { return .midrash }
        if tokens.contains("targum") { return .targum }
        if tokens.contains("halakh") { return .halakhah }
        return .other
    }
}
#endif
