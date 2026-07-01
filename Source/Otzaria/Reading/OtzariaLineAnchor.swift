import Foundation

struct OtzariaLineAnchor: Identifiable, Equatable {
    let id: Int
    let bookId: Int
    let lineIndex: Int
    let heRef: String?
    let text: String
    let range: NSRange
}
