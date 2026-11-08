import Foundation

/// Pinned functional data from SeforimLibrary@344232b6; no Kotlin implementation is embedded.
func runOtzariaReferenceKeyFixtureTests() throws -> Int {
    struct KeyCase: Decodable { let input: String; let key: String?; let hash: Int64? }
    struct LineCase: Decodable { let heRef: String; let aliases: [String]; let key: String?; let hash: Int64? }
    struct Partial: Decodable { let key: String; let hash: Int64 }
    struct PartialLineCase: Decodable { let heRef: String; let aliases: [String]; let keys: [Partial] }
    struct Fixtures: Decodable { let refKeys: [KeyCase]; let lineKeys: [LineCase]; let partialLineKeys: [PartialLineCase]; let partialRefKeys: [KeyCase] }
    let data = try Data(contentsOf: URL(fileURLWithPath: "tools/fixtures/otzaria-ref-key-fixtures.json"))
    let fixtures = try JSONDecoder().decode(Fixtures.self, from: data)
    var count = 0
    func verify(_ actual: String?, expected: String?, hash: Int64?, input: String) throws {
        guard actual == expected else {
            throw NSError(domain: "RefKeyFixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Key mismatch for '\(input)': \(actual ?? "nil") != \(expected ?? "nil")"])
        }
        count += 1
        if let hash {
            guard let actual, Int64(bitPattern: OtzariaReferenceKey.hash(actual)) == hash else {
                throw NSError(domain: "RefKeyFixture", code: 2, userInfo: [NSLocalizedDescriptionKey: "Hash mismatch for '\(input)'"])
            }
            count += 1
        }
    }
    for value in fixtures.refKeys { try verify(OtzariaReferenceKey.key(value.input), expected: value.key, hash: value.hash, input: value.input) }
    for value in fixtures.lineKeys { try verify(OtzariaReferenceKey.lineKey(value.heRef, aliases: value.aliases), expected: value.key, hash: value.hash, input: value.heRef) }
    for value in fixtures.partialRefKeys { try verify(OtzariaReferenceKey.partialKey(value.input), expected: value.key, hash: value.hash, input: value.input) }
    for value in fixtures.partialLineKeys {
        let keys = OtzariaReferenceKey.partialLineKeys(value.heRef, aliases: value.aliases)
        guard keys == value.keys.map(\.key) else { throw NSError(domain: "RefKeyFixture", code: 3, userInfo: [NSLocalizedDescriptionKey: "Partial keys mismatch: \(value.heRef)"]) }
        count += 1
        for (key, expected) in zip(keys, value.keys) { try verify(key, expected: expected.key, hash: expected.hash, input: value.heRef) }
    }
    print("PASS: \(count) RefKey key/hash assertions across all 43 pinned fixture cases")
    return count
}
