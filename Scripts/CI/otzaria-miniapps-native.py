#!/usr/bin/env python3
"""One actual Otzaria editor -> Hanlin TextStudio -> original saved-note journey."""
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
import tarfile
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/artifacts/miniapps-native"
PRODUCER_DIR = ROOT / "build/miniapps-producer"
INPUTS = ROOT / "Scripts/CI/otzaria-miniapps-native.inputs.json"
BUILD_INPUTS = ROOT / "Scripts/CI/hq-stage2-focused-apple.inputs.json"
SELECTOR = "MiniAppsAnnotationAcceptanceTests/testOriginalNoteReturnsTextFromActualMiniAppsAndPersistsAfterRelaunch"
GROUPS = [{"label": "11-reader", "size": "11", "hid_comparison": False, "case_ids": [SELECTOR]}]
BUNDLE = "com.davidpovarsky.chavrusatext"
PRODUCER = "com.itorah.hanlinminiapps"
GROUP = "group.com.itorah.shared"
MANIFEST = OUT / "selection.json"
resolve_native_container = runpy.run_path(str(ROOT / "Scripts/CI/miniapps-simulator-containers.py"))["resolve_container"]


def require(value, message):
    if not value:
        raise RuntimeError(message)


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n")


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def capture(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True, timeout=120).strip()


def git(*args):
    return capture("git", *args)


def configuration():
    value = json.loads(INPUTS.read_text())
    require(re.fullmatch(r"[a-f0-9]{40}", value["producer_source_sha"]), "Producer source must be frozen")
    require(value["producer_repository"] == "davidpovarsky/hanlin-ai", "Unexpected producer source repository")
    origin = value.get("producer_origin", "github-actions")
    require(origin in ("github-actions", "local-mac"), "Unsupported producer execution origin")
    if origin == "github-actions":
        require(type(value["producer_run_id"]) is int and value["producer_run_id"] > 0, "Producer run must be frozen")
        require(value["producer_artifact_name"] == "app-split-" + str(value["producer_run_id"]),
                "Unexpected producer artifact identity")
        require("local_producer_manifest" not in value, "A GitHub producer cannot silently substitute a local product")
    else:
        require(value.get("producer_run_id") is None and value.get("producer_artifact_name") is None,
                "A local producer must not invent GitHub run or artifact identities")
        local = value.get("local_producer_manifest")
        require(isinstance(local, dict) and set(local) == {"path", "sha256"}
                and isinstance(local["path"], str) and Path(local["path"]).is_absolute()
                and isinstance(local["sha256"], str) and re.fullmatch(r"[a-f0-9]{64}", local["sha256"]),
                "Local producer requires its exact manifest path and reviewed SHA256")
    return value


def source_context():
    config = configuration()
    inputs = json.loads(BUILD_INPUTS.read_text())
    source = inputs["application_source_sha"]
    require(re.fullmatch(r"[a-f0-9]{40}", source), "Application source must be frozen")
    head = git("rev-parse", "HEAD")
    require(head == os.environ["EXPECTED_CHECKOUT_SHA"], "Wrong immutable native checkout")
    subprocess.run(["git", "merge-base", "--is-ancestor", source, head], cwd=ROOT, check=True, timeout=90)
    trees = {p: git("rev-parse", "HEAD:" + p) for p in
             ["Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests"]}
    require(all(value == git("rev-parse", source + ":" + path) for path, value in trees.items()),
            "Original consumer application or test changed after source pin")
    require(all(inputs["application_trees"][p] == trees[p] for p in inputs["application_trees"]),
            "Original native build pins do not bind this source")
    require(inputs["hanlin_gitlink"] == config["producer_source_sha"], "Consumer SDK and actual producer differ")
    original = runpy.run_path(str(ROOT / "Scripts/CI/completion-focused-native.py"))
    return {"checkout_sha": head, "application_source_sha": source, "application_trees": trees,
            "producer_inputs": config,
            "original_case_catalog_sha256": digest(ROOT / "docs/hq-integration/runtime27/R27_CASES.json"),
            "execution_inputs": original["exact_working_inputs"](["Scripts/CI", ".github/workflows", "Maktabah-iOSUITests", "tools"])}


