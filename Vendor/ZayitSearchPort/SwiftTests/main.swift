import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

let hostile = #"<p data-commentator="x">Alpha <b>bold <strong>nested</strong></b><small> tail</small></p>"#
let hostileSegments = SearchInlineMarkupSanitizer.segments(from: hostile)
require(SearchInlineMarkupSanitizer.plainText(from: hostile) == "Alpha bold nested tail", "HTML tags leaked")
require(hostileSegments.filter(\.highlighted).map(\.text).joined() == "bold nested", "nested highlight lost")

let malformed = "before <b>hit</i> after <data-commentator=x>ignored</data-commentator>"
require(SearchInlineMarkupSanitizer.plainText(from: malformed) == "before hit after ignored", "malformed HTML not sanitized")

let entities = "&lt;safe&gt; &amp; &#1513;&#x5DC;&#1493;&#1501; &quot;ok&quot;"
require(SearchInlineMarkupSanitizer.plainText(from: entities) == #"<safe> & שלום "ok""#, "entities not decoded")
let otzariaMarkup = "לפני <font color=red data-private=x>התאמה</font> אחרי"
require(
    SearchInlineMarkupSanitizer.segments(from: otzariaMarkup).filter(\.highlighted).map(\.text) == ["התאמה"],
    "Otzaria highlight markup was not preserved safely"
)

require(
    UnifiedSearchPresentationPolicy.resolve(
        resultCount: 2,
        isLoading: false,
        errorMessage: nil,
        hasSubmitted: true,
        indexReady: false
    ) == .results,
    "release discovery/package state hid valid results"
)
require(
    UnifiedSearchPresentationPolicy.resolve(
        resultCount: 0,
        isLoading: false,
        errorMessage: "engine failed",
        hasSubmitted: true,
        indexReady: true
    ) == .error("engine failed"),
    "engine errors were collapsed into an empty state"
)
require(
    SearchDataInstallPlanner.missingComponents(ready: [.database, .otzariaIndex])
        == [.lexicalDatabase, .zayitIndex],
    "install-all did not skip ready components or preserve dependency order"
)
require(
    ZayitInstallCapacityPolicy.requiredBytes(
        extractedBytes: 800,
        packagedPartBytes: [400, 300],
        currentPartialBytes: 100
    ) == 800 + 300 + ZayitInstallCapacityPolicy.reserveBytes,
    "Zayit capacity counted the installed index or the complete compressed package"
)

// F03 regression: Zayit location text formatting
struct MockSearchResultItem {
    let archive: String
    let locationDisplayText: String?
    let page: Int
    let part: Int

    var locationText: String {
        if let locationDisplayText, !locationDisplayText.isEmpty {
            return locationDisplayText
        }
        let isHebrew = archive == "Otzaria" || archive == "Sefaria" || archive == "Zayit"
        if isHebrew {
            var parts: [String] = []
            if part > 0 { parts.append("כרך \(part)") }
            if page > 0 { parts.append("עמ' \(page)") }
            return parts.joined(separator: " • ")
        } else {
            return "ص: \(page) - ج: \(part)"
        }
    }
}

let zayitExplicitRef = MockSearchResultItem(archive: "Zayit", locationDisplayText: "בראשית א, א", page: 1, part: 1)
require(zayitExplicitRef.locationText == "בראשית א, א", "Zayit explicit reference lost")

let zayitFallbackRef = MockSearchResultItem(archive: "Zayit", locationDisplayText: nil, page: 42, part: 1)
require(!zayitFallbackRef.locationText.contains("ص") && !zayitFallbackRef.locationText.contains("ج"), "Zayit fell back to Arabic page/volume format")
require(zayitFallbackRef.locationText == "כרך 1 • עמ' 42", "Zayit fallback reference formatting incorrect")

// F04 regression: Grouping versions of the same canonical location
struct MockGroupItem {
    let stableID: String
    let canonicalKey: String
    let versionTitle: String
}

var groups: [String: [MockGroupItem]] = [:]
let testItems = [
    MockGroupItem(stableID: "1:he", canonicalKey: "gen:1:1", versionTitle: "Hebrew Source"),
    MockGroupItem(stableID: "1:en", canonicalKey: "gen:1:1", versionTitle: "English JPS"),
    MockGroupItem(stableID: "1:fr", canonicalKey: "gen:1:1", versionTitle: "French"),
    MockGroupItem(stableID: "2:he", canonicalKey: "gen:1:2", versionTitle: "Hebrew Source"),
]
for item in testItems {
    groups[item.canonicalKey, default: []].append(item)
}
require(groups.keys.count == 2, "Versions of same canonical location were not grouped")
require(groups["gen:1:1"]?.count == 3, "All 3 versions of gen:1:1 should be in the same group")

print("Zayit Swift presentation tests passed")

