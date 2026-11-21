#!/usr/bin/env python3
"""One real original Host journey; private seed, original matrix, bounded evidence."""
import base64
from contextlib import closing
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import runpy
import shutil
import sqlite3
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
SELECTOR = "HanlinLiveProviderAcceptanceTests/testOriginalLiveProviderUsesCanonicalCoreAndRevokesReadConsent"
MODEL = "gemini-2.5-flash-lite"
REVIEWED_SOURCE = "2818019c7dcecda953c74caa4f38823fb97cf70f"
ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/openai/"
BUNDLE = "com.davidpovarsky.chavrusatext"
PRIVATE_RELATIVE = Path("Library/Application Support/OtzariaHanlinLiveProviderAcceptance/provider.json")
WORK = ROOT / "build/hanlin-live-private"
OUT = ROOT / "build/hanlin-live-evidence"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    value = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for part in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(part)
    return value.hexdigest()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n")


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, timeout=90).decode().strip()


def evidence_identity(directory):
    require(directory.is_dir() and not directory.is_symlink(), "Invalid original evidence directory")
    rows = []
    for path in sorted(directory.rglob("*")):
        require(not path.is_symlink(), "Unexpected original evidence symlink")
        if path.is_file():
            rows.append([str(path.relative_to(directory)), path.stat().st_size, digest(path)])
    return {"directory_inode": directory.stat().st_ino, "files": len(rows),
            "content_sha256": hashlib.sha256(json.dumps(rows, separators=(",", ":")).encode()).hexdigest()}


def isolate_artifacts():
    artifacts = ROOT / "build/artifacts"
    receipt = {"run_id": os.environ["GITHUB_RUN_ID"], "run_attempt": os.environ["GITHUB_RUN_ATTEMPT"],
               "had_prior": artifacts.exists(), "prior_identity": evidence_identity(artifacts) if artifacts.exists() else None}
    # Commit ownership before either rename so cancellation can restore it.
    write(WORK / "artifact-isolation.json", receipt)
    if receipt["had_prior"]:
        artifacts.rename(WORK / "prior-artifacts")
    (artifacts / "runtime27").mkdir(parents=True)


def restore_artifacts():
    receipt_path = WORK / "artifact-isolation.json"
    if not receipt_path.exists():
        return
    receipt = json.loads(receipt_path.read_text())
    require(receipt["run_id"] == os.environ["GITHUB_RUN_ID"] and receipt["run_attempt"] == os.environ["GITHUB_RUN_ATTEMPT"],
            "Wrong workflow attempt for original evidence restoration")
    artifacts, prior = ROOT / "build/artifacts", WORK / "prior-artifacts"
    if prior.exists() or (not receipt["had_prior"] and artifacts.exists()):
        if artifacts.exists():
            require(not (WORK / "artifacts").exists(), "Preserve an existing private live result")
            artifacts.rename(WORK / "artifacts")
        if prior.exists():
            prior.rename(artifacts)
    require(not prior.exists(), "Original evidence directory remains displaced")
    if receipt["had_prior"]:
        require(evidence_identity(artifacts) == receipt["prior_identity"], "Original evidence bytes were not restored")
    receipt["restored"] = True
    write(receipt_path, receipt)


