import Foundation

struct PrototypeHostContext: Equatable, Sendable {
    let title: String
    let identifier: String
    let collectionName: String?
    let excerpt: String?
    let detail: String?

    var compactTitle: String {
        "Current context: \(title)"
    }

    var accessibilitySummary: String {
        [
            title,
            collectionName,
            detail,
            excerpt
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }
}
