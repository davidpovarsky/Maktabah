
import Foundation
@main struct SelectedVersionControls {
    static func main() async throws {
        let args = CommandLine.arguments
        let fixtureRoot = URL(fileURLWithPath: args[1])
        let scratch = URL(fileURLWithPath: args[2])
        let locator = TextLocator(backend: .sefaria, workKey: "Psalms", position: .canonicalRef("Psalms 131"))
        let text = LibraryTextVersionSelection(title: "Tanach with Text Only", language: "he")
        let nikkud = LibraryTextVersionSelection(title: "Tanach with Nikkud", language: "he")
        let english = LibraryTextVersionSelection(title: "The Holy Scriptures: A New Translation (JPS 1917)", language: "en")
        let french = LibraryTextVersionSelection(title: "Bible du Rabbinat 1899 [fr]", language: "en")
        func expected(_ file: String) throws -> LibraryTextSection {
            let dto = try JSONDecoder().decode(SefariaTextsV3DTO.self, from: Data(contentsOf: fixtureRoot.appendingPathComponent(file)))
            return SefariaSection(ref: dto.ref, heRef: dto.heRef, sectionRef: dto.sectionRef, indexTitle: dto.indexTitle,
                next: dto.next, prev: dto.prev, versions: dto.versions, linksBySegment: [], origin: .remote).asLibrarySection()
        }
        func create(_ name: String) -> (SourceSectionControl, SefariaHTTPClient, SefariaDiskCache) {
            let client = SefariaHTTPClient(root: fixtureRoot)
            let cache = SefariaDiskCache(directory: scratch.appendingPathComponent(name))
            return (SourceSectionControl(client: client, cache: cache), client, cache)
        }
        var pass = 0, fail = 0
        func check(_ name: String, _ result: Bool) {
            if result { pass += 1; print("PASS " + name) } else { fail += 1; print("FAIL " + name) }
        }
        func sameBody(_ lhs: LibraryTextSection, _ rhs: LibraryTextSection) -> Bool {
            lhs.locator == rhs.locator && lhs.segments == rhs.segments && lhs.versions == rhs.versions
        }
        let sourceExpected = try expected("psalms131-text-only.json")
        let markedExpected = try expected("psalms131-nikkud.json")
        let englishExpected = try expected("psalms131-jps1917.json")
        let frenchExpected = try expected("psalms131-french.json")
        check("independent real source has different same-ref Hebrew bodies", sourceExpected.locator == markedExpected.locator
            && sourceExpected.segments.map(\.primaryText) != markedExpected.segments.map(\.primaryText))
        for (name, selected, wanted) in [("Hebrew text-only",text,sourceExpected),("Hebrew nikkud",nikkud,markedExpected),
                                        ("English JPS1917",english,englishExpected),("French legacy-en bucket",french,frenchExpected)] {
            let (store, _, _) = create(name)
            let actual = try await store.expandedContext(at: locator, selected: selected)
            check("selected exact body " + name, sameBody(actual,wanted))
            check("canonical locator unchanged " + name, actual.locator == locator)
            check("genuine bilingual slots " + name, actual.segments.count == 3
                && actual.segments.allSatisfy { !$0.primaryText.isEmpty && $0.translation?.isEmpty == false })
        }
        let (sequence, client, cache) = create("cache")
        let first = try await sequence.expandedContext(at: locator, selected: text)
        let second = try await sequence.expandedContext(at: locator, selected: nikkud)
        check("switch edition changes actual text", first.segments.map(\.primaryText) != second.segments.map(\.primaryText))
        let originalDefault = try await sequence.section(at: locator)
        check("default section behavior preserved", sameBody(originalDefault,try expected("psalms131-default.json")))
        let callsBefore = await client.count()
        await client.block()
        let cold = SourceSectionControl(client: client, cache: cache)
        let cached = try await cold.expandedContext(at: locator, selected: text)
        check("cold exact edition cache", sameBody(cached,sourceExpected))
        let callsAfter = await client.count()
        check("cache needs no transport fixture", callsBefore == callsAfter)
        for (name, title, response, duplicate, familyMissing) in [
            ("missing requested edition","not a published edition",Optional<String>.none,false,false),
            ("missing edition in successful response",text.title,Optional("psalms131-default.json"),false,false),
            ("ambiguous exact tuple",text.title,Optional<String>.none,true,false),
            ("absent language family",text.title,Optional<String>.none,false,true)
        ] {
            let (store, transport, _) = create(name)
            await transport.configure(response: response, duplicate: duplicate, familyMissing: familyMissing)
            do {
                _ = try await store.expandedContext(at: locator, selected: .init(title:title,language:"he"))
                check("reject " + name,false)
            } catch { check("reject " + name,true) }
        }
        for mode in LibraryReaderTextMode.allCases {
            let sample = englishExpected.segments[1]
            let actual = previewVisibility(mode:mode,language:"en",primary:sample.primaryText,translation:sample.translation)
            check("English result explicit mode " + mode.rawValue,
                  actual.0 == (mode != .translation) && actual.1 == (mode != .source))
        }
        print("RESULT pass=\(pass) fail=\(fail)")
        if fail > 0 { exit(1) }
    }
}