def prepare():
    require(not (OUT / "source-before.json").exists(), "Existing native evidence must not be overwritten")
    context = source_context()
    contract = json.loads((ROOT / "docs/hq-integration/runtime27/R27_CASES.json").read_text())
    if SELECTOR not in {row["case_id"] for row in contract["cases"] + contract.get("supplemental_cases", [])}:
        contract.setdefault("supplemental_cases", []).append({
            "case_id": SELECTOR, "device": "ipad11", "status": "NOT_RUN",
            "oracle": "Original reader selection and note toolbar, actual Hanlin TextStudio warm/cold callbacks, three atomic receipts, linked-note anchors and unchanged source corpus"})
    for row in contract["cases"] + contract.get("supplemental_cases", []):
        if row["case_id"] == SELECTOR:
            row["oracle"] = "Original reader selection and note toolbar; actual TextStudio warm/cold callbacks; three atomic receipts, linked-note anchors and unchanged corpus"
    contract.update(source_test_commit=context["application_source_sha"],
                    app_source=context["application_source_sha"],
                    application_source_sha=context["application_source_sha"],
                    execution_case_ids=[SELECTOR], execution_groups=GROUPS, required_nonzero_cases=1,
                    native_cases_executed=0, expected_per_device={"ipad11": 1, "ipad13": 0, "iphone": 0},
                    diagnostic_only=True, hid_comparison=False,
                    scope="Actual two-app MiniApps consumer acceptance only; previously accepted unrelated suites are not replayed")
    runpy.run_path(str(ROOT / "Scripts/CI/runtime27.py"))["execution_groups"](contract)
    declarations = runpy.run_path(str(ROOT / "Scripts/CI/verify-faithful-xctest.py"))["validate_selections"](
        [SELECTOR], ROOT / "Maktabah-iOSUITests")
    require(declarations["status"] == "DECLARATIONS_MATCH", "The selected original XCTest is absent")
    write(OUT / "declarations.json", declarations)
    write(MANIFEST, contract)
    write(OUT / "source-before.json", context)


def restore_producer():
    config = configuration()
    if config.get("producer_origin") == "local-mac":
        helper = runpy.run_path(str(ROOT / "Scripts/CI/miniapps-local-producer.py"))
        return helper["restore"](config, PRODUCER_DIR, OUT, ROOT / "Vendor/HanlinSDK", PRODUCER)
    repository = config["producer_repository"]
    run_id = str(config["producer_run_id"])
    run = json.loads(capture("gh", "api", f"repos/{repository}/actions/runs/{run_id}"))
    require(run["head_sha"] == config["producer_source_sha"], "Actual producer run has a different source")
    destination = PRODUCER_DIR
    destination.mkdir(parents=True, exist_ok=True)
    deadline = time.monotonic() + 1800
    while True:
        artifacts = json.loads(capture("gh", "api", f"repos/{repository}/actions/runs/{run_id}/artifacts?per_page=100"))
        matches = [a for a in artifacts["artifacts"] if a["name"] == config["producer_artifact_name"] and not a["expired"]]
        if matches:
            require(len(matches) == 1, "Ambiguous actual producer artifact")
            break
        run = json.loads(capture("gh", "api", f"repos/{repository}/actions/runs/{run_id}"))
        require(run["status"] != "completed" and time.monotonic() < deadline,
                "Actual producer completed without the required simulator product")
        time.sleep(15)
    subprocess.run(["gh", "run", "download", run_id, "--repo", repository,
                    "--name", config["producer_artifact_name"], "--dir", str(destination)], cwd=ROOT, check=True, timeout=300)
    manifests = list(destination.rglob("producer-manifest.json"))
    require(len(manifests) == 1, "Actual producer artifact must contain one manifest")
    manifest_path = manifests[0]
    manifest = json.loads(manifest_path.read_text())
    require(manifest["schema_version"] == 1
            and manifest["producer_sha"] == config["producer_source_sha"]
            and str(manifest["run_id"]) == run_id and manifest["bundle_id"] == PRODUCER,
            "Actual producer manifest has the wrong identity")
    require(manifest["build_status"] == "EXECUTED_PASS", "No successful actual producer app build")
    require(manifest["app_relative_path"] == "HanlinMiniApps.app"
            and manifest["archive_name"] == "HanlinMiniApps-simulator.zip", "Unexpected simulator archive layout")
    archive = manifest_path.parent / manifest["archive_name"]
    require(digest(archive) == manifest["archive_sha256"], "Producer archive bytes do not match its manifest")
    subprocess.run(["ditto", "-x", "-k", str(archive), str(destination)], check=True, timeout=180)
    app = destination / manifest["app_relative_path"]
    info = plistlib.loads((app / "Info.plist").read_bytes())
    require(info["CFBundleIdentifier"] == PRODUCER
            and info["CFBundleExecutable"] == manifest["executable_name"], "Extracted app identity differs")
    require(digest(app / info["CFBundleExecutable"]) == manifest["executable_sha256"], "Producer executable changed")
    write(OUT / "producer-admission.json", {
        "status": "EXACT_ACTUAL_SIMULATOR_PRODUCT_RESTORED", "artifact_id": matches[0]["id"],
        "artifact_name": matches[0]["name"], "producer_manifest": manifest,
        "producer_native_acceptance_status": manifest["native_acceptance_status"],
        "note": "This consumer lane never promotes or replaces the separate producer native acceptance or physical signing result."})


