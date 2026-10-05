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
        // If work key corresponds to Otzaria book, attempt navigation
        if let nav = navigationState {
            let workKey = link.locator.workKey
            // Find book by title or id
            if let book = nav.selectedBook, book.name == workKey {
                // Already open in the right book, just refresh reader
                nav.readerToken = UUID()
                return true
            }
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
