import Foundation

func require(_ value: @autoclosure () -> Bool, _ message: String) {
    if !value() { fatalError(message) }
}

let production = OtzariaDataProfileRegistry.productionID
let mini = OtzariaDataProfileRegistry.miniTest10ID
let bundled = try JSONDecoder().decode(
    OtzariaDataProfile.self,
    from: Data(contentsOf: URL(fileURLWithPath: "Source/Otzaria/DataProfiles/miniTest10.profile.json"))
)
try bundled.validate()
require(bundled.profileID == mini && bundled.bookIDs.count == 10, "bundled mini profile is invalid")
require(bundled.profileVersion == 2, "bundled mini profile version is not canonical v2")
require(bundled.sharedLexicalDatabase.releaseTag == "v0.3.0", "lexical release is not pinned")

require(
    OtzariaDataProfileRegistry.resolvedProfileID(
        arguments: ["Maktabah"], environment: [:], embeddedDefault: nil
    ) == production,
    "an ordinary production build must default to production"
)
require(
    OtzariaDataProfileRegistry.resolvedProfileID(
        arguments: ["Maktabah"], environment: [:], embeddedDefault: mini
    ) == mini,
    "an embedded mini build default was not selected"
)
require(
    OtzariaDataProfileRegistry.resolvedProfileID(
        arguments: ["Maktabah"], environment: [OtzariaDataProfileRegistry.environmentKey: production],
        embeddedDefault: mini
    ) == production,
    "environment override did not outrank the embedded default"
)
require(
    OtzariaDataProfileRegistry.resolvedProfileID(
        arguments: ["Maktabah", OtzariaDataProfileRegistry.launchArgument, mini],
        environment: [OtzariaDataProfileRegistry.environmentKey: production], embeddedDefault: production
    ) == mini,
    "launch argument did not have highest precedence"
)

require(
    OtzariaDataProfileCompatibility.matches(
        profileID: nil, profileVersion: nil, activeID: production, activeVersion: 1
    ),
    "legacy production metadata must remain compatible"
)
require(
    !OtzariaDataProfileCompatibility.matches(
        profileID: nil, profileVersion: nil, activeID: mini, activeVersion: 1
    ),
    "legacy production metadata leaked into miniTest10"
)
require(
    OtzariaDataProfileCompatibility.matches(
        profileID: mini, profileVersion: 2, activeID: mini, activeVersion: 2
    ),
    "same miniTest10 profile did not survive relaunch validation"
)
require(
    !OtzariaDataProfileCompatibility.matches(
        profileID: mini, profileVersion: 2, activeID: production, activeVersion: 1
    ),
    "miniTest10 metadata leaked into production"
)
require(
    !OtzariaDataProfileCompatibility.matches(
        profileID: mini, profileVersion: 1, activeID: mini, activeVersion: 2
    ),
    "mismatched profile version was accepted"
)

let base = URL(fileURLWithPath: "/tmp/profile-tests", isDirectory: true)
let miniDatabase = OtzariaProfileStorage.applicationSupportRoot(
    base: base, component: .database, profileID: mini
)
let miniOtzaria = OtzariaProfileStorage.applicationSupportRoot(
    base: base, component: .otzariaSearch, profileID: mini
)
let miniZayit = OtzariaProfileStorage.applicationSupportRoot(
    base: base, component: .zayitSearch, profileID: mini
)
require(miniDatabase.path != miniOtzaria.path && miniOtzaria.path != miniZayit.path,
        "partial component installs must use isolated roots")
require(miniDatabase.path.contains("/Profiles/miniTest10/"), "mini profile root is not namespaced")

print("Otzaria data profile isolation/relaunch/partial/mismatch tests passed")
