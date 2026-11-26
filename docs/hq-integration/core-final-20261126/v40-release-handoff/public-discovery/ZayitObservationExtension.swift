
// Same-file test observation of the result returned by the original private resolver.
extension ZayitSearchArtifactService {
    func observeProductionReleaseForSmoke(databaseURL: URL) async throws -> (
        tag: String, manifest: ZayitSearchArtifactManifest, partURLs: [String: URL]
    ) {
        let original = try await resolveArtifact(matching: databaseURL)
        return (original.releaseTag, original.manifest, original.partURLs)
    }
}
