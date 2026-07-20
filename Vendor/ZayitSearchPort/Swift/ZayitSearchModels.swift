import Foundation

enum ZayitSearchMatchMode: String, CaseIterable, Identifiable {
    case exact
    case flexible

    var id: Self { self }

    var nearValue: UInt32 {
        switch self {
        case .exact:
            return 0
        case .flexible:
            return 5
        }
    }
}

struct ZayitSearchDataPaths: Codable, Sendable {
    let seforimDb: String
    let lexicalDb: String
    let indexDir: String
    enum CodingKeys: String, CodingKey { case seforimDb = "seforim_db", lexicalDb = "lexical_db", indexDir = "index_dir" }
}

struct ZayitSearchRequest: Codable, Sendable {
    let query: String
    let near: UInt32
    let limit: Int
    let offset: Int
    let filters: ZayitSearchFilters
}
struct ZayitSearchFilters: Codable, Sendable {
    var bookId: Int64? = nil; var categoryId: Int64? = nil; var bookIds:[Int64]=[]; var lineIds:[Int64]=[]; var baseBookOnly=false
    enum CodingKeys:String,CodingKey { case bookId="book_id",categoryId="category_id",bookIds="book_ids",lineIds="line_ids",baseBookOnly="base_book_only" }
}
struct ZayitSearchPage: Codable, Sendable { let hits:[ZayitSearchHit]; let totalHits:UInt64; let isLastPage:Bool
    enum CodingKeys:String,CodingKey{case hits,totalHits="total_hits",isLastPage="is_last_page"}
}
struct ZayitSearchHit: Codable, Identifiable, Sendable { let bookId:Int64; let bookTitle:String; let lineId:Int64; let lineIndex:Int; let snippetHtml:String; let score:Float; let isBaseBook:Bool
    var id:Int64{lineId}
    enum CodingKeys:String,CodingKey{case bookId="book_id",bookTitle="book_title",lineId="line_id",lineIndex="line_index",snippetHtml="snippet_html",score,isBaseBook="is_base_book"}
}
