import Combine
import Foundation
import SwiftUI

@MainActor
class iOSHistoryViewModel: ObservableObject {
    static let shared = iOSHistoryViewModel()

    @Published var historyBookIds: [Int] = []
    @Published var favoriteBookIds: [Int] = []

    @Published var historyBooks: [BooksData] = []
    @Published var favoriteBooks: [BooksData] = []

    private let historyKey = "iOSHistoryBookIds"
    private let favoritesKey = "iOSFavoriteBookIds"
    private let maxHistoryCount = 50

    init() {
        loadFromUserDefaults()
    }

    func loadFromUserDefaults() {
        let hIds = UserDefaults.standard.array(forKey: historyKey) as? [Int] ?? []
        let fIds = UserDefaults.standard.array(forKey: favoritesKey) as? [Int] ?? []

        historyBookIds = hIds
        favoriteBookIds = fIds

        loadBooksData()
    }

    func saveToUserDefaults() {
        UserDefaults.standard.set(historyBookIds, forKey: historyKey)
        UserDefaults.standard.set(favoriteBookIds, forKey: favoritesKey)
    }

    func addBookToHistory(_ bookId: Int) {
        historyBookIds.removeAll { $0 == bookId }
        historyBookIds.insert(bookId, at: 0)

        if historyBookIds.count > maxHistoryCount {
            historyBookIds = Array(historyBookIds.prefix(maxHistoryCount))
        }

        saveToUserDefaults()
        loadBooksData()
    }

    func toggleFavorite(_ bookId: Int) {
        if let index = favoriteBookIds.firstIndex(of: bookId) {
            favoriteBookIds.remove(at: index)
        } else {
            favoriteBookIds.insert(bookId, at: 0)
        }
        saveToUserDefaults()
        loadBooksData()
    }

    func removeHistory(_ bookId: Int) {
        historyBookIds.removeAll { $0 == bookId }
        saveToUserDefaults()
        loadBooksData()
    }

    func loadBooksData() {
        let dm = LibraryDataManager.shared
        historyBooks = historyBookIds.compactMap { dm.getBook([$0]).first }
        favoriteBooks = favoriteBookIds.compactMap { dm.getBook([$0]).first }
    }
}