def binaries():
    products = ROOT / "build/DerivedData/Build/Products/Debug-iphonesimulator"
    result = {}
    for bundle in [products / "Maktabah.app", products / "Maktabah-iOSUITests-Runner.app",
                   products / "Maktabah-iOSUITests-Runner.app/PlugIns/Maktabah-iOSUITests.xctest"]:
        info = plistlib.loads((bundle / "Info.plist").read_bytes())
        for path in [bundle / "Info.plist", bundle / info["CFBundleExecutable"], *sorted(bundle.glob("*.dylib"))]:
            result[str(path.relative_to(ROOT))] = digest(path)
    return result


def export_built_products():
    """Retain the complete real products before a Simulator infrastructure failure."""
    build_path = ROOT / "build/hq-stage2/result.json"
    build = json.loads(build_path.read_text())
    require(build["status"] == "SIMULATOR_BUILD_FOR_REAL_UI_PASS"
            and build["checkout_sha"] == os.environ["EXPECTED_CHECKOUT_SHA"],
            "Only the actual successful immutable native build can be exported")
    products = ROOT / "build/DerivedData/Build/Products"
    primary_roots = [products / "Debug-iphonesimulator/Maktabah.app",
                     products / "Debug-iphonesimulator/Maktabah-iOSUITests-Runner.app"]
    test_runs = sorted(products.glob("*.xctestrun"))
    require(all(path.is_dir() for path in primary_roots) and test_runs, "Original native products are incomplete")
    roots = [*primary_roots, *test_runs]
    referenced_products, platform_references = [], []
    def include_product(path):
        path = Path(path)
        require(path.is_absolute(), "Original native product reference is not absolute")
        resolved = path.resolve(strict=True)
        require(path.is_relative_to(products) and resolved.is_relative_to(products) and resolved.exists(),
                "An original native product reference is missing or outside Products")
        # Keep every lexical symlink used by the unchanged xctestrun path, as
        # well as its resolved product. Resolving first would lose alias roots.
        candidates = [resolved]
        current = products
        for part in path.relative_to(products).parts:
            if part == "..":
                current = current.parent
                continue
            current = current / part
            require(current.is_relative_to(products),
                    "An original native product alias is outside Products")
            if current.is_symlink():
                candidates.append(current)
                current = current.resolve(strict=True)
        for candidate in candidates:
            if any(candidate == root or candidate.is_relative_to(root) for root in roots):
                continue
            parts = candidate.relative_to(products).parts
            # Include the complete referenced framework/bundle, not only one leaf.
            whole = products.joinpath(*parts[:2]) if len(parts) > 1 else candidate
            roots[:] = [root for root in roots if not root.is_relative_to(whole)]
            roots.append(whole)

    def reference_path(value, host):
        if value.startswith(("__PLATFORMS__/", "__DEVELOPER_DIR__/")):
            platform_references.append(value)
            return None
        if "__TESTHOST__" in value:
            require(host is not None, "Original test-host placeholder has no host")
            value = value.replace("__TESTHOST__", str(host))
        value = value.replace("__TESTROOT__", str(products))
        require(re.search(r"__[A-Z][A-Z0-9_]*__", value) is None, "Unresolved original XCTest product placeholder")
        path = Path(value)
        require(path.is_absolute(), "Original XCTest product reference is not absolute")
        return path

    product_keys = {"TestBundlePath", "TestHostPath", "UITargetAppPath",
                    "DependentProductPaths", "ProductPath"}
    def collect_references(value, host=None):
        if isinstance(value, dict):
            if isinstance(value.get("TestHostPath"), str):
                host = reference_path(value["TestHostPath"], host)
            for key, item in value.items():
                if key in product_keys:
                    for raw in item if isinstance(item, list) else [item]:
                        if isinstance(raw, str):
                            path = reference_path(raw, host)
                            if path is not None:
                                include_product(path)
                                referenced_products.append(path.relative_to(products).as_posix())
                else:
                    collect_references(item, host)
        elif isinstance(value, list):
            for item in value:
                collect_references(item, host)
    for path in test_runs:
        collect_references(plistlib.loads(path.read_bytes()))

    visited = set()
    while True:
        pending = [root for root in roots if root not in visited]
        if not pending:
            break
        require(len(roots) < 128, "Unexpectedly large native product reference closure")
        for top in pending:
            visited.add(top)
            for path in [top, *sorted(top.rglob("*"))] if top.is_dir() and not top.is_symlink() else [top]:
                if path.is_symlink():
                    require(not Path(os.readlink(path)).is_absolute(),
                            "Native product has a nonportable absolute symlink")
                    include_product(path.parent / os.readlink(path))
    roots.sort()
    entries = {}
    for top in roots:
        for path in [top, *sorted(top.rglob("*"))] if top.is_dir() and not top.is_symlink() else [top]:
            relative = path.relative_to(products).as_posix()
            if path.is_symlink():
                require(path.resolve(strict=True).is_relative_to(products.resolve()),
                        "Native product symlink leaves the exported product root")
                entries[relative] = {"kind": "symlink", "target": os.readlink(path)}
            elif path.is_file():
                entries[relative] = {"kind": "file", "bytes": path.stat().st_size,
                                     "mode": path.stat().st_mode & 0o777, "sha256": digest(path)}
            elif path.is_dir():
                entries[relative] = {"kind": "directory", "mode": path.stat().st_mode & 0o777}
            else:
                raise RuntimeError("Unexpected native product file type")
    archive = OUT / "Maktabah-MiniApps-native-products.tar.gz"
    require(not archive.exists(), "An earlier authentic product archive must not be overwritten")
    with tarfile.open(archive, "w:gz", compresslevel=1) as output:
        for path in roots:
            output.add(path, arcname=path.relative_to(products).as_posix(), recursive=True)
    write(OUT / "native-products-manifest.json", {
        "schema_version": 1, "status": "ACTUAL_BUILT_SIMULATOR_PRODUCTS_EXPORTED",
        "checkout_sha": build["checkout_sha"], "application_source_sha": build["application_source_sha"],
        "run_id": os.environ.get("GITHUB_RUN_ID"), "hanlin_gitlink": build["hanlin_gitlink"],
        "application_trees": build["application_trees"], "ui_test_tree": git("rev-parse", "HEAD:Maktabah-iOSUITests"),
        "build_status": build["status"], "build_receipt_sha256": digest(build_path),
        "xcode": build["xcode"], "swift": build["swift"], "sdk_version": build["sdk_version"],
        "archive_name": archive.name, "archive_bytes": archive.stat().st_size, "archive_sha256": digest(archive),
        "product_root": "build/DerivedData/Build/Products", "files": entries,
        "original_xctestrun": [path.relative_to(products).as_posix() for path in test_runs],
        "exported_product_roots": [path.relative_to(products).as_posix() for path in roots],
        "original_test_product_references": sorted(set(referenced_products)),
        "xcode_platform_provided_references": sorted(set(platform_references)),
        "binary_identity": binaries(), "native_ui_acceptance": "NOT_RUN_AT_EXPORT",
        "physical_signing_status": "NOT_VALIDATED_BY_SIMULATOR"})
    print("Retained original app and UI test products with complete file and archive hashes", flush=True)