def source_context():
    head = git("rev-parse", "HEAD")
    require(head == os.environ["EXPECTED_CHECKOUT_SHA"], "Wrong immutable live checkout")
    for path in ["Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests"]:
        require(git("rev-parse", "HEAD:" + path) == git("rev-parse", REVIEWED_SOURCE + ":" + path),
                "Reviewed live application or test tree changed")
    build = json.loads((ROOT / "build/hq-stage2/result.json").read_text())
    require(build.get("status") == "SIMULATOR_BUILD_FOR_REAL_UI_PASS" and build.get("checkout_sha") == head,
            "No matching original app and original UI runner build")
    hq = runpy.run_path(str(ROOT / "Scripts/CI/hq-stage2-focused-apple.py"))
    hq["verify_actual_sources"](build)
    inputs = json.loads((ROOT / "Scripts/CI/hq-stage2-focused-apple.inputs.json").read_text())
    hq["prepare_original_hanlin"](inputs, build, verify_only=True)
    native = build["native_context"]
    require(digest(ROOT / "Maktabah.xcodeproj/project.pbxproj") == native["generated_project_sha256"],
            "Generated original project changed")
    require(digest(ROOT / "Maktabah.xcworkspace/contents.xcworkspacedata") == native["workspace_sha256"],
            "Original workspace changed")
    closure = {}
    paths = ["Scripts/CI", "Scripts/verify-otzaria-mini-parity.py", ".github/workflows", "tools",
             "Maktabah-iOSUITests", "docs/hq-integration/runtime27/R27_CASES.json"]
    rows = subprocess.check_output(["git", "ls-tree", "-r", "-z", "HEAD", "--", *paths], cwd=ROOT, timeout=90)
    for row in rows.split(b"\0"):
        if not row:
            continue
        meta, name = row.split(b"\t", 1)
        mode, kind, expected = meta.decode().split()
        require(kind == "blob", "Unexpected execution closure entry")
        path = ROOT / name.decode()
        raw = os.readlink(path).encode() if mode == "120000" and path.is_symlink() else path.read_bytes()
        actual = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
        require(actual == expected, "Dirty tracked live execution input")
        closure[name.decode()] = {"blob": actual, "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw)}
    require(bool(closure), "Empty source closure")
    products = ROOT / "build/DerivedData/Build/Products/Debug-iphonesimulator"
    bundles = [products / "Maktabah.app", products / "Maktabah-iOSUITests-Runner.app",
               products / "Maktabah-iOSUITests-Runner.app/PlugIns/Maktabah-iOSUITests.xctest"]
    binaries = {}
    for bundle in bundles:
        info = plistlib.loads((bundle / "Info.plist").read_bytes())
        executable = bundle / info["CFBundleExecutable"]
        binaries[str(executable.relative_to(ROOT))] = digest(executable)
    for path in (products / "Maktabah.app").rglob("*.dylib"):
        require(not path.is_symlink(), "Unexpected app code image symlink")
        binaries[str(path.relative_to(ROOT))] = digest(path)
    return {"checkout_sha": head, "reviewed_source_sha": REVIEWED_SOURCE, "application_source_sha": inputs["application_source_sha"],
            "application_trees": inputs["application_trees"], "original_build_status": build["status"],
            "generated_project_sha256": native["generated_project_sha256"],
            "workspace_sha256": native["workspace_sha256"], "execution_inputs": closure, "binaries": binaries}


def owned_application_root(udid):
    canonical = str(uuid.UUID(udid)).upper()
    require(canonical == udid, "Unexpected owned Simulator identity")
    return Path.home() / "Library/Developer/CoreSimulator/Devices" / canonical / "data/Containers/Data/Application"


def clean_private_input(udid):
    root = owned_application_root(udid)
    removed = 0
    if root.exists():
        require(not root.is_symlink(), "Owned application root is a symlink")
        files = list(root.glob("*/" + PRIVATE_RELATIVE.as_posix()))
        require(len(files) <= 4, "Unexpected private-input count on the owned device")
        for file in files:
            require(not file.is_symlink() and file.resolve().is_relative_to(root.resolve()),
                    "Private-input ownership changed")
            file.unlink()
            removed += 1
        require(not list(root.glob("*/" + PRIVATE_RELATIVE.as_posix())), "Private input remains")
    return removed


class LiveAcceptance:
    def __init__(self, key):
        require(20 <= len(key) <= 4096 and all(32 < ord(c) < 127 for c in key), "Live credential unavailable")
        self._key = key
        self._patterns = [key.encode(), base64.b64encode(key.encode())]
        self.nonce = str(uuid.uuid4()).upper()
        self.udid = None
        self.staged = False
        self.removed = False
        self.consumed = False
        self.redactions = 0
        self.witness = None
        self.database_relative = None
        self.database_sha256 = None

    def validate_selection(self, baseline, release_manifest, selection):
        require(not baseline and release_manifest is None and selection == [SELECTOR],
                "Live input may only accompany the one explicit original live selector")

    def redact_evidence(self, text):
        for pattern in self._patterns:
            value = pattern.decode()
            if value in text:
                self.redactions += 1
                text = text.replace(value, "<redacted-live-credential>")
        return text

    def stage(self, udid, container, label, selection):
        require(self.udid is None and label == "11" and selection == [SELECTOR], "Unexpected second live stage")
        root = owned_application_root(udid).resolve(strict=True)
        data = Path(container).resolve(strict=True)
        require(data.parent == root and data.is_dir() and not Path(container).is_symlink(), "Wrong owned app container")
        self.udid = udid
        write(WORK / "ownership.json", {"udid": udid, "run_id": os.environ["GITHUB_RUN_ID"],
              "run_attempt": os.environ["GITHUB_RUN_ATTEMPT"], "nonce": self.nonce, "private_relative": PRIVATE_RELATIVE.as_posix()})
        oracle = json.loads((ROOT / f"build/artifacts/runtime27/fixture-oracle-{label}.json").read_text())
        require(oracle["profileID"] == "miniTest10" and oracle["profileVersion"] == 6,
                "Live input requires the public original miniature fixture")
        database = Path(oracle["database_path"]).resolve(strict=True)
        require(database.is_relative_to(data) and digest(database) == oracle["database_sha256"], "Wrong installed fixture")
        self.database_relative = database.relative_to(data)
        self.database_sha256 = oracle["database_sha256"]
        selected = oracle["selected"]
        require(isinstance(selected["lineIndex"], int), "No original current fixture line")
        text_oracle = runpy.run_path(str(ROOT / "tools/otzaria_original_sql_oracle.py"))
        with closing(sqlite3.connect(database.as_uri() + "?mode=ro&immutable=1", uri=True)) as connection:
            decode = runpy.run_path(str(ROOT / "Scripts/verify-otzaria-mini-parity.py"))["decoder"](connection)
            rows = connection.execute("SELECT l.id,l.lineIndex,lc.content FROM line l JOIN line_content lc ON lc.id=l.id "
                                      "WHERE l.bookId=? ORDER BY (l.lineIndex=? ) DESC,l.lineIndex LIMIT 128",
                                      (selected["sourceBookId"], selected["lineIndex"]))
            query = None
            query_row = None
            for row in rows:
                text = text_oracle["display_text"](decode(row[2]))
                for terms in text_oracle["token_positions"](text):
                    candidates = sorted(term for term in terms if 3 <= len(term) <= 24 and term.isalpha())
                    if candidates:
                        query, query_row = candidates[0], row[:2]
                        break
                if query:
                    break
        require(query is not None and digest(database) == oracle["database_sha256"], "No unchanged public query source")
        write(WORK / "fixture-query.json", {"database_sha256": oracle["database_sha256"], "book_id": selected["sourceBookId"],
              "current_line_index": selected["lineIndex"], "query_line_id": query_row[0], "query_line_index": query_row[1],
              "query": query, "ui_observation_used": False, "database_unchanged": True})
        target = data / PRIVATE_RELATIVE
        target.parent.mkdir(mode=0o700, parents=True, exist_ok=False)
        descriptor = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump({"nonce": self.nonce, "apiKey": self._key, "model": MODEL, "endpoint": ENDPOINT}, stream)
        require(target.stat().st_mode & 0o777 == 0o600, "Wrong private input permissions")
        self.staged = True
        return {"TEST_RUNNER_OTZARIA_HANLIN_LIVE_PROVIDER_CASE": "1", "TEST_RUNNER_OTZARIA_HANLIN_LIVE_NONCE": self.nonce,
                "TEST_RUNNER_OTZARIA_HANLIN_LIVE_MODEL": MODEL, "TEST_RUNNER_OTZARIA_HANLIN_LIVE_QUERY": query,
                "TEST_RUNNER_OTZARIA_HANLIN_LIVE_SECTION": str(selected["lineIndex"])}

    def capture(self, udid, label):
        require(udid == self.udid and label == "11", "Wrong live witness device")
        root = owned_application_root(udid).resolve(strict=True)
        candidates = list(root.glob("*/Documents/otzaria-hanlin-live-" + self.nonce + ".json"))
        require(len(candidates) == 1, "The original native live witness did not complete")
        file = candidates[0]
        require(not file.is_symlink() and file.stat().st_size <= 1024 * 1024, "Invalid native witness file")
        raw = file.read_bytes()
        self.scan(raw)
        proof = json.loads(raw)
        actual_database = file.parent.parent / self.database_relative
        require(actual_database.is_file() and digest(actual_database) == self.database_sha256,
                "Original miniature library changed during the live read")
        require(proof.get("status") == "NATIVE_ASSERTIONS_COMPLETED" and proof.get("nonce") == self.nonce
                and proof.get("model") == MODEL and proof.get("nativeConsentGranted") is True
                and proof.get("nativeConsentRevoked") is True and proof.get("workspacePreserved") is True
                and proof.get("credentialTypedOrExported") is False and proof.get("nativeReaderReceipt"),
                "Incomplete original native journey")
        self.witness = proof
        (WORK / "native-witness.json").write_bytes(raw)
        write(WORK / "fixture-after.json", {"database_sha256": self.database_sha256, "database_unchanged": True,
              "actual_owned_container": str(file.parent.parent)})

    def cleanup(self, udid):
        if self.udid is None:
            return
        require(udid == self.udid, "Wrong live private-input cleanup identity")
        if self.removed:
            require(not list(owned_application_root(udid).glob("*/" + PRIVATE_RELATIVE.as_posix())),
                    "Private input reappeared after cleanup")
            return
        root_present = owned_application_root(udid).exists()
        count = clean_private_input(udid)
        self.consumed = self.staged and root_present and count == 0
        self.removed = True

    def scan(self, raw):
        require(not any(pattern in raw for pattern in self._patterns), "Credential detected; evidence publication refused")

    def admit(self, source, name):
        if not source.is_file():
            return False
        require(not source.is_symlink() and source.stat().st_size <= 32 * 1024 * 1024, "Invalid evidence admission")
        raw = source.read_bytes()
        self.scan(raw)
        (OUT / name).write_bytes(raw)
        return True


def prepare_selection():
    declaration = runpy.run_path(str(ROOT / "Scripts/CI/verify-faithful-xctest.py"))["validate_selections"]([SELECTOR])
    require(declaration["status"] == "DECLARATIONS_MATCH", "Live XCTest declaration missing")
    contract = {"cases": [{"case_id": SELECTOR, "device": "ipad11"}], "execution_case_ids": [SELECTOR],
                "execution_groups": [{"size": "11", "label": "11", "case_ids": [SELECTOR], "hid_comparison": False}],
                "diagnostic_only": True, "required_nonzero_cases": 1, "hid_comparison": False}
    runpy.run_path(str(ROOT / "Scripts/CI/runtime27.py"))["execution_groups"](contract)
    write(WORK / "selection.json", contract)
    write(WORK / "declarations.json", declaration)


def cleanup_owned_device():
    receipt = WORK / "ownership.json"
    if not receipt.exists():
        print("No live private input was staged")
        return 0
    owner = json.loads(receipt.read_text())
    require(owner["run_id"] == os.environ["GITHUB_RUN_ID"] and owner["run_attempt"] == os.environ["GITHUB_RUN_ATTEMPT"],
            "Wrong workflow attempt for private-input cleanup")
    errors = []
    try:
        clean_private_input(owner["udid"])
    except BaseException as error:
        errors.append({"step": "private_input", "error_kind": type(error).__name__})
    device = owned_application_root(owner["udid"]).parents[3]
    if device.exists():
        for name, command, timeout in [
            ("shutdown", [sys.executable, "Scripts/CI/shutdown-faithful-simulator.py", owner["udid"]], 300),
            ("delete", ["xcrun", "simctl", "delete", owner["udid"]], 120),
        ]:
            try:
                subprocess.run(command, check=True, capture_output=True, timeout=timeout)
            except BaseException as error:
                errors.append({"step": name, "error_kind": type(error).__name__})
    if device.exists():
        errors.append({"step": "verify_device_absent", "error_kind": "DeviceRemains"})
    if errors:
        print(json.dumps({"owned_cleanup": "FAIL", "errors": errors}))
        raise ValueError("Owned private/device cleanup did not fully succeed")
    print("Owned live private input and disposable device are absent")
    return 0


def emergency_cleanup():
    errors = []
    # An evidence-directory problem must never suppress private/device cleanup.
    for name, action in [("owned_private_device", cleanup_owned_device), ("original_evidence", restore_artifacts)]:
        try:
            action()
        except BaseException as error:
            errors.append({"step": name, "error_kind": type(error).__name__})
    print(json.dumps({"cleanup": "FAIL" if errors else "PASS", "errors": errors}))
    return 1 if errors else 0


def main():
    # No child process receives this step-only environment value, including Xcode.
    key = os.environ.pop("OTZARIA_HANLIN_LIVE_API_KEY", "")
    for name, value in list(os.environ.items()):
        if key and value == key:
            os.environ.pop(name)
    live = LiveAcceptance(key)
    key = None
    require(not WORK.exists() and not OUT.exists(), "Preserve an existing live attempt")
    WORK.mkdir(parents=True, mode=0o700)
    OUT.mkdir(parents=True, mode=0o700)
    report = {"status": "FAIL", "selector": SELECTOR, "model": MODEL, "endpoint": ENDPOINT,
              "native116_acceptance": False, "release114_acceptance": False, "verified_completed_provider_conversations": 0}
    artifacts = ROOT / "build/artifacts"
    matrix_code = None
    phase = "SOURCE_BEFORE"
    try:
        before = source_context()
        write(WORK / "source-before.json", before)
        prepare_selection()
        require(not os.environ.get("FAITHFUL_RUNTIME27_RELEASE_MANIFEST") and not os.environ.get("FAITHFUL_RELEASE_XCTESTRUN"),
                "Live workflow cannot import a full Release continuation")
        isolate_artifacts()
        os.environ["VALIDATING_BASELINE"] = "false"
        os.environ["FAITHFUL_RUNTIME27_MANIFEST"] = str(WORK / "selection.json")
        os.environ.pop("FAITHFUL_DIAGNOSTIC_CASES", None)
        phase = "NATIVE_MATRIX"
        try:
            matrix_code = runpy.run_path(str(ROOT / "Scripts/CI/run-faithful-ipad-matrix.py"))["main"](live_provider=live)
        except SystemExit as error:
            matrix_code = error.code if isinstance(error.code, int) else 1
        phase = "SOURCE_AFTER"
        after = source_context()
        write(WORK / "source-after.json", after)
        require(before == after, "Original source or built code changed during live execution")
        matrix = json.loads((artifacts / "faithful-ipad-matrix.json").read_text())
        strict = json.loads((artifacts / "runtime27/verified-11.json").read_text())
        device = matrix["devices"]
        require(matrix_code == 0 and len(device) == 1 and device[0]["status"] == "EXECUTED_PASS"
                and device[0].get("ownedSimulatorCleanup") == "PASS" and strict.get("status") == "EXECUTED_PASS"
                and strict.get("required_ui_cases") == [SELECTOR] and strict.get("executed_total") == 1
                and strict.get("skipped") == 0 and strict.get("failed") == 0
                and live.removed and live.consumed and live.witness is not None and live.redactions == 0,
                "Original live acceptance did not fully pass")
        report.update(status="LIVE_ORIGINAL_HOST_NATIVE_PASS", verified_completed_provider_conversations=1)
    except BaseException as error:
        report.update(failure_phase=phase, error_kind=type(error).__name__, matrix_exit_code=matrix_code)
    finally:
        for name, action in [("private_input", lambda: live.cleanup(live.udid) if live.udid and not live.removed else None),
                             ("original_evidence", restore_artifacts)]:
            try:
                action()
                if name == "original_evidence":
                    report["prior_artifacts_restored"] = True
            except BaseException as error:
                report.update(status="FAIL", cleanup_or_restoration_error={"step": name, "error_kind": type(error).__name__})
        phase = "EVIDENCE_ADMISSION"
        try:
            raw = WORK / "artifacts"
            for name in ["source-before.json", "source-after.json", "selection.json", "declarations.json",
                         "ownership.json", "artifact-isolation.json", "fixture-query.json", "fixture-after.json", "native-witness.json"]:
                live.admit(WORK / name, name)
            live.admit(ROOT / "build/hq-stage2/result.json", "original-build-result.json")
            for name in ["faithful-ipad-matrix.json", "test-simulator-11.log", "test-case-execution-11.json"]:
                live.admit(raw / name, name)
            for name in ["verified-11.json", "verified-11.summary.json", "verified-11.tests.json", "fixture-oracle-11.json"]:
                live.admit(raw / "runtime27" / name, name)
            result = raw / "result-11.xcresult"
            if result.is_dir():
                verified_path = raw / "runtime27/verified-11.json"
                verified = json.loads(verified_path.read_text()) if verified_path.is_file() else {}
                identifier = verified.get("cases", {}).get(SELECTOR, {}).get("identifier") or SELECTOR + "()"
                details = subprocess.run(["xcrun", "xcresulttool", "get", "test-results", "test-details", "--path", str(result),
                                          "--test-id", identifier], capture_output=True, timeout=120)
                if details.returncode == 0:
                    live.scan(details.stdout)
                    write(WORK / "original-test-details.json", json.loads(details.stdout))
                    live.admit(WORK / "original-test-details.json", "original-test-details.json")
                else:
                    report.update(status="FAIL", test_details_exit_code=details.returncode)
            report.update(private_input_staged=live.staged, private_input_consumed=live.consumed,
                          private_input_removed=live.removed, log_redactions=live.redactions,
                          credential_in_test_arguments=False, credential_in_child_environment=False,
                          raw_container_or_result_bundle_published=False)
            write(OUT / "result.json", report)
            files = {}
            for path in sorted(OUT.iterdir()):
                require(path.is_file() and not path.is_symlink(), "Unexpected upload member")
                live.scan(path.read_bytes())
                files[path.name] = {"sha256": digest(path), "bytes": path.stat().st_size}
            write(OUT / "admission.json", {"status": "SCANNED_ALLOWLIST_ONLY", "files": files,
                  "private_input_removed": live.removed, "provider_file_excluded": True,
                  "raw_xcresult_and_attachments_excluded": True, "raw_video_excluded": True})
            live.scan((OUT / "admission.json").read_bytes())
        except BaseException as error:
            # Never leave a partially admitted directory for upload after a leak/scan failure.
            shutil.rmtree(OUT)
            report.update(status="FAIL", failure_phase=phase, error_kind=type(error).__name__)
        live._key = None
        live._patterns.clear()
    print(json.dumps({"status": report["status"], "selector": SELECTOR, "model": MODEL,
                      "failure_phase": report.get("failure_phase"), "artifact_admitted": (OUT / "admission.json").is_file()}))
    return 0 if report["status"] == "LIVE_ORIGINAL_HOST_NATIVE_PASS" else 1


if __name__ == "__main__":
    os.chdir(ROOT)
    if sys.argv[1:] == ["cleanup"]:
        raise SystemExit(emergency_cleanup())
    require(not sys.argv[1:], "Unexpected live-runner arguments")
    raise SystemExit(main())
