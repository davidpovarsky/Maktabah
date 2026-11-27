import Foundation
import Darwin

// Compile-only boundaries for unrelated original app owners. These methods
// are never called: controls exercise only the exact admittedNamespace source.
@MainActor enum OtzariaDataProfileRegistry { static let activeProfileID = "COMPILE_ONLY" }
@MainActor enum OtzariaIndexFileLogger { static let memoryFootprint = 1 }
@MainActor final class OtzariaFileLogger {
    static let shared = OtzariaFileLogger()
    func log(_ value: String) { fatalError("Original logger must not run in admission controls") }
}

@main
struct ProductionGroupsAdmissionControls {
    @MainActor static func main() throws {
        let namespace = "FC212997-B126-45A0-B55C-72BCB3765865"
        let enabledArgs = ["-StudyGroupPerformanceEnabled", "YES"]
        let productionArgs = enabledArgs + ["-StudyGroupProductionPerformanceEnabled", "YES"]
        var results: [[String: Any]] = []
        @MainActor func check(_ name: String, args: [String], profile: String, environment: String?,
                   enabled: Bool = true, namespace supplied: String? = "FC212997-B126-45A0-B55C-72BCB3765865",
                   production: Bool = false, expected: Bool) {
            let env = environment.map { ["OTZARIA_DATA_PROFILE": $0] } ?? [:]
            #if PRODUCTION_GROUP_OBSERVATION_CANDIDATE
            let value = StudyGroupSwitchPerformanceObservation.admittedNamespace(arguments: args,
                environment: env, activeProfile: profile, enabled: enabled, namespace: supplied,
                productionEnabled: production)
            #else
            let value = StudyGroupSwitchPerformanceObservation.admittedNamespace(arguments: args,
                environment: env, activeProfile: profile, enabled: enabled, namespace: supplied)
            #endif
            let accepted = value == namespace
            results.append(["name": name, "expectedAccepted": expected, "actualAccepted": accepted,
                            "pass": accepted == expected, "returnedOnlyExactNamespace": value == nil || value == supplied])
        }
        check("original enabled mini", args: enabledArgs, profile: "miniTest10", environment: "miniTest10", expected: true)
        check("mini unchanged with extra production flag", args: productionArgs, profile: "miniTest10", environment: "miniTest10", production: true, expected: true)
        check("mini no original flag", args: [], profile: "miniTest10", environment: "miniTest10", expected: false)
        check("mini original flag false", args: enabledArgs, profile: "miniTest10", environment: "miniTest10", enabled: false, expected: false)
        check("mini invalid namespace", args: enabledArgs, profile: "miniTest10", environment: "miniTest10", namespace: "invalid", expected: false)
        check("mini missing namespace", args: enabledArgs, profile: "miniTest10", environment: "miniTest10", namespace: nil, expected: false)
        check("ordinary production remains silent", args: enabledArgs, profile: "production", environment: "production", expected: false)
        check("production opt-in", args: productionArgs, profile: "production", environment: "production", production: true, expected: true)
        check("production missing separate flag", args: enabledArgs, profile: "production", environment: "production", production: true, expected: false)
        check("production separate flag false", args: productionArgs, profile: "production", environment: "production", production: false, expected: false)
        check("production original flag false", args: productionArgs, profile: "production", environment: "production", enabled: false, production: true, expected: false)
        check("production original flag missing", args: ["-StudyGroupProductionPerformanceEnabled", "YES"], profile: "production", environment: "production", production: true, expected: false)
        check("production wrong active profile", args: productionArgs, profile: "miniTest10", environment: "production", production: true, expected: false)
        check("production wrong environment profile", args: productionArgs, profile: "production", environment: "miniTest10", production: true, expected: false)
        check("production absent environment", args: productionArgs, profile: "production", environment: nil, production: true, expected: false)
        check("production invalid namespace", args: productionArgs, profile: "production", environment: "production", namespace: "invalid", production: true, expected: false)
        check("production empty namespace", args: productionArgs, profile: "production", environment: "production", namespace: "", production: true, expected: false)
        check("production missing namespace", args: productionArgs, profile: "production", environment: "production", namespace: nil, production: true, expected: false)
        check("unrecognized profile", args: productionArgs, profile: "v40", environment: "v40", production: true, expected: false)
        let failures = results.filter { $0["pass"] as? Bool != true || $0["returnedOnlyExactNamespace"] as? Bool != true }.count
        let record: [String: Any] = ["scope": "Whole original Swift admission function; compile-only unrelated dependency boundaries; no UI, operation, memory or timing execution", "count": results.count, "passed": results.count - failures, "failed": failures, "uiExecuted": 0, "results": results]
        let bytes = try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: bytes, as: UTF8.self))
        if failures > 0 { exit(1) }
    }
}