class ActualMiniAppsProducer:
    def __init__(self):
        self.udid = None
        self.group = None
        self.corpus_group = None
        self.captured = False
        self.video = None
        self.video_log = None
        self.state = {"status": "NOT_REACHED", "fixture_producer": False, "synthetic_results_written": False}

    def validate_selection(self, baseline, release_manifest, selection):
        require(not baseline and release_manifest is None and selection == [SELECTOR], "Wrong native case selection")

    def stage(self, udid, container, label, selection):
        require(self.udid is None and label == "11-reader" and selection == [SELECTOR], "Wrong owned simulator scope")
        self.udid = udid
        producer = PRODUCER_DIR / "HanlinMiniApps.app"
        require((OUT / "producer-admission.json").is_file(), "Actual producer product was not admitted")
        subprocess.run(["xcrun", "simctl", "install", udid, str(producer)], check=True, timeout=180)
        subprocess.run(["xcrun", "simctl", "launch", udid, PRODUCER], check=True, timeout=60)
        consumer_group = resolve_native_container(udid, BUNDLE, GROUP)
        producer_group = resolve_native_container(udid, PRODUCER, GROUP)
        require(Path(consumer_group).resolve() == Path(producer_group).resolve(),
                "The two installed original apps do not resolve the same App Group")
        self.group = Path(consumer_group).resolve()
        self.corpus_group = resolve_native_container(udid, BUNDLE, "group.com.davidpovarsky.itorah").resolve()
        corpus_profile = json.loads((ROOT / "Source/Otzaria/DataProfiles/miniTest10.profile.json").read_text())
        self.state.update(status="ACTUAL_PRODUCER_INSTALLED", udid=udid, group=str(self.group),
                          consumer_bundle=BUNDLE, producer_bundle=PRODUCER, shared_group_identifier=GROUP,
                          original_corpus_group=str(self.corpus_group))
        write(OUT / "actual-two-app-stage.json", self.state)
        self.video_log = (OUT / "native-video.log").open("w")
        self.video = subprocess.Popen(["xcrun", "simctl", "io", udid, "recordVideo", str(OUT / "actual-two-app-ipad.mp4")],
                                      stdout=self.video_log, stderr=subprocess.STDOUT)
        return {"TEST_RUNNER_MINIAPPS_NATIVE_SHARED_GROUP": str(self.group),
                "TEST_RUNNER_MINIAPPS_NATIVE_PRODUCER_BUNDLE": PRODUCER,
                "TEST_RUNNER_MINIAPPS_NATIVE_CORPUS_GROUP": str(self.corpus_group),
                "TEST_RUNNER_MINIAPPS_NATIVE_CORPUS_SHA256": corpus_profile["sourceDatabase"]["databaseSHA256"]}

    def redact_evidence(self, line):
        return line

    def capture(self, udid, label):
        require(udid == self.udid and label == "11-reader", "Wrong producer evidence simulator")
        if self.captured:
            return
        self.captured = True
        if self.video is not None:
            self.video.terminate()
            try:
                self.video.wait(timeout=30)
            except subprocess.TimeoutExpired:
                self.video.kill()
                self.video.wait(timeout=10)
            self.video_log.close()
        report = {"status": "INCOMPLETE", "records": [], "fixture_producer": False, "synthetic_results_written": False}
        try:
            for path in sorted((self.group / "MiniAppsBridge/v1/requests").glob("*.json")):
                record = json.loads(path.read_text())
                request = record["request"]
                if request["source"]["appID"] != BUNDLE:
                    continue
                document = json.loads(request["source"]["metadata"]["otzaria.annotation.v1"])
                database = Path(document["profile"])
                require(database.is_file(), "Original request annotation database is unavailable")
                connection = sqlite3.connect(database.as_uri() + "?mode=ro", uri=True)
                try:
                    rows = connection.execute(
                        "SELECT r.annotation_id,r.annotation_uuid,a.ckRecordId,a.note,r.result_json,"
                        "a.bkId,a.contentId,a.startIndex,a.length,a.context "
                        "FROM miniapps_result_receipts r JOIN annotations a ON a.id=r.annotation_id "
                        "WHERE r.request_id=?", (request["id"],)).fetchall()
                finally:
                    connection.close()
                result = record.get("result") or {}
                text = "\n".join(item["text"] for item in result.get("items", []) if item.get("text") is not None)
                draft = document["draftNote"]
                selection = document.get("selection")
                encoded = draft.encode("utf-16-le")
                position = ((selection["location"] + selection["length"]) * 2 if selection else len(encoded))
                require(0 <= position <= len(encoded), "Original capture has an invalid UTF-16 insertion")
                expected = (encoded[:position] + text.encode("utf-16-le") + encoded[position:]).decode("utf-16-le")
                verified = (record["acknowledged"] is True and result.get("status") == "success"
                            and result.get("operation") == "insert" and len(rows) == 1
                            and (rows[0][0] > 0 if document["isReaderSelection"] else rows[0][0] == document["annotationID"])
                            and rows[0][1] == rows[0][2] == document["annotationUUID"]
                            and rows[0][5:10] == (document["bookID"], document["contentID"],
                                document["rangeLocation"], document["rangeLength"], document["context"])
                            and json.loads(rows[0][4]) == result)
                report["records"].append({"shared_record": record, "original_receipt_rows": rows,
                                         "expected_note_after_this_result": expected,
                                         "same_original_annotation_verified": verified})
            records = report["records"]
            require(len(records) == 3 and all(r["same_original_annotation_verified"] for r in records),
                    "Expected editor warm/cold plus reader-selection results with three original atomic receipts")
            editor_records = [r for r in records if r["shared_record"]["request"]["source"].get("kind") == "annotation"]
            reader_records = [r for r in records if r["shared_record"]["request"]["source"].get("kind") == "reader"]
            require(len(editor_records) == 2 and len(reader_records) == 1, "Reader and editor entry paths must both execute")
            warm = [r for r in editor_records if r["shared_record"]["request"]["source"].get("documentText") == ""]
            require(len(warm) == 1, "Expected one original blank-note warm invocation")
            warm = warm[0]
            cold = next(r for r in editor_records if r is not warm)
            require(cold["shared_record"]["request"]["source"]["documentText"] == warm["expected_note_after_this_result"],
                    "Cold invocation did not capture the actually saved warm result")
            warm_text = warm["shared_record"]["result"]["items"][0]["text"]
            cold_text = cold["shared_record"]["result"]["items"][0]["text"]
            require(warm_text.startswith("MiniApps original note שלום ") and cold_text.startswith("MiniApps cold note שלום "),
                    "Both original editor invocations must return their actual typed text")
            identities = {tuple(r["original_receipt_rows"][0][:3]) for r in editor_records}
            require(len(identities) == 1 and all(r["original_receipt_rows"][0][3] == cold["expected_note_after_this_result"]
                                               for r in editor_records),
                    "Both editor callbacks must resolve to the same final original annotation row")
            reader = reader_records[0]
            request = reader["shared_record"]["request"]
            document = json.loads(request["source"]["metadata"]["otzaria.annotation.v1"])
            source_selection = request["source"].get("selection")
            require(document["isReaderSelection"] and document.get("annotationID") is None
                    and source_selection and source_selection["length"] > 0,
                    "Reader result must originate in an actual nonempty source selection")
            encoded = request["source"]["documentText"].encode("utf-16-le")
            begin = source_selection["location"] * 2
            end = begin + source_selection["length"] * 2
            require(0 <= begin < end <= len(encoded)
                    and encoded[begin:end].decode("utf-16-le") == source_selection["text"]
                    and "\n".join(item["text"] for item in request["inputs"]) == source_selection["text"],
                    "Actual reader selection and shared input do not match the original source")
            row = reader["original_receipt_rows"][0]
            require(tuple(row[:3]) not in identities and row[3] == reader["expected_note_after_this_result"]
                    and row[3].startswith("MiniApps reader note שלום "),
                    "Reader output must create its own original source-linked annotation")
            profile = json.loads((ROOT / "Source/Otzaria/DataProfiles/miniTest10.profile.json").read_text())
            corpus = []
            for path in self.corpus_group.rglob("seforim.db"):
                manifest_path = path.with_name("seforim-installation.json")
                if manifest_path.is_file():
                    manifest = json.loads(manifest_path.read_text())
                    if manifest.get("profileID", manifest.get("effectiveProfileID")) == "miniTest10":
                        corpus.append(path)
            require(len(corpus) == 1, "Expected exactly the installed original miniTest10 corpus")
            after_hash = digest(corpus[0])
            require(after_hash == profile["sourceDatabase"]["databaseSHA256"],
                    "Reader MiniApps roundtrip changed the original corpus bytes")
            report["source_corpus"] = {"profile": "miniTest10", "path": str(corpus[0]),
                "expected_sha256": profile["sourceDatabase"]["databaseSHA256"], "actual_after_sha256": after_hash,
                "before_after_equal": "ASSERTED_BY_ACTUAL_XCTEST", "status": "ORIGINAL_CORPUS_BYTES_UNCHANGED"}
            report["actual_callbacks"] = 3
            report["actual_reader_selection_to_picker"] = "ASSERTED_AND_CAPTURED_BY_ACTUAL_XCTEST"
            report["cold_callback_without_manual_launch"] = "ASSERTED_BY_ACTUAL_XCTEST"
            report["status"] = "ACTUAL_SHARED_RECORD_AND_ORIGINAL_SQLITE_RECEIPT_PASS"
        except Exception as error:
            report["error"] = type(error).__name__ + ": " + str(error)
        write(OUT / "native-wire-evidence.json", report)
        result = ROOT / "build/artifacts/result-11-reader.xcresult"
        if result.is_dir():
            subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(result),
                            "--output-path", str(ROOT / "build/artifacts/visual-miniapps")], check=True, timeout=180)

    def cleanup(self, udid):
        if self.udid is not None:
            self.capture(udid, "11-reader")


