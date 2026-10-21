//
//  OpenBookOptions.swift
//  Maktabah
//
//  Created by Ays on 10/10/26.
//

import Foundation

struct OpenBookOptions {
    var contentId: Int?
    var searchEvent: ReaderHighlightEvent?
    var annotationEvent: ReaderAnnotationEvent?
    var recordHistory: Bool = true
    var searchText: String?
    var searchMode: SearchMode?
    var nearDistance: Int = 10
    var targetAnnotation: Annotation?
    var highlightTerms: [String]?

    init(
        contentId: Int? = nil,
        searchEvent: ReaderHighlightEvent? = nil,
        annotationEvent: ReaderAnnotationEvent? = nil,
        recordHistory: Bool = true,
        searchText: String? = nil,
        searchMode: SearchMode? = nil,
        nearDistance: Int = 10,
        targetAnnotation: Annotation? = nil,
        highlightTerms: [String]? = nil
    ) {
        self.contentId = contentId
        self.searchEvent = searchEvent
        self.annotationEvent = annotationEvent
        self.recordHistory = recordHistory
        self.searchText = searchText
        self.searchMode = searchMode
        self.nearDistance = nearDistance
        self.targetAnnotation = targetAnnotation
        self.highlightTerms = highlightTerms
    }
}
