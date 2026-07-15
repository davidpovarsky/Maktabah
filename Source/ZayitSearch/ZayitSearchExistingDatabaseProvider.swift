import Foundation

enum ZayitSearchExistingDatabaseProvider {
    static var currentURL: URL? {
        OtzariaMaktabahBridge.shared.databaseURL
    }
}