def execute():
    require(source_context() == json.loads((OUT / "source-before.json").read_text()), "Source changed before native execution")
    build = json.loads((ROOT / "build/hq-stage2/result.json").read_text())
    require(build["status"] == "SIMULATOR_BUILD_FOR_REAL_UI_PASS", "Original app and UI runner did not build")
    write(OUT / "built-binaries.json", binaries())
    driver = runpy.run_path(str(ROOT / "Scripts/CI/runtime27.py"))
    controller = driver["runtime27_interruption"].InterruptController().install()
    try:
        return driver["run_logged"]([sys.executable, "Scripts/CI/otzaria-miniapps-native.py", "matrix"],
                                    "miniapps-two-app-matrix.log", 7200, interrupt_controller=controller)
    finally:
        controller.restore()


def matrix():
    require(source_context() == json.loads((OUT / "source-before.json").read_text()), "Source changed before original matrix")
    require(not os.environ.get("FAITHFUL_RUNTIME27_RELEASE_MANIFEST") and not os.environ.get("FAITHFUL_DIAGNOSTIC_CASES"),
            "The MiniApps lane cannot combine unrelated native suites")
    os.environ["OTZARIA_MINIAPPS_NATIVE_CONTAINER_RECOVERY"] = "1"
    os.environ["VALIDATING_BASELINE"] = "false"
    os.environ["FAITHFUL_RUNTIME27_MANIFEST"] = str(MANIFEST)
    return runpy.run_path(str(ROOT / "Scripts/CI/run-faithful-ipad-matrix.py"))["main"](live_provider=ActualMiniAppsProducer())


