// Included inside the fixture manager; actual methods are extracted separately.
static let shared = OtzariaSearchIndexManager()
var indexRootURL: URL { FixtureWorld.root.appendingPathComponent("indexes") }
func indexURL(for path: String) -> URL { indexRootURL.appendingPathComponent("managed-library") }
func buildingIndexURL(for path: String) -> URL { indexURL(for: path).appendingPathExtension("building") }
func previousIndexURL(for path: String) -> URL { indexURL(for: path).appendingPathExtension("previous") }
func sentinelURL(for path: String) -> URL { indexRootURL.appendingPathComponent("building-sentinel") }
func identityURL(indexURL: URL) -> URL { indexURL.appendingPathComponent("otzaria_search_identity.json") }
func checkpointURL(indexURL: URL) -> URL { indexURL.appendingPathComponent("checkpoint.json") }
func semanticArtifactURL(for path: String) -> URL { indexRootURL.appendingPathComponent("semantic.json") }
func preflightStorage(databasePath: String) throws {}
func semanticCorpusIdentity(database: OtzariaIndexFingerprint, catalogueHash: String) -> String { "fixture" }
func decode<T: Decodable>(_ type: T.Type, at url: URL) -> T? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(type, from: data)
}
func atomicWrite<T: Encodable>(_ value: T, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    try encoder.encode(value).write(to: url, options: .atomic)
    FixtureWorld.writes += 1
}
func fixtureCanSeed(from url: URL, identity: OtzariaIndexBuildIdentity) -> Bool {
    canSeedBuildingIndex(from: url, for: identity)
}
