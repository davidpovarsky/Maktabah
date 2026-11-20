
// TEST-ONLY APPENDIX. The runner appends these bytes to a byte-identical copy of
// the complete owner and verifies the original prefix and repository file.
// No production source is edited; no defaults, bookmark or migration is invoked.
extension OtzariaDatabaseAccessController {
    static func occurrenceFixtureMake() -> OtzariaDatabaseAccessController {
        OtzariaDatabaseAccessController()
    }
    func occurrenceFixturePublish(url: URL?, source: Source?) {
        publishSelection(url: url, source: source)
    }
}
