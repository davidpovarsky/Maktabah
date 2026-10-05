import Foundation
import SwiftUI

@MainActor
final class TorahStudyDeepLinkHandler: ObservableObject {
    static let shared = TorahStudyDeepLinkHandler()

    @Published var activeStudyDeepLink: TorahStudyDeepLink?
    @Published var statusMessage: String?

    private init() {}

    func handle(url: URL, navigationState: OtzariaIntegratedNavigationState? = nil) -> Bool {
        guard let link = TorahStudyDeepLink.parse(url: url) else {
            return false
        }

        self.activeStudyDeepLink = link

        switch link.action {
        case .open:
            return openSource(link: link, navigationState: navigationState)
        case .learn:
            return initiateHandoffToHanlin(link: link)
        case .lookup:
            return openSource(link: link, navigationState: navigationState)
        }
    }

    private func openSource(link: TorahStudyDeepLink, navigationState: OtzariaIntegratedNavigationState?) -> Bool {
        let workKey = link.locator.workKey
        let lineIndex = Int(link.locator.positionValue)

        // Parse expected book ID if workKey encodes book:ID or direct integer
        let expectedBookId: Int
        if workKey.hasPrefix("book:"), let parsed = Int(workKey.dropFirst("book:".count)) {
            expectedBookId = parsed
        } else if let parsed = Int(workKey) {
            expectedBookId = parsed
        } else {
            expectedBookId = 0
        }

        #if os(iOS)
        let resolvedBook: BooksData?
        if let book = try? OtzariaDatabaseManagerAdapter.resolveBook(stableKey: workKey, expectedBookId: expectedBookId) {
            resolvedBook = book
        } else if expectedBookId > 0, let book = try? OtzariaDatabaseManagerAdapter.fetchBook(byId: expectedBookId) {
            resolvedBook = book
        } else {
            resolvedBook = nil
        }

        if let book = resolvedBook {
            let lineSuffix = lineIndex != nil ? " line \(lineIndex!)" : ""
            if let nav = navigationState {
                let otzariaBook = OtzariaBook(
                    id: book.id,
                    title: book.book,
                    categoryId: book.catId ?? 0,
                    orderIndex: book.orderIndex ?? 0,
                    totalLines: book.totalLines ?? 0,
                    shortDescription: book.bithoqoh,
                    filePath: book.info,
                    fileType: nil,
                    isBaseBook: false,
                    hasTeamim: false,
                    hasNekudot: false,
                    hasLinks: false
                )
                nav.openBook(otzariaBook)
                if let line = lineIndex {
                    nav.selectedLineID = line
                }
                nav.readerToken = UUID()
            }
            statusMessage = "Navigated to \(book.book)\(lineSuffix)"
            return true
        }
        #endif

        if let nav = navigationState {
            if let line = lineIndex {
                nav.selectedLineID = line
            }
            nav.readerToken = UUID()
        }
        statusMessage = "Opened Torah passage: \(link.workTitle ?? link.locator.workKey)"
        return true
    }

    private func initiateHandoffToHanlin(link: TorahStudyDeepLink) -> Bool {
        guard let url = link.url(scheme: "hanlin") else { return false }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        return true
        #else
        return false
        #endif
    }
}
