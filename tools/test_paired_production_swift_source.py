#!/usr/bin/env python3
"""Source-bound production receipt and original-launch controls; never native acceptance."""
import argparse, hashlib, json, pathlib, re, shutil, subprocess, sys, datetime

def require(ok, message):
    if not ok:
        raise RuntimeError(message)

def digest(data):
    return hashlib.sha256(data).hexdigest()

def original_method(source, marker):
    start = source.index(marker)
    end = source.index("\n    }\n", start) + len("\n    }\n")
    return source[start:end]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--module-cache", type=pathlib.Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    out = args.output.resolve()
    require(not out.exists(), "Preserve every prior source-control attempt")
    require(shutil.disk_usage(root).free >= 256 * 1024 * 1024 + 100 * 1024 * 1024,
            "Original reserve plus this bounded control budget is required")
    source_path = root / "Maktabah-iOSUITests/ProductionAnnotationEditorAcceptanceTests.swift"
    source = source_path.read_text()
    def git(*values):
        return subprocess.check_output(["git", "-c", "gc.auto=0", "-c", "maintenance.auto=false",
                                        "-C", str(root), *values])
    base = "95a8e41c69da9add6e260d6b5afb20fe316fcfe4"
    donor = "8c0e9b21cf7f87c18383aa4fc329c65bf974d441"
    base_path = "Maktabah-iOSUITests/MaktabahUITestBase.swift"
    faithful_path = "Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift"
    base_source = git("show", base + ":" + base_path).decode()
    faithful = git("show", base + ":" + faithful_path).decode()
    donor_source = git("show", donor + ":" + str(source_path.relative_to(root))).decode()
    out.mkdir(parents=True, exist_ok=False)
    for name, text in [("candidate.swift", source), ("original-base.swift", base_source),
                       ("original-faithful.swift", faithful), ("donor.swift", donor_source)]:
        (out / name).write_text(text)

    production_types = source[source.index("// Paired acceptance consumes"):source.index(
        "extension ProductionAnnotationEditorAcceptanceTests {", source.index("// Paired acceptance consumes"))]
    tier_start = base_source.index("public enum TestTier:")
    tier_end = base_source.index("\n}\n", tier_start) + len("\n}\n")
    tier = base_source[tier_start:tier_end]
    launch = original_method(base_source, "    func launchWithTier(")
    reader0 = original_method(faithful, "    func launchReader(enabled:")
    reader1_start = faithful.index("    func launchReader(enabled:", faithful.index(reader0) + len(reader0))
    reader1 = original_method(faithful[reader1_start:], "    func launchReader(enabled:")
    legacy_helper = original_method(donor_source, "    private func createAndShareOrdinaryNativeNote(")
    legacy_launch = next(line.strip() for line in legacy_helper.splitlines() if line.strip().startswith("launchReader("))
    corrected_helper = original_method(source, "    private func launchPairedProductionReader(")
    corrected_launch = next(line.strip() for line in corrected_helper.splitlines() if line.strip().startswith("launchWithTier("))

    # Only XCUIApplication and platform rendering are boundary doubles. The tier
    # enum, original launch bodies, paired call expressions and receipt policy are
    # extracted byte-for-byte from their recorded actual sources.
    harness = "import Foundation\n" + production_types + "\n" + tier + r"""
final class XCUIApplication {
    var launchArguments: [String] = []
    var launchEnvironment: [String: String] = [:]
    init(bundleIdentifier: String) {}
    func launch() {}
}
final class OriginalLaunchHost {
    var app: XCUIApplication!
    private let workspaceTestNamespace = UUID().uuidString
    var isolatesStudyWorkspace: Bool { true }
    let workspaceNamespace = UUID().uuidString
    private var viewportURL: URL?
    var readerTestTier: TestTier { .realUI }
    var readerAdditionalLaunchArguments: [String] { [] }
    private func recordRuntime27Configuration(stage: String) {}
    func dismissAlertsIfNeeded() {}
""" + launch + reader0 + reader1 + """
    func baseline() { """ + legacy_launch + """ }
    func candidate() { _ = """ + corrected_launch + """ }
}
""" + r"""
@main
struct Controls {
    static func main() throws {
        var rows: [[String: Any]] = []
        func check(_ name: String, _ condition: Bool) {
            rows.append(["name": name, "pass": condition])
        }
        func rejected(_ name: String, _ body: () throws -> Void) {
            do { try body(); check(name, false) } catch { check(name, true) }
        }
        let baseline = CommandLine.arguments.contains("--baseline")
        let app = OriginalLaunchHost()
        if baseline { app.baseline() } else { app.candidate() }
        check("actual-original-launch-uses-production", app.app.launchEnvironment["OTZARIA_DATA_PROFILE"] == "production")
        check("actual-original-launch-omits-smoke-scenario", !app.app.launchArguments.contains("-smokeScenario"))
        check("actual-original-launch-omits-UUID-test-workspace", !app.app.launchArguments.contains("-studyWorkspaceTestingNamespace"))
        do {
            try OrdinaryPairedProductionPolicy.validateLaunch(arguments: app.app.launchArguments, environment: app.app.launchEnvironment)
            check("exact-original-production-launch-contract", true)
        } catch { check("exact-original-production-launch-contract", false) }
        if !baseline {
            let udid = "11111111-1111-4111-8111-111111111111"
            let witness: [String: Any] = ["path": "/source-control-boundary/fixture", "bytes": 123,
                                          "sha256": String(repeating: "a", count: 64)]
            let canonical: [String: Any] = [
                "schema": "otzaria.original.two-full-apps.production.v1",
                "udid": udid, "bundle_id": "com.davidpovarsky.chavrusatext",
                "profile": "production", "release_id": 455390662,
                "data_container": "/source-control-boundary/app",
                "documents_directory": "/source-control-boundary/app/Documents",
                "data_container_metadata": witness,
                "corpus_owner_container": "/source-control-boundary/group",
                "corpus_owner_metadata": witness,
                "installed_database": ["path": "/source-control-boundary/group/Otzaria/seforim.db",
                    "bytes": Int64(4355063808),
                    "sha256": "8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01"],
                "corpus": ["counts": ["book": 8259, "line": 7925185, "link": 7001824]],
                "installation_manifest": witness, "install_receipt": witness,
                "target_book": ["book_id": 103, "title": "Actual SQL title boundary"]
            ]
            func validate(_ object: [String: Any], udid: String = udid) throws {
                let bytes = try JSONSerialization.data(withJSONObject: object)
                let receipt = try JSONDecoder().decode(OrdinaryPairedProductionReceipt.self, from: bytes)
                try OrdinaryPairedProductionPolicy.validate(receipt, actualUDID: udid)
            }
            try validate(canonical); check("fixed-complete-v40-source-contract", true)
            for (key, bad) in [
                ("schema", "foreign"), ("bundle_id", "foreign.bundle"),
                ("profile", "miniTest10"), ("udid", "22222222-2222-4222-8222-222222222222")
            ] {
                var object = canonical; object[key] = bad
                rejected("reject-" + key) { try validate(object) }
            }
            var object = canonical; object["release_id"] = 1
            rejected("reject-different-release") { try validate(object) }
            rejected("reject-absent-actual-simulator") { try validate(canonical, udid: "") }
            object = canonical; object.removeValue(forKey: "data_container_metadata")
            rejected("reject-missing-app-owner-witness") { try validate(object) }
            object = canonical; object.removeValue(forKey: "corpus_owner_metadata")
            rejected("reject-missing-corpus-owner-witness") { try validate(object) }
            object = canonical; object.removeValue(forKey: "install_receipt")
            rejected("reject-missing-original-installer-receipt") { try validate(object) }
            for key in ["book", "line", "link"] {
                var changed = canonical
                var counts = ["book": 8259, "line": 7925185, "link": 7001824]
                counts[key] = 10; changed["corpus"] = ["counts": counts]
                rejected("reject-incomplete-corpus-" + key) { try validate(changed) }
            }
            object = canonical; object["corpus"] = ["counts": ["book": 8259, "line": 7925185, "link": 7001824, "other": 1]]
            rejected("reject-foreign-corpus-shape") { try validate(object) }
            for (name, book) in [
                ("different-book", ["book_id": 3891, "title": "Actual SQL title boundary"] as [String: Any]),
                ("empty-title", ["book_id": 103, "title": " \n "] as [String: Any]),
                ("unbounded-title", ["book_id": 103, "title": String(repeating: "x", count: 1025)] as [String: Any])
            ] {
                var changed = canonical; changed["target_book"] = book
                rejected("reject-" + name) { try validate(changed) }
            }
            for (field, value) in [("bytes", Int64(123) as Any), ("sha256", String(repeating: "b", count: 64) as Any)] {
                var changed = canonical
                var database = changed["installed_database"] as! [String: Any]
                database[field] = value; changed["installed_database"] = database
                rejected("reject-installed-database-" + field) { try validate(changed) }
            }
            for (field, value) in [("bytes", 0 as Any), ("path", "relative" as Any),
                                   ("sha256", "invalid" as Any), ("sha256", String(repeating: "G", count: 64) as Any)] {
                var changed = canonical; var invalid = witness; invalid[field] = value
                changed["installation_manifest"] = invalid
                rejected("reject-manifest-witness-" + field + "-" + String(describing: value).prefix(8)) { try validate(changed) }
            }
            try OrdinaryPairedProductionPolicy.validateRunner(["OTZARIA_DATA_PROFILE": "production",
                                                               "TEST_RUNNER_SIMCTL_CHILD_OTZARIA_DATA_PROFILE": "production"])
            check("runner-production-profile-remains-allowed", true)
            let forbidden = [
                "OTZARIA_SHARED_ROOT_OVERRIDE", "OTZARIA_PRODUCTION_DB_PATH",
                "OTZARIA_ANNOTATION_ACCEPTANCE_DATABASE", "CHAVRUSA_READER_VIEWPORT_REPORT",
                "FAITHFUL_VIEWPORT_DIRECTORY",
                "OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE", "OTZARIA_NATIVE_BOOTSTRAP_RELEASE_ID",
                "OTZARIA_ORIGINAL_EDITOR_QUALIFICATION", "OTZARIA_ORIGINAL_EDITOR_PROCESS_RESUME"
            ]
            for key in forbidden {
                rejected("reject-runner-presence-" + key) {
                    try OrdinaryPairedProductionPolicy.validateRunner([key: ""])
                }
            }
            for prefix in ["TEST_RUNNER_", "SIMCTL_CHILD_", "TEST_RUNNER_SIMCTL_CHILD_TEST_RUNNER_"] {
                rejected("reject-runner-aliased-storage-" + prefix) {
                    try OrdinaryPairedProductionPolicy.validateRunner([prefix + "OTZARIA_PRODUCTION_DB_PATH": "0"])
                }
                rejected("reject-runner-aliased-mini-profile-" + prefix) {
                    try OrdinaryPairedProductionPolicy.validateRunner([prefix + "OTZARIA_DATA_PROFILE": "miniTest10"])
                }
            }
            for extra in [["-smokeScenario", "readerDetail"], ["-smokeBypassBootstrap"],
                          ["-studyWorkspaceTestingNamespace", udid], ["-foreignFlag"]] {
                rejected("reject-extra-app-arguments-" + extra[0]) {
                    try OrdinaryPairedProductionPolicy.validateLaunch(arguments: app.app.launchArguments + extra,
                                                                      environment: app.app.launchEnvironment)
                }
            }
            var launchEnvironment = app.app.launchEnvironment
            launchEnvironment["OTZARIA_ANYTYPE_NETWORK_UI"] = "test-owned-original-account"
            rejected("reject-network-test-flag-in-app") {
                try OrdinaryPairedProductionPolicy.validateLaunch(arguments: app.app.launchArguments, environment: launchEnvironment)
            }
            launchEnvironment = app.app.launchEnvironment; launchEnvironment["OTZARIA_DATA_PROFILE"] = "miniTest10"
            rejected("reject-app-mini-profile") {
                try OrdinaryPairedProductionPolicy.validateLaunch(arguments: app.app.launchArguments, environment: launchEnvironment)
            }
        }
        let failures = rows.filter { $0["pass"] as? Bool != true }.count
        let result: [String: Any] = [
            "mode": baseline ? "original-donor-launch" : "corrected-production-launch-and-policy",
            "passed": rows.count - failures, "failed": failures, "cases": rows,
            "actual_launch_arguments": app.app.launchArguments,
            "actual_launch_environment": app.app.launchEnvironment,
            "boundary": "Exact original launch source and actual paired receipt policy with explicit XCUIApplication double; no app, MCM, SQLite, UIKit, simulator, network or native acceptance"
        ]
        print(String(decoding: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys, .prettyPrinted]), as: UTF8.self))
        if failures != 0 { exit(1) }
    }
}
"""
    (out / "ControlInput.swift").write_text(harness)
    files = {"candidate": (str(source_path), source), "original_base": (base_path, base_source),
             "original_faithful": (faithful_path, faithful), "donor": (donor, donor_source),
             "control_input": (str(out / "ControlInput.swift"), harness)}
    pins = {key: {"path": path, "bytes": len(text.encode()), "sha256": digest(text.encode())}
            for key, (path, text) in files.items()}
    commands = []
    def run(name, command, expected):
        commands.append({"name": name, "argv": [str(value) for value in command], "expected_exit": expected})
        (out / "COMMANDS.json").write_text(json.dumps(commands, indent=2) + "\n")
        with (out / (name + ".stdout")).open("w") as stdout, (out / (name + ".stderr")).open("w") as stderr:
            completed = subprocess.run(command, cwd=root, stdout=stdout, stderr=stderr, text=True, timeout=60)
        commands[-1]["actual_exit"] = completed.returncode
        (out / "COMMANDS.json").write_text(json.dumps(commands, indent=2) + "\n")
        require(completed.returncode == expected, name + " exit " + str(completed.returncode))
    (out / "INPUTS.json").write_text(json.dumps(pins, indent=2) + "\n")
    run("syntax", ["swiftc", "-frontend", "-parse", source_path], 0)
    run("compile", ["swiftc", "-swift-version", "6", "-strict-concurrency=complete", "-parse-as-library",
                    "-module-cache-path", args.module_cache, out / "ControlInput.swift", "-o", out / "controls"], 0)
    run("original-baseline", [out / "controls", "--baseline"], 1)
    run("candidate", [out / "controls"], 0)
    baseline_result = json.loads((out / "original-baseline.stdout").read_text())
    candidate_result = json.loads((out / "candidate.stdout").read_text())
    preserved = []
    for name in re.findall(r"    func (test\w+)\(", donor_source):
        if name == "testOrdinaryOriginalNativeTwoAppExchangePhase":
            continue
        original = original_method(donor_source, "    func " + name + "(")
        current = original_method(source, "    func " + name + "(")
        require(original == current, "An existing native case body changed: " + name)
        preserved.append({"name": name, "bytes": len(original.encode()), "sha256": digest(original.encode())})
    # Real paired methods may observe only original production state. Existing
    # nonpaired helpers retain their old namespace branch unchanged.
    paired_method = original_method(source, "    func testOrdinaryOriginalNativeTwoAppExchangePhase(")
    require("launchReader(" not in paired_method and "workspaceSidecarURL" not in paired_method,
            "Paired method still reaches a fixture launcher or UUID sidecar")
    require("loadPairedProduction()" in paired_method and "defer { pairedProduction = nil }" in paired_method,
            "The paired receipt lifetime must be explicit")
    require("scenario: nil" in corrected_helper and "launchWithTier(.production" in corrected_helper,
            "Original production entry must remain explicit")
    require("readerLibraryPaletteLauncher()" in corrected_helper and "input.typeText(installation.receipt.target_book.title)" in corrected_helper,
            "Keep actual original Library and source-derived title entry")
    # No input mutation is permitted; these patterns name SQL writes, process/
    # corpus injection and invented workspace creation, not UI-owned edit actions.
    appended = source[source.index("// Paired acceptance consumes"):]
    for prohibited in ["SQLITE_OPEN_READWRITE", "SQLITE_OPEN_CREATE", "INSERT INTO", "UPDATE annotations",
                       "UserDefaults.standard.set", "createDirectory(", "setValue(", "SIMCTL_CHILD_OTZARIA_SHARED_ROOT_OVERRIDE"]:
        require(prohibited not in appended, "Paired acceptance added an injection: " + prohibited)
    result = {"schema": "otzaria.wave3.paired-production.source-controls.v1",
              "completed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "status": "SOURCE_CONTROLS_PASS_NATIVE_NOT_RUN", "baseline": baseline_result,
              "candidate": candidate_result, "preserved_original_cases": preserved,
              "input_pins": pins, "commands": commands,
              "native": "NOT_RUN; Apple typecheck, actual MCM, production installation, original UI and two-app transport pending",
              "free_after": shutil.disk_usage(root).free}
    (out / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"output": str(out), "result_sha256": digest((out / "RESULT.json").read_bytes()),
                      "baseline": [baseline_result["passed"], baseline_result["failed"]],
                      "candidate": [candidate_result["passed"], candidate_result["failed"]],
                      "preserved_cases": len(preserved), "free_after": result["free_after"]}))

if __name__ == "__main__":
    main()
