//
//  AnnotationDelegate.swift
//  maktab
//
//  Created by MacBook on 16/12/25.
//

import Foundation

protocol AnnotationDelegate: AnyObject {
    func didSelect(annotation: Annotation)
}

#if os(macOS)
extension IbarotTextVC: AnnotationDelegate {
    func didSelect(annotation: Annotation) {
        let bkId = annotation.bkId
        let contentId = annotation.contentId
        guard let book = LibraryDataManager.shared.getBook([bkId]).first else {
            DispatchQueue.main.async {
                ReusableFunc.showAlert(
                    title: String(localized: .bookNotFound(bookID: bkId)),
                    message: String(localized: .bookMissingOnAnnotationClick)
                )
            }
            return
        }

        Task.detached { [weak self, book, contentId, annotation] in
            guard let self else { return }

            if await currentBook?.id != bkId {
                do {
                    try await displayBook(book)
                    try await bookDB.connect(archive: book.archive)
                } catch {
                    return
                }
            }

            await handleDelegate(contentId, fromResults: true)
            await highlighAndScrollToAnns(annotation)
        }
    }
}
#endif

