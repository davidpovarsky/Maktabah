import Foundation

protocol OtzariaLibraryRepository: Sendable {
    func loadLibrary() async throws -> (nodes: [OtzariaLibraryNode], books: [OtzariaBook])
}

protocol OtzariaBookTextRepository: Sendable {
    func lines(bookId: Int, startingAtLineIndex: Int, limit: Int) async throws -> [OtzariaBookLine]
    func tableOfContents(bookId: Int) async throws -> [OtzariaTOCEntry]
}

protocol OtzariaSourceRepository: Sendable {
    func sources(for line: OtzariaBookLine) async throws -> [OtzariaLinkedSource]
}