def collect():
    report = {"status": "FAILED", "scope": "ACTUAL_TWO_APP_CONSUMER_NATIVE_ONLY",
              "required_case_ids": [SELECTOR], "full_native116_acceptance": False,
              "physical_signing_status": "NOT_TESTED_BY_SIMULATOR", "synthetic_results_written": False}
    try:
        context = source_context()
        report.update(context)
        require(context == json.loads((OUT / "source-before.json").read_text()), "Qualification source changed")
        build = json.loads((ROOT / "build/hq-stage2/result.json").read_text())
        require(build["status"] == "SIMULATOR_BUILD_FOR_REAL_UI_PASS" and build["checkout_sha"] == context["checkout_sha"],
                "No matching original app and UI runner build")
        require(binaries() == json.loads((OUT / "built-binaries.json").read_text()), "Actual native code images changed")
        info = ROOT / "build/DerivedData/Build/Products/Debug-iphonesimulator/Maktabah.app/Info.plist"
        require(build.get("simulator_embedded_data_profile") == "miniTest10"
                and digest(info) == build.get("built_app_info_sha256")
                and plistlib.loads(info.read_bytes()).get("OtzariaDefaultDataProfile") == "miniTest10",
                "Cold callback must use the original profile embedded at build time, with no post-build app mutation")
        hq = runpy.run_path(str(ROOT / "Scripts/CI/hq-stage2-focused-apple.py"))
        hq["verify_actual_sources"](build)
        native = build["native_context"]
        require(digest(ROOT / "Maktabah.xcodeproj/project.pbxproj") == native["generated_project_sha256"]
                and digest(ROOT / "Maktabah.xcworkspace/contents.xcworkspacedata") == native["workspace_sha256"],
                "Original generated CocoaPods project/workspace changed")
        hq["prepare_original_hanlin"](json.loads(BUILD_INPUTS.read_text()), build, verify_only=True)
        write(OUT / "original-post-ui-input-audit.json", build)
        contract = json.loads(MANIFEST.read_text())
        runpy.run_path(str(ROOT / "Scripts/CI/runtime27.py"))["collect_cases"](report, contract)
        result = json.loads((ROOT / "build/artifacts/faithful-ipad-matrix.json").read_text())
        devices = result.get("devices", [])
        require(len(devices) == 1 and devices[0]["label"] == "11-reader"
                and devices[0]["status"] == "EXECUTED_PASS" and devices[0]["ownedSimulatorCleanup"] == "PASS"
                and report.get("executed_ui_pass") == 1
                and not any(report.get(key, 0) for key in ["executed_ui_fail", "executed_ui_skip", "ui_not_run"]),
                "The original two-app XCTest did not execute and pass")
        wire = json.loads((OUT / "native-wire-evidence.json").read_text())
        require(wire["status"] == "ACTUAL_SHARED_RECORD_AND_ORIGINAL_SQLITE_RECEIPT_PASS", "Original saved callback receipt is incomplete")
        report["producer_admission"] = json.loads((OUT / "producer-admission.json").read_text())
        report["status"] = "ACTUAL_TWO_APP_CONSUMER_UI_EXECUTED_PASS"
        return 0
    except Exception as error:
        report["error"] = type(error).__name__ + ": " + str(error)
        return 1
    finally:
        write(OUT / "result.json", report)


