import Foundation

func runDecodingTests() throws {
    let decoder = JSONDecoder()
    let genesis = try decoder.decode(SefariaTextsV3DTO.self, from: fixture("texts-genesis.json"))
    let section = SefariaSection(ref: genesis.ref, heRef: genesis.heRef, sectionRef: genesis.sectionRef,
        indexTitle: genesis.indexTitle, next: genesis.next, prev: genesis.prev,
        versions: genesis.versions, linksBySegment: [], origin: .remote).asLibrarySection()
    try expect(section.segments.count == 2, "ordinary text segments")
    try expect(section.segments[0].translation == "In the beginning", "translation pairing")
    try expect(section.versions.first?.license == "CC-BY-SA", "version attribution")

    let bavli = try decoder.decode(SefariaTextsV3DTO.self, from: fixture("texts-berakhot.json"))
    try expect(bavli.next == "Berakhot 2b" && bavli.versions.count == 1, "Bavli and missing translation")
    let commentary = try decoder.decode(SefariaTextsV3DTO.self, from: fixture("texts-commentary.json"))
    try expect(commentary.indexTitle == "Rashi on Genesis", "commentary work identity")

    let search = try decoder.decode(SefariaSearchResponseDTO.self, from: fixture("search.json"))
    try expect(search.hits.total.value == 1 && search.hits.hits[0].source.ref == "Genesis 1:1",
        "search response to canonical ref")
    let offline = try decoder.decode(SefariaOfflineMetadataDTO.self, from: fixture("offline-metadata.json"))
    try expect(offline.links?.first?.first?.type == "commentary", "offline links")
    do {
        _ = try decoder.decode(SefariaTextsV3DTO.self, from: Data("{bad".utf8))
        throw TestFailure.failed("malformed response was accepted")
    } catch is DecodingError {}
}
