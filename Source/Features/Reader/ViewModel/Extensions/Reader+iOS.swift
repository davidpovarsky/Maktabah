//
//  Reader+iOS.swift
//  Maktabah
//

import Foundation

extension ReaderViewModel {
    func saveCurrentState() {
        if let scroll = fetchScrollPosition?() {
            readerState.scrollPosition = scroll
        }
        if let range = fetchSelectedRange?() {
            readerState.selectedRange = range
        }
        annotationEvent = nil
        searchEvent = nil
    }

    func didSelectTOCNode(id: Int) {
        clearSearchHighlight()
        targetAnnotation = nil
        annotationEvent = nil
        if let node = tocViewModel.findNodeById(id), let locator = node.backendLocator {
            loadBackendContent(locator)
            return
        }
        fetchContentById(id)
    }

    func didSelectTOCNode(_ node: TOCNode) {
        clearSearchHighlight()
        targetAnnotation = nil
        annotationEvent = nil
        if let locator = node.backendLocator {
            loadBackendContent(locator)
            return
        }
        fetchContentById(node.id)
    }

    func didSelectTOCNode(id: Int, title: String = "") {
        annotationEvent = nil
        searchEvent = title.isEmpty ? nil : ReaderHighlightEvent(
            query: title,
            contentId: id,
            isTOC: true
        )
        didSelectTOCNode(id: id)
    }

    func didSelectSearch(query: String, contentId: Int) {
        searchText = query
        highlightTerms = nil
        searchHighlightFocusLocator = nil
        searchMode = searchViewModel.searchMode
        nearDistance = searchViewModel.nearDistance
        searchEvent = ReaderHighlightEvent(
            query: query,
            contentId: contentId,
            mode: searchViewModel.searchMode,
            nearDistance: searchViewModel.nearDistance
        )
        annotationEvent = nil
        fetchContentById(contentId)
    }

    func didSelectSearch(result: SearchResultItem, query: String) {
        searchText = query
        highlightTerms = result.highlightTerms
        searchMode = searchViewModel.searchMode
        nearDistance = searchViewModel.nearDistance
        targetAnnotation = nil
        searchHighlightFocusLocator = result.backendLocator
        searchEvent = ReaderHighlightEvent(
            query: query,
            contentId: result.bookId,
            mode: searchViewModel.searchMode,
            nearDistance: searchViewModel.nearDistance
        )
        annotationEvent = nil
        if let locator = result.backendLocator {
            loadBackendContent(LibraryReaderDestination(sectionLocator: locator, focusLocator: locator))
        } else {
            fetchContentById(result.bookId)
        }
    }

    var hasActiveSearchHighlight: Bool {
        !searchText.isEmpty || highlightTerms?.isEmpty == false
    }

    func clearSearchHighlight() {
        ReaderSearchHighlightPolicy.clear(
            searchText: &searchText,
            highlightTerms: &highlightTerms,
            focusLocator: &searchHighlightFocusLocator,
            selectedLocator: &selectedSegmentLocator,
            inspectorIsVisible: readerInspectorVisible
        )
        searchMode = nil
        searchEvent = nil
    }

    func didSelectAnnotation(_ ann: Annotation) {
        targetAnnotation = ann
        annotationEvent = ReaderAnnotationEvent(annotation: ann)
        searchEvent = nil
        let targetContentId = Int(ann.contentId)
        if targetContentId != currentContentId {
            fetchContentById(targetContentId)
        }
    }
}
