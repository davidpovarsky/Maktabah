//
//  Reader+Annotation.swift
//  Maktabah
//

import Foundation

extension ReaderViewModel {
    // MARK: - Shared: Annotations

    func loadAnnotations() {
        #if os(iOS)
        guard let book = currentBook else { return }
        let anns = CrossBackendAnnotationResolver.annotations(
            forBookID: book.id,
            contentID: currentContentId,
            text: contentText,
            locator: annotationLocator(for: book),
            manager: annotationStore
        )

        currentAnnotations = anns
        #endif
    }

    func findBestAnnotation(for range: NSRange) -> Annotation? {
        guard currentBook != nil else { return nil }
        return annotationCoordinator.findBestAnnotation(
            overlapping: range,
            in: currentAnnotations,
            showHarakat: TextViewState.shared.showHarakat
        )
    }

    func addAnnotation(
        in range: NSRange,
        mode: AnnotationMode,
        sourceText: String,
        color: PlatformColor
    ) throws {
        guard let book = currentBook else { throw AnnotationCreationError.missingBook }
        let locator = backendRenderModel?.renderedSegment(at: range.location)?.locator
            ?? annotationLocator(for: book)
        if let locator {
            LegacyIdentityRegistry.shared.register(title: book.book, for: locator)
        }
        let params = SaveHighlightParams(
            text: sourceText,
            range: range,
            color: color,
            bkId: book.id,
            contentId: currentContentId,
            page: currentPage ?? 0,
            part: currentPart ?? 0,
            diacriticsText: diacriticsText,
            showHarakat: showHarakat,
            mode: mode,
            backendLocator: locator
        )
        _ = try annotationCoordinator.saveHighlight(params)
        loadAnnotations()
    }

    func makeAnnotationDraft(
        in range: NSRange,
        mode: AnnotationMode,
        sourceText: String,
        color: PlatformColor
    ) throws -> Annotation {
        guard let book = currentBook else { throw AnnotationCreationError.missingBook }
        let locator = backendRenderModel?.renderedSegment(at: range.location)?.locator
            ?? annotationLocator(for: book)
        if let locator {
            LegacyIdentityRegistry.shared.register(title: book.book, for: locator)
        }
        return try annotationCoordinator.makeAnnotation(
            text: sourceText,
            range: range,
            color: color,
            bkId: book.id,
            contentId: currentContentId,
            page: currentPage ?? 0,
            part: currentPart ?? 0,
            diacriticsText: diacriticsText,
            showHarakat: showHarakat,
            mode: mode,
            backendLocator: locator
        )
    }

    func persistNewAnnotation(_ annotation: Annotation) throws {
        precondition(annotation.id == nil, "Only unsaved annotation drafts may be inserted")
        try validateAnnotationTarget(annotation)
        _ = try annotationStore.addAnnotation(annotation)
        loadAnnotations()
    }

    func annotationLocator(for book: BooksData) -> TextLocator? {
        if let locator = backendSection?.locator ?? book.backendLocator { return locator }
        return TextLocator(
            backend: .otzaria,
            workKey: "book:\(book.id)",
            position: .legacyLine(currentContentId)
        )
    }

    func deleteAnnotation(id: Int64) throws {
        try annotationStore.deleteAnnotation(id: id)
        loadAnnotations()
    }

    func updateAnnotation(_ annotation: Annotation) throws {
        try validateAnnotationTarget(annotation)
        try annotationStore.updateAnnotation(annotation)
        loadAnnotations()
    }

    private func validateAnnotationTarget(_ annotation: Annotation) throws {
        guard let book = currentBook,
              book.id == annotation.bkId,
              currentContentId == annotation.contentId else {
            throw AnnotationCreationError.invalidRange(
                location: annotation.range.location,
                length: annotation.range.length,
                sourceLength: (contentText as NSString).length
            )
        }

        let source = contentText as NSString
        let range = showHarakat ? annotation.rangeDiacritics : annotation.range
        guard range.location != NSNotFound,
              range.length > 0,
              range.location <= source.length,
              range.length <= source.length - range.location else {
            throw AnnotationCreationError.invalidRange(
                location: range.location,
                length: range.length,
                sourceLength: source.length
            )
        }
    }
}
