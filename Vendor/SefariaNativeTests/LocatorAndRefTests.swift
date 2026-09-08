import Foundation

func runLocatorAndRefTests() throws {
    let sefaria = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:1"))
    let otzaria = TextLocator(backend: .otzaria, workKey: "42", position: .legacyLine(7))
    try expect(try JSONDecoder().decode(TextLocator.self, from: JSONEncoder().encode(sefaria)) == sefaria,
        "Sefaria locator round trip")
    try expect(try JSONDecoder().decode(TextLocator.self, from: JSONEncoder().encode(otzaria)) == otzaria,
        "Otzaria locator round trip")
    try expect(sefaria.persistenceKey != otzaria.persistenceKey, "source-qualified IDs must not collide")
    try expect(SefariaRef.canonicalInput("Genesis.1.1") == "Genesis 1:1", "Tanakh URL ref")
    try expect(SefariaRef.canonicalInput("Berakhot.2a") == "Berakhot 2a", "Bavli URL ref")
    try expect(SefariaRef.canonicalInput("Rashi_on_Genesis.1.1.1") == "Rashi on Genesis 1:1:1",
        "commentary URL ref")
    try expect(SefariaRef.canonicalInput("Pesach_Haggadah,_Magid.1") == "Pesach Haggadah, Magid 1",
        "complex URL ref")
    try expect(SefariaRef.talmudAddress(offset: 0) == "2a" && SefariaRef.talmudAddress(offset: 1) == "2b",
        "Talmud address sequence")
}