def reuse_ui_compile():
    """Reuse only the already executed SDK compile when every compiler input matches."""
    proof = configuration().get("ui_compile_reuse")
    if not proof:
        return False
    receipt_path = ROOT / proof["report"]
    require(digest(receipt_path) == proof["report_sha256"], "Reviewed Apple compiler receipt changed")
    receipt = json.loads(receipt_path.read_text())
    require(receipt["status"] == "SDK_COMPILE_PASS" and receipt["aggregateSDKStatus"] == "PASS"
            and receipt["compilerExitCode"] == 0 and receipt["appMembershipStatus"] == "PASS"
            and receipt["sourceSHA"] == proof["source_sha"] and receipt["nativeUITestsExecuted"] == 0,
            "Historical evidence is not the actual successful UI SDK compile")
    same_sources = all(digest(ROOT / name) == expected for name, expected in receipt["sourceHashes"].items())
    same_driver = all(git("rev-parse", "HEAD:" + name) == git("rev-parse", proof["source_sha"] + ":" + name)
                      for name in ["Scripts/CI/typecheck-faithful-ui-tests.py", "Maktabah.xcodeproj/project.pbxproj"])
    same_tools = (capture("xcodebuild", "-version") == receipt["xcode"]
                  and capture("xcrun", "swift", "--version") == receipt["swift"]
                  and capture("xcrun", "--sdk", "iphonesimulator", "--show-sdk-path") == receipt["sdk"])
    reusable = same_sources and same_driver and same_tools
    write(OUT / "ui-sdk-compile-reuse.json", {"status": "REUSED_EXACT_APPLE_SDK_COMPILE" if reusable else "CHANGED_SOURCE_REQUIRES_ACTUAL_UI_TARGET_BUILD",
          "historical_run": proof["run_id"], "historical_source": proof["source_sha"],
          "historical_artifact_id": proof["artifact_id"], "historical_artifact_sha256": proof["artifact_sha256"],
          "report_sha256": proof["report_sha256"], "same_source_bytes": same_sources,
          "same_driver_and_project": same_driver, "same_apple_compiler_and_sdk": same_tools,
          "native_tests_executed": 0, "new_standalone_swift_compiles": 0,
          "current_compile_owner": "Actual Maktabah-iOS build-for-testing including its original UI target"})
    return reusable


