#!/usr/bin/env python3
"""Portable policy + exact source install/recovery/writer regressions.

No real index, archive/network, Apple runtime or qualification evidence is
produced. The normal policy is compiled unchanged (type renamed for isolation).
Flow fixtures forward to that complete production policy without a candidate
admission override. The historical disabled-registry evidence remains immutable.
"""
from pathlib import Path
import argparse, datetime, hashlib, json, os, subprocess, tempfile

ROOT = Path(__file__).resolve().parents[1]
BASE = "7e777509d486a17bec5b4bd437a9ac7f51d3a43a"
POLICY = "Source/Otzaria/Search/Distribution/OtzariaSearchArtifactPolicy.swift"
INSTALLER = "Source/Otzaria/Search/Distribution/OtzariaSearchArtifactInstaller.swift"
MANAGER = "Source/Otzaria/Search/OtzariaSearchIndexManager.swift"

def block(source, marker):
    start = source.index(marker)
    header_end = start
    if "func " in marker:
        header_end = source.index("(", start) + 1
        depth = 1
        while depth:
            depth += (source[header_end] == "(") - (source[header_end] == ")")
            header_end += 1
    opening = source.index("{", header_end)
    depth = 1
    pos = opening + 1
    while depth:
        depth += (source[pos] == "{") - (source[pos] == "}")
        pos += 1
    return source[start:pos]

