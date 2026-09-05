import Foundation

enum OtzariaDataProfileRegistry {
    static let productionID = "production"
    static let miniTest10ID = "miniTest10"
    static let launchArgument = "-OtzariaDataProfile"
    static let environmentKey = "OTZARIA_DATA_PROFILE"

    static var activeProfileID: String {
        if let value = launchArgumentValue(), !value.isEmpty { return value }
        if let value = ProcessInfo.processInfo.environment[environmentKey], !value.isEmpty { return value }
        return productionID
    }

    static var activeProfile: OtzariaDataProfile? {
        guard activeProfileID != productionID else { return nil }
        return try? loadProfile(id: activeProfileID)
    }

    static var activeIdentity: (id: String, version: Int) {
        let selected = activeProfileID
        guard selected != productionID else { return (productionID, 1) }
        return (selected, activeProfile?.profileVersion ?? 1)
    }

    static func requireActiveProfile() throws -> OtzariaDataProfile {
        guard activeProfileID != productionID else {
            throw OtzariaDataProfileError.profileNotFound(productionID)
        }
        return try loadProfile(id: activeProfileID)
    }

    static func loadProfile(id: String, bundle: Bundle = .main) throws -> OtzariaDataProfile {
        guard id != productionID,
              let url = bundle.url(forResource: "\(id).profile", withExtension: "json") else {
            throw OtzariaDataProfileError.profileNotFound(id)
        }
        let profile = try JSONDecoder().decode(OtzariaDataProfile.self, from: Data(contentsOf: url))
        try profile.validate()
        guard profile.profileID == id else {
            throw OtzariaDataProfileError.invalidManifest("resource name and profileID differ")
        }
        return profile
    }

    private static func launchArgumentValue() -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: launchArgument),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
