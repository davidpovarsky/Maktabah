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

print("Zayit Swift presentation tests passed")
