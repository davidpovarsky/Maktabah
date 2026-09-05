import Foundation

enum OtzariaArtifactComponent: String, Codable, CaseIterable, Sendable {
    case database
    case lexicalDatabase
    case otzariaIndex
    case zayitIndex
}

struct OtzariaArtifactDescriptor: Codable, Equatable, Sendable {
    let component: OtzariaArtifactComponent
    let artifactID: String
    let version: String
    let assetName: String
    let downloadURL: URL
    let compressedBytes: Int64
    let extractedBytes: Int64
    let sha256: String
    let schemaVersion: Int
    let artifactVersion: Int
    let builderRevision: String

    var identity: String {
        [component.rawValue, artifactID, version, sha256.lowercased()].joined(separator: ":")
    }

    func validateMetadata() throws {
        guard downloadURL.scheme?.lowercased() == "https" else {
            throw OtzariaDataProfileError.invalidManifest("\(component.rawValue) URL must use HTTPS")
        }
        guard compressedBytes > 0, extractedBytes > 0 else {
            throw OtzariaDataProfileError.invalidManifest("\(component.rawValue) sizes must be positive")
        }
        guard sha256.count == 64, sha256.allSatisfy(\.isHexDigit) else {
            throw OtzariaDataProfileError.invalidManifest("\(component.rawValue) SHA-256 is malformed")
        }
        guard schemaVersion > 0, artifactVersion > 0, !builderRevision.isEmpty else {
            throw OtzariaDataProfileError.invalidManifest("\(component.rawValue) version metadata is missing")
        }
    }
}

struct OtzariaDataProfile: Codable, Equatable, Identifiable, Sendable {
    struct SourceDatabase: Codable, Equatable, Sendable {
        let repository: String
        let releaseTag: String
        let releaseID: Int64
        let assetName: String
        let assetSHA256: String
        let fingerprint: String
    }

    let profileID: String
    let displayName: String
    let profileVersion: Int
    let sourceDatabase: SourceDatabase
    let bookIDs: [Int]
    let artifacts: [OtzariaArtifactDescriptor]
    let goldenQueries: [String]

    var id: String { profileID }

    func artifact(_ component: OtzariaArtifactComponent) -> OtzariaArtifactDescriptor? {
        artifacts.first { $0.component == component }
    }

    func validate() throws {
        guard profileID.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil else {
            throw OtzariaDataProfileError.invalidManifest("profileID contains unsafe path characters")
        }
        guard profileVersion > 0 else {
            throw OtzariaDataProfileError.invalidManifest("profileVersion must be positive")
        }
        guard Set(bookIDs).count == bookIDs.count else {
            throw OtzariaDataProfileError.invalidManifest("bookIDs contains duplicates")
        }
        guard Set(artifacts.map(\.component)).count == artifacts.count else {
            throw OtzariaDataProfileError.invalidManifest("artifact components must be unique")
        }
        for artifact in artifacts { try artifact.validateMetadata() }
    }
}

enum OtzariaDataProfileError: LocalizedError, Sendable {
    case profileNotFound(String)
    case invalidManifest(String)
    case missingArtifact(OtzariaArtifactComponent)

    var errorDescription: String? {
        switch self {
        case .profileNotFound(let id):
            return "The Otzaria data profile '\(id)' is not bundled with this build."
        case .invalidManifest(let detail):
            return "The Otzaria data profile is invalid: \(detail)"
        case .missingArtifact(let component):
            return "The active Otzaria data profile is missing \(component.rawValue)."
        }
    }
}

struct OtzariaInstalledArtifactState: Codable, Equatable, Sendable {
    enum ValidationState: String, Codable, Sendable {
        case unknown
        case metadataVerified
        case fullyVerified
        case invalid
    }

    let profileID: String
    let profileVersion: Int
    let component: OtzariaArtifactComponent
    let artifactIdentity: String
    let installedBytes: Int64
    let installedAt: Date
    let validationState: ValidationState
    let lastValidatedAt: Date?

    func matches(profile: OtzariaDataProfile, descriptor: OtzariaArtifactDescriptor) -> Bool {
        profileID == profile.profileID &&
            profileVersion == profile.profileVersion &&
            component == descriptor.component &&
            artifactIdentity == descriptor.identity &&
            installedBytes == descriptor.extractedBytes &&
            validationState != .invalid
    }
}

extension Notification.Name {
    static let otzariaDataProfileWillChange = Notification.Name("otzariaDataProfileWillChange")
    static let otzariaDataProfileDidChange = Notification.Name("otzariaDataProfileDidChange")
}

enum OtzariaProductPolicy {
    static var usesManagedOtzariaData: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    static var disablesLegacyLibraryActions: Bool { usesManagedOtzariaData }
}
