import Foundation

protocol OtzariaLibraryRepository {
    func loadLibrary() async throws -> (nodes: [OtzariaLibraryNode], books: [OtzariaBook])
}

protocol OtzariaBookTextRepository {
    func lines(bookId: Int, startingAtLineIndex: Int, limit: Int) async throws -> [OtzariaBookLine]
    func tableOfContents(bookId: Int) async throws -> [OtzariaTOCEntry]
}

protocol OtzariaSourceRepository {
    func sources(for line: OtzariaBookLine) async throws -> [OtzariaLinkedSource]
}
