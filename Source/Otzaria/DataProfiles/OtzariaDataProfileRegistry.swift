import Foundation

enum OtzariaDataProfileRegistry {
    static let productionID = "production"
    static let miniTest10ID = "miniTest10"
    static let defaultsKey = "otzaria.activeDataProfile"
    static let launchArgument = "-OtzariaDataProfile"
    static let environmentKey = "OTZARIA_DATA_PROFILE"

    static var activeProfileID: String {
        if let argument = launchArgumentValue(), !argument.isEmpty { return argument }
        if let environment = ProcessInfo.processInfo.environment[environmentKey], !environment.isEmpty {
            return environment
        }
        return UserDefaults.standard.string(forKey: defaultsKey) ?? productionID
    }

    static var activeProfile: OtzariaDataProfile? {
        try? loadProfile(id: activeProfileID)
    }

    static func requireActiveProfile() throws -> OtzariaDataProfile {
        try loadProfile(id: activeProfileID)
    }

    static func loadProfile(id: String, bundle: Bundle = .main) throws -> OtzariaDataProfile {
        if id == productionID { return productionProfile }
        guard let url = bundle.url(forResource: id, withExtension: "profile.json") else {
            throw OtzariaDataProfileError.profileNotFound(id)
        }
        let decoder = JSONDecoder()
        let profile = try decoder.decode(OtzariaDataProfile.self, from: Data(contentsOf: url))
        try profile.validate()
        guard profile.profileID == id else {
            throw OtzariaDataProfileError.invalidManifest("resource name and profileID differ")
        }
        return profile
    }

    static func selectProfile(_ profileID: String) throws {
        let profile = try loadProfile(id: profileID)
        let previous = activeProfileID
        guard previous != profile.profileID else { return }
        NotificationCenter.default.post(
            name: .otzariaDataProfileWillChange,
            object: nil,
            userInfo: ["from": previous, "to": profile.profileID]
        )
        UserDefaults.standard.set(profile.profileID, forKey: defaultsKey)
        NotificationCenter.default.post(
            name: .otzariaDataProfileDidChange,
            object: nil,
            userInfo: ["from": previous, "to": profile.profileID]
        )
    }

    private static func launchArgumentValue() -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: launchArgument), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    static let productionProfile = OtzariaDataProfile(
        profileID: productionID,
        displayName: "Production",
        profileVersion: 1,
        sourceDatabase: .init(
            repository: OtzariaLibraryRelease.repository,
            releaseTag: "latest",
            releaseID: 0,
            assetName: OtzariaLibraryRelease.databaseAssetName,
            assetSHA256: "",
            fingerprint: "dynamic-latest-release"
        ),
        bookIDs: [],
        artifacts: [],
        goldenQueries: ["לחתוך צנון בסכין בשרי"]
    )
}