def run_from_existing_native_workflow(report, run_logged, controller):
    """Use the existing native subset runner without changing workflow authority."""
    code = 1
    try:
        prepare()
        # Preserve historical source-compile evidence honestly. Changed UI code
        # is compiled in the real app/test target below, not a duplicate standalone suite.
        reuse_ui_compile()
        if run_logged([sys.executable, "Scripts/CI/hq-stage2-focused-apple.py", "--build-for-testing",
                       "--derived-data", "build/DerivedData", "--simulator-data-profile", "miniTest10"],
                      "miniapps-original-app-build.log", 7200, interrupt_controller=controller):
            raise RuntimeError("Original app/test build failed; new two-app UI case NOT_RUN")
        export_built_products()
        restore_producer()
        write(OUT / "built-binaries.json", binaries())
        code = run_logged([sys.executable, "Scripts/CI/otzaria-miniapps-native.py", "matrix"],
                          "miniapps-two-app-matrix.log", 7200, interrupt_controller=controller)
    except Exception as error:
        report["miniapps_driver_error"] = type(error).__name__ + ": " + str(error)
        code = 1
    finally:
        collection_code = collect()
        outcome = json.loads((OUT / "result.json").read_text())
        report.update(outcome)
        report.setdefault("case_outcomes", [])
        report["mode"] = "ui"
    return code or collection_code


if __name__ == "__main__":
    os.chdir(ROOT)
    OUT.mkdir(parents=True, exist_ok=True)
    (ROOT / "build/artifacts/runtime27").mkdir(parents=True, exist_ok=True)
    modes = {"prepare": prepare, "restore-producer": restore_producer, "run": execute, "matrix": matrix, "collect": collect}
    if len(sys.argv) != 2 or sys.argv[1] not in modes:
        raise SystemExit("Expected prepare, restore-producer, run, matrix or collect")
    raise SystemExit(modes[sys.argv[1]]() or 0)
