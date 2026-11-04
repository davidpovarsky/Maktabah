import Foundation

/// The result of matching a query against a string.
public struct FuzzyMatch: Hashable, Sendable {
    /// Higher is better. Only compare scores of the same query.
    public var score: Int
    /// The matched characters as ranges of character offsets into the candidate, merged where they
    /// touch: `"nn"` in `"New Note"` gives `[0..<1, 4..<5]`.
    public var ranges: [Range<Int>]

    public init(score: Int, ranges: [Range<Int>]) {
        self.score = score
        self.ranges = ranges
    }
}

/// Fuzzy matching in the style of code editors' "Go to File": the characters of the query must
/// appear in the candidate in order, but not next to each other.
///
/// Matching ignores case, diacritics and spaces in the query. Of all the ways the query fits the
/// candidate, the one with the best score wins, so `"note"` in `"Rename Note"` highlights the word
/// "Note", not the "n" of "Rename". The score rewards:
///
/// - matches at the start of a word (after a space, punctuation or a lower-to-upper case change),
/// - consecutive characters,
/// - a match at the very first character, a prefix of the whole candidate, and an exact match,
///
/// and subtracts a little for every character skipped between matches and before the first one.
///
/// ```swift
/// FuzzyMatcher.match("nn", in: "New Note")?.ranges   // [0..<1, 4..<5]
/// FuzzyMatcher.match("xyz", in: "New Note")          // nil
/// ```
public enum FuzzyMatcher {
    /// The weights of the score. They are public so the ordering rules can be read, not changed.
    public enum Weight {
        /// Every matched character.
        public static let match = 16
        /// A matched character that starts a word.
        public static let wordStart = 30
        /// A matched uppercase letter after a lowercase one (`"tableView"`), or a digit after a letter.
        public static let camelCase = 20
        /// A matched character right after the previous matched one.
        public static let consecutive = 32
        /// Subtracted for every character skipped between two matched characters.
        public static let gap = 3
        /// At most this much is subtracted, one per character, for characters before the first match.
        public static let maxLeadingPenalty = 10
        /// The first character of the candidate matched.
        public static let firstCharacter = 15
        /// The candidate starts with the query.
        public static let prefix = 50
        /// The candidate is the query.
        public static let exact = 100
    }

    /// Matches `query` against `candidate`. Returns `nil` when the query's characters do not all
    /// appear in order. An empty query (or one of only spaces) matches everything with score 0.
    public static func match(_ query: String, in candidate: String) -> FuzzyMatch? {
        let needle = query.filter { !$0.isWhitespace }.map(fold)
        guard !needle.isEmpty else { return FuzzyMatch(score: 0, ranges: []) }

        let characters = Array(candidate)
        let haystack = characters.map(fold)
        let n = needle.count
        let m = haystack.count
        guard n <= m, isSubsequence(needle, of: haystack) else { return nil }

        let bonuses = (0..<m).map { bonus(at: $0, in: characters) }

        // scores[i][j]: the best score of matching needle[0...i] with needle[i] at haystack[j].
        // previous[i][j]: where needle[i - 1] sits in that best match.
        var scores = [[Int?]](repeating: [Int?](repeating: nil, count: m), count: n)
        var previous = [[Int]](repeating: [Int](repeating: -1, count: m), count: n)

        for i in 0..<n {
            for j in i..<m where haystack[j] == needle[i] {
                let base = Weight.match + bonuses[j]
                if i == 0 {
                    scores[0][j] = base - min(j, Weight.maxLeadingPenalty) + (j == 0 ? Weight.firstCharacter : 0)
                    continue
                }
                var best: Int?
                var bestIndex = -1
                for k in (i - 1)..<j {
                    guard let earlier = scores[i - 1][k] else { continue }
                    let skipped = j - k - 1
                    let score = earlier + base + (skipped == 0 ? Weight.consecutive : -skipped * Weight.gap)
                    if best.map({ score > $0 }) ?? true {
                        best = score
                        bestIndex = k
                    }
                }
                if let best {
                    scores[i][j] = best
                    previous[i][j] = bestIndex
                }
            }
        }

        var bestScore = Int.min
        var end = -1
        for j in 0..<m {
            if let score = scores[n - 1][j], score > bestScore {
                bestScore = score
                end = j
            }
        }
        guard end >= 0 else { return nil }

        var indices: [Int] = []
        var position = end
        for i in stride(from: n - 1, through: 0, by: -1) {
            indices.append(position)
            position = previous[i][position]
        }
        indices.reverse()

        let foldedCandidate = haystack.joined()
        let foldedQuery = query.trimmingCharacters(in: .whitespaces).map(fold).joined()
        if foldedCandidate == foldedQuery {
            bestScore += Weight.exact
        } else if foldedCandidate.hasPrefix(foldedQuery) {
            bestScore += Weight.prefix
        }

        return FuzzyMatch(score: bestScore, ranges: ranges(from: indices))
    }

    /// Merges sorted character offsets into ranges: `[0, 1, 2, 5]` becomes `[0..<3, 5..<6]`.
    static func ranges(from indices: [Int]) -> [Range<Int>] {
        var result: [Range<Int>] = []
        for index in indices {
            if let last = result.last, last.upperBound == index {
                result[result.count - 1] = last.lowerBound..<(index + 1)
            } else {
                result.append(index..<(index + 1))
            }
        }
        return result
    }

    /// Case, diacritic and width folding of one character, so "É" matches "e".
    static func fold(_ character: Character) -> String {
        String(character).folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    private static func isSubsequence(_ needle: [String], of haystack: [String]) -> Bool {
        var index = 0
        for character in haystack where index < needle.count && character == needle[index] {
            index += 1
        }
        return index == needle.count
    }

    private static func bonus(at index: Int, in characters: [Character]) -> Int {
        guard index > 0 else { return Weight.wordStart }
        let previous = characters[index - 1]
        let current = characters[index]
        let previousIsWordCharacter = previous.isLetter || previous.isNumber
        let currentIsWordCharacter = current.isLetter || current.isNumber
        if !previousIsWordCharacter {
            return currentIsWordCharacter ? Weight.wordStart : 0
        }
        if previous.isLowercase && current.isUppercase { return Weight.camelCase }
        if previous.isLetter && current.isNumber { return Weight.camelCase }
        return 0
    }
}
