#if os(iOS)
import Foundation
import TorahInspectorCore

@MainActor
final class MaktabahTorahInspectorSession {
    private let coordinator: BackendCoordinator
    private let otzaria: OtzariaMaktabahBridge
    private let preferredMode: LibraryReaderTextMode
    private var locatorsByReference: [String: TextLocator] = [:]

    convenience init() {
        self.init(preferredMode: UserDefaults.standard.libraryReaderTextMode)
    }

    convenience init(preferredMode: LibraryReaderTextMode) {
        self.init(coordinator: .shared, otzaria: .shared, preferredMode: preferredMode)
    }

    init(
        coordinator: BackendCoordinator,
        otzaria: OtzariaMaktabahBridge = .shared,
        preferredMode: LibraryReaderTextMode = UserDefaults.standard.libraryReaderTextMode
    ) {
        self.coordinator = coordinator
        self.otzaria = otzaria
        self.preferredMode = preferredMode
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
        }
    )

    func selection(
        sefariaLocator: TextLocator?,
        otzariaLine: OtzariaLineAnchor?
    ) -> TorahInspectorSelection? {
        if let locator = sefariaLocator {
            switch locator.position {
            case .canonicalRef(let reference):
                remember(locator, for: reference)
                return TorahInspectorSelection(providerID: locator.backend.rawValue, canonicalRef: reference, preferredSegmentRef: reference)
            case .legacyLine:
                let reference = Self.reference(for: locator)
                remember(locator, for: reference)
                return TorahInspectorSelection(
                    providerID: locator.backend.rawValue,
                    canonicalRef: reference,
                    preferredSegmentRef: reference
                )
            }
        }
        guard let line = otzariaLine else { return nil }
        let locator = TextLocator(
            backend: .otzaria,
            workKey: "book:\(line.bookId)",
            position: .legacyLine(line.lineIndex)
        )
        let reference = Self.reference(for: locator)
        remember(locator, for: reference)
        return TorahInspectorSelection(
            providerID: BackendID.otzaria.rawValue,
            canonicalRef: reference,
            preferredSegmentRef: reference
        )
    }

    func locator(for selection: TorahInspectorSelection) -> TextLocator? {
        locator(for: selection.canonicalRef, providerID: selection.providerID)
    }

    private func document(for reference: String, providerID: String?) async throws -> TorahTextDocument {
        let locator = try activeLocator(for: reference, providerID: providerID)
        switch locator.backend {
        case .sefaria:
            let section = try await coordinator.section(at: locator)
            return try map(section, requestedReference: reference)
        case .otzaria:
            return try mapOtzariaDocument(locator: locator, requestedReference: reference)
        }
    }

    private func links(for reference: String, providerID: String?) async throws -> [TorahLinkedSource] {
        let locator = try activeLocator(for: reference, providerID: providerID)
        let sources = try await coordinator.links(for: locator)
        return sources.map { source in
            let sourceReference = Self.reference(for: source.locator)
            remember(source.locator, for: sourceReference)
            let usesHebrewReference = preferredMode != .translation
            return TorahLinkedSource(
                sourceRef: sourceReference,
                sourceHebrewRef: usesHebrewReference ? source.heRef : nil,
                category: source.category,
                type: source.type,
                collectiveTitle: source.collectiveTitle,
                hebrewCollectiveTitle: source.heCollectiveTitle,
                hebrewText: source.primaryText,
                englishText: source.translation,
                versionTitle: source.versionTitle,
                hebrewVersionTitle: source.heVersionTitle,
                license: source.license,
                rawProviderPayload: source.locator.persistenceKey
            )
        }
    }

    private func topics(for reference: String, providerID: String?) async throws -> [TorahLinkedTopic] {
        let locator = try activeLocator(for: reference, providerID: providerID)
        return try await coordinator.topics(for: locator).map {
            TorahLinkedTopic(slug: $0.slug, titleHe: $0.titleHe, titleEn: $0.titleEn)
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
            return TorahTextSegment(
                canonicalRef: reference,
                hebrewRef: preferredMode == .translation ? nil : segment.heRef,
                text: text,
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
              case .legacyLine(let lineIndex) = locator.position,
              let unit = otzaria.getReadingUnit(
                bookId: bookID,
                containingLineIndex: lineIndex,
                mode: otzaria.currentReadingUnitMode
              ) else { throw TorahError.invalidReference }

        let previous = otzaria.getPreviousReadingUnit(
            bookId: bookID,
            beforeLineIndex: unit.startLineIndex,
            mode: otzaria.currentReadingUnitMode
        )
        let next = otzaria.getNextReadingUnit(
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
        if let remembered = locatorsByReference["\(providerID):\(reference)"] { return remembered }
        switch BackendID(rawValue: providerID) {
        case .sefaria:
            return TextLocator(backend: .sefaria, workKey: reference, position: .canonicalRef(reference))
        case .otzaria:
            let parts = reference.split(separator: ":", omittingEmptySubsequences: false)
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
        locatorsByReference["\(locator.backend.rawValue):\(reference)"] = locator
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

    private static func otzariaBookID(from workKey: String) -> Int? {
        guard workKey.hasPrefix("book:") else { return nil }
        return Int(workKey.dropFirst("book:".count))
    }
}
#endif