def digest(data):
    return hashlib.sha256(data).hexdigest()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir", required=True, type=Path)
    parser.add_argument("--baseline-flows", action="store_true")
    parser.add_argument("--swiftc", default="swiftc")
    parser.add_argument("--compile-timeout-seconds", type=int, default=120)
    parser.add_argument("--compiler-jobs", type=int, default=1)
    options = parser.parse_args()
    out = options.artifacts_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    (ROOT / "build").mkdir(exist_ok=True)
    owned = Path(tempfile.mkdtemp(prefix="read-compat-", dir=ROOT / "build"))
    original = {p: subprocess.check_output(["git", "show", BASE + ":" + p], cwd=ROOT)
                for p in (POLICY, INSTALLER, MANAGER)}
    current = {p: (ROOT / p).read_bytes() for p in (POLICY, INSTALLER, MANAGER)}
    policy = current[POLICY].decode("utf-8-sig")
    baseline_policy = original[POLICY].decode("utf-8-sig")
    (owned / "Policy.swift").write_text(policy.replace("OtzariaSearchArtifactPolicy", "SubjectArtifactPolicy"), encoding="utf-8")
    (owned / "BaselinePolicy.swift").write_text(baseline_policy.replace("OtzariaSearchArtifactPolicy", "BaselineArtifactPolicy")
        .replace("OtzariaManagedDiscoveryDisposition", "BaselineManagedDiscoveryDisposition"), encoding="utf-8")
    models = (ROOT / "Source/Otzaria/Search/OtzariaSearchModels.swift").read_text(encoding="utf-8-sig")
    model_names = ["OtzariaSearchEngineBuildInfo", "OtzariaIndexFingerprint", "OtzariaSemanticArtifactIdentity",
                   "OtzariaIndexBuildIdentity", "OtzariaIndexCheckpoint"]
    model_source = "import Foundation\n" + "\n".join(block(models, "struct " + name + ":") for name in model_names)
    db_models = (ROOT / "Source/Otzaria/Bootstrap/OtzariaDatabaseDownloadModels.swift").read_text(encoding="utf-8-sig")
    model_source += "\n" + block(db_models, "struct OtzariaDatabaseInstallationManifest:")
    manifest = (ROOT / "Source/Otzaria/Search/Distribution/OtzariaSearchArtifactManifest.swift").read_text(encoding="utf-8-sig")
    model_source += "\n" + manifest.split("extension OtzariaSearchArtifactError:", 1)[0]
    (owned / "Models.swift").write_text(model_source, encoding="utf-8")
    subject = original if options.baseline_flows else current
    installer = subject[INSTALLER].decode("utf-8-sig")
    manager = subject[MANAGER].decode("utf-8-sig")
    install_methods = ["    func install(", "    func installStreaming(", "    func recover(",
                       "    func promote(", "    func writeTrustedManifest("]
    source = "import Foundation\nstruct OtzariaSearchArtifactInstaller: Sendable {\n"
    source += "let extractor = OtzariaZstdStreamExtractor()\n"
    source += "\n".join(block(installer, name) for name in install_methods)
    source += "\nfunc excludeFromBackup(_ url: URL) throws {}\n}\n"
    (owned / "Installer.swift").write_text(source, encoding="utf-8")
    manager_methods = ["    func currentFingerprint(", "    func makeIdentity(", "    func storedIdentity(",
                       "    func writeIdentity(", "    func checkpoint(", "    func writeCheckpoint(",
                       "    func prepareOrResumeBuildingIndex(", "    func validateCurrentIndex(",
                       "    func recoverTrustedManagedIndex(", "    private func canSeedBuildingIndex("]
    if "    func trustedManagedReadManifest(" in manager:
        manager_methods.append("    func trustedManagedReadManifest(")
    source = "import Foundation\nfinal class OtzariaSearchIndexManager: @unchecked Sendable {\n"
    source += (ROOT / "Tests/HQ/search/IndexReadCompatibilityManagerBoundary.swift").read_text(encoding="utf-8")
    source += "\n".join(block(manager, name) for name in manager_methods)
    if "    func trustedManagedReadManifest(" not in manager:
        source += "\nfunc trustedManagedReadManifest(indexURL: URL, databasePath: String, build: OtzariaSearchEngineBuildInfo) -> OtzariaSearchArtifactManifest? { nil }\n"
    source += "\n}\n"
    (owned / "Manager.swift").write_text(source, encoding="utf-8")
    writer_markers = ["    func makeIdentity(", "    func prepareOrResumeBuildingIndex(",
                      "    private func canSeedBuildingIndex("]
    writer_parity = {marker.strip(): block(current[MANAGER].decode("utf-8-sig"), marker)
        == block(original[MANAGER].decode("utf-8-sig"), marker) for marker in writer_markers}
    if not all(writer_parity.values()):
        raise RuntimeError("An exact-writer method changed")
    exe = owned / ("read-compat.exe" if os.name == "nt" else "read-compat")
    fixtures = [ROOT / "Tests/HQ/search/IndexReadCompatibilityBoundary.swift",
                ROOT / "Tests/HQ/search/IndexReadCompatibilityFixtures.swift"]
    command = [options.swiftc, "-parse-as-library", "-swift-version", "6", "-strict-concurrency=complete",
               "-j", str(options.compiler_jobs),
               *map(str, owned.glob("*.swift")), *map(str, fixtures), "-o", str(exe)]
    report = dict(observed_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        base=BASE, flow_source="baseline" if options.baseline_flows else "working_tree",
        source_sha256={p:digest(b) for p,b in subject.items()},
        candidate_policy_sha256=digest(current[POLICY]), exact_writer_methods_unchanged=writer_parity,
        fixture_sha256={str(p.relative_to(ROOT)):digest(p.read_bytes()) for p in fixtures},
        manager_boundary_sha256=digest((ROOT / "Tests/HQ/search/IndexReadCompatibilityManagerBoundary.swift").read_bytes()),
        runner_sha256=digest(Path(__file__).read_bytes()),
        manifest_sha256={name:digest((ROOT/name).read_bytes()) for name in [
            "Tests/HQ/search/Fixtures/otzaria-miniTest10-v6-manifest.json",
            "Tests/HQ/search/Fixtures/actual-265-d5-build-info-20261120.json",
            "docs/hq-search/manifests/otzaria-search-manifest.json"]},
        generated_swift_sha256={p.name:digest(p.read_bytes()) for p in owned.glob("*.swift")},
        swift_version=subprocess.check_output([options.swiftc,"--version"],text=True,encoding="utf-8").strip(),
        production_qualification="CANDIDATE_EXACT_CONTRACT_REGISTRY_ENABLED",
        qualification_evidence_commit="df3b894cef2c8ea3dd50ccb31394635aa8fe4077",
        qualification_review_raw_windows_sha256="56fead3a78281ea6a1ba68d21806d5fa7505f2ba32b709fd03c1ce831c8fa3ca",
        qualification_review_git_lf_sha256="3ccd704a831f4a96ec06a691bdc17e7a8988168659bad766815018c9106983a1",
        boundaries=["Complete current and baseline policy with only type names renamed",
            "Exact original install/stream/promote/trusted-manifest/recovery/readiness/writer methods",
            "Real filesystem, Swift Codable and task cancellation",
            "Controlled profile/provider, FFI compatibility/count/open, raw fixture extractor, storage lock/capacity/backup metadata",
            "Flow boundary forwards to complete production validate; no candidate-admission override"],
        actual_old_index_runtime_executed=0, native_executed=0, owned_directory=str(owned))
    report["compile_timeout_seconds"] = options.compile_timeout_seconds
    report["compiler_jobs"] = options.compiler_jobs
    compile_result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", timeout=options.compile_timeout_seconds)
    (out / "compile.log").write_text(compile_result.stdout + compile_result.stderr, encoding="utf-8")
    report["compile_exit"] = compile_result.returncode
    code = compile_result.returncode
    if code:
        print(compile_result.stderr[-9000:])
    else:
        run = subprocess.run([str(exe), str(ROOT), str(owned / "state"), str(out / "cases.json")],
                             capture_output=True, text=True, encoding="utf-8", timeout=90)
        (out / "tests.log").write_text(run.stdout + run.stderr, encoding="utf-8")
        report["execute_exit"] = run.returncode
        code = run.returncode
        if (out / "cases.json").exists():
            report["cases"] = json.loads((out / "cases.json").read_text(encoding="utf-8"))
        print(run.stdout)
        print(run.stderr[-3000:])
    report["status"] = "PORTABLE_PASS_NOT_RUNTIME_QUALIFICATION" if code == 0 else "FAILED"
    (out / "RESULT.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status":report["status"],"counts":report.get("cases",{}).get("counts")}))
    return code

if __name__ == "__main__":
    raise SystemExit(main())
