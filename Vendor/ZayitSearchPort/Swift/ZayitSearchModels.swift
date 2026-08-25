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
struct ZayitSearchHit: Codable, Identifiable, Sendable { let bookId:Int64; let stableBookKey:String; let bookTitle:String; let lineId:Int64; let lineIndex:Int; let reference:String; let snippetHtml:String; let matchedTerms:[String]; let score:Float; let isBaseBook:Bool
    var id:Int64{lineId}
    enum CodingKeys:String,CodingKey{case bookId="book_id",stableBookKey="stable_book_key",bookTitle="book_title",lineId="line_id",lineIndex="line_index",reference,snippetHtml="snippet_html",matchedTerms="matched_terms",score,isBaseBook="is_base_book"}
}

struct SearchInlineSegment: Equatable, Sendable {
    let text: String
    let highlighted: Bool
}

enum SearchInlineMarkupSanitizer {
    static func segments(from markup: String) -> [SearchInlineSegment] {
        var result: [SearchInlineSegment] = []
        var buffer = ""
        var highlightDepth = 0
        var index = markup.startIndex

        func flush() {
            guard !buffer.isEmpty else { return }
            result.append(.init(text: decodeEntities(buffer), highlighted: highlightDepth > 0))
            buffer.removeAll(keepingCapacity: true)
        }

        while index < markup.endIndex {
            if markup[index] == "<", let close = markup[index...].firstIndex(of: ">") {
                flush()
                let rawTag = markup[markup.index(after: index)..<close]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                let name = rawTag
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    .split(whereSeparator: { $0.isWhitespace })
                    .first.map(String.init) ?? ""
                let isOtzariaHighlight = name == "font" && (
                    rawTag.contains("color=red")
                        || rawTag.contains("color=\"red\"")
                        || rawTag.contains("color='#ff0000'")
                        || rawTag.contains("color=\"#ff0000\"")
                        || rawTag.hasPrefix("/font")
                )
                if name == "b" || name == "strong" || name == "mark" || isOtzariaHighlight {
                    highlightDepth = rawTag.hasPrefix("/")
                        ? max(0, highlightDepth - 1) : highlightDepth + 1
                } else if ["br", "p", "div", "li", "h1", "h2", "h3"].contains(name),
                          !buffer.hasSuffix(" ") {
                    buffer.append(" ")
                }
                index = markup.index(after: close)
            } else {
                buffer.append(markup[index])
                index = markup.index(after: index)
            }
        }
        flush()
        return result.filter { !$0.text.isEmpty }
    }

    static func plainText(from markup: String) -> String {
        segments(from: markup).map(\.text).joined()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeEntities(_ value: String) -> String {
        var decoded = value
        let entities = [
            "&nbsp;": " ", "&quot;": "\"", "&#39;": "'", "&apos;": "'",
            "&lt;": "<", "&gt;": ">", "&amp;": "&"
        ]
        for (entity, replacement) in entities {
            decoded = decoded.replacingOccurrences(of: entity, with: replacement)
        }
        while let start = decoded.range(of: "&#"),
              let end = decoded[start.upperBound...].firstIndex(of: ";") {
            let token = String(decoded[start.upperBound..<end])
            let radix = token.lowercased().hasPrefix("x") ? 16 : 10
            let digits = radix == 16 ? String(token.dropFirst()) : token
            guard let value = UInt32(digits, radix: radix), let scalar = UnicodeScalar(value) else {
                decoded.removeSubrange(start.lowerBound...end)
                continue
            }
            decoded.replaceSubrange(start.lowerBound...end, with: String(Character(scalar)))
        }
        return decoded
    }
}
