import Foundation
@main enum CanonicalManifest {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else { throw CocoaError(.fileReadUnknown) }
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let model = try JSONDecoder().decode(OtzariaSearchArtifactManifest.self, from: data)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let encoded = try encoder.encode(model)
        let roundTrip = try JSONDecoder().decode(OtzariaSearchArtifactManifest.self, from: encoded)
        guard model == roundTrip else { throw CocoaError(.coderInvalidValue) }
        try encoded.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
        print("canonical_typed_manifest_bytes=\(encoded.count) artifact=\(model.artifactIdentity)")
    }
}
