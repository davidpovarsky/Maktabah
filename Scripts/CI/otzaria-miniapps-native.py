#!/usr/bin/env python3
"""Actual original Otzaria text and native-file journeys through standalone MiniApps."""
import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import runpy
import shutil
import sqlite3
import stat
import uuid
import zipfile
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
FILE_SELECTOR = "MiniAppsAnnotationAcceptanceTests/testOriginalNativeFilesRoundTripAndReplayAfterColdReopen"
PICKER_SELECTOR = "MiniAppsAnnotationAcceptanceTests/testSharedPickerHebrewRTLUsesNativeEditingAndPersistsPreferences"
IPAD_SELECTORS = [SELECTOR, FILE_SELECTOR]
SELECTORS = IPAD_SELECTORS + [PICKER_SELECTOR]
FILE_WORKSHOP = "org.itorah.miniapps.fileworkshop"
GROUPS = [{"label": "11-reader", "size": "11", "hid_comparison": False, "case_ids": IPAD_SELECTORS},
          {"label": "phone", "size": "phone", "hid_comparison": False, "case_ids": [PICKER_SELECTOR]}]
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
    image_guard = runpy.run_path(str(ROOT / "Scripts/CI/miniapps_runtime_image_origin.py"))
    image_guard["require_full_acceptance_inputs"](os.environ, "canonical MiniApps process environment")
    value = json.loads(INPUTS.read_text())
    require(re.fullmatch(r"[a-f0-9]{40}", value["producer_source_sha"]), "Producer source must be frozen")
    require(value["producer_repository"] == "davidpovarsky/hanlin-ai", "Unexpected producer source repository")
    consumer = value.get("consumer_sdk_source_sha", value["producer_source_sha"])
    require(isinstance(consumer, str) and re.fullmatch(r"[a-f0-9]{40}", consumer),
            "Consumer shared SDK source must be frozen")
    origin = value.get("producer_origin", "github-actions")
    require(origin in ("github-actions", "local-mac"), "Unsupported producer execution origin")
    if origin == "github-actions":
        require(type(value["producer_run_id"]) is int and value["producer_run_id"] > 0, "Producer run must be frozen")
        require(value["producer_artifact_name"] == "app-split-" + str(value["producer_run_id"]),
                "Unexpected producer artifact identity")
        require("local_producer_manifest" not in value and "local_producer_preparation" not in value,
                "A GitHub producer cannot silently substitute a local product or preparation")
    else:
        require(value.get("producer_run_id") is None and value.get("producer_artifact_name") is None,
                "A local producer must not invent GitHub run or artifact identities")
        local = value.get("local_producer_manifest")
        require(isinstance(local, dict) and set(local) == {"path", "sha256"}
                and isinstance(local["path"], str) and Path(local["path"]).is_absolute()
                and isinstance(local["sha256"], str) and re.fullmatch(r"[a-f0-9]{64}", local["sha256"]),
                "Local producer requires its exact manifest path and reviewed SHA256")
    return value


def original_editor_admission(config):
    """Pin the existing strict Debug route without claiming Release qualification."""
    debug = config.get("original_editor_debug_admission")
    if debug is None:
        routes = runpy.run_path(str(ROOT / "Scripts/CI/original_editor_sdk_routes.py"))["load"](ROOT)
        return {"mode": "all-configurations", **{
            key: routes[key] for key in
            ("manifest_path", "manifest_sha256", "sdk_source_sha", "native_source_tree", "signing_team_id")}}
    require(isinstance(debug, dict) and set(debug) == {"path", "sha256"},
            "Debug native SDK admission requires its exact committed configuration")
    path = debug.get("path")
    require(isinstance(path, str) and path.startswith("Scripts/CI/")
            and path.endswith(".json") and not Path(path).is_absolute()
            and ".." not in Path(path).parts
            and re.fullmatch(r"[a-f0-9]{64}", debug.get("sha256", "")),
            "Debug native SDK configuration path or digest is invalid")
    target = ROOT / path
    require(target.is_file() and not target.is_symlink() and digest(target) == debug["sha256"],
            "Debug native SDK configuration bytes differ")
    committed = subprocess.check_output(["git", "show", "HEAD:" + path], cwd=ROOT, timeout=90)
    require(committed == target.read_bytes(), "Debug native SDK configuration is not committed exactly")
    admission = json.loads(committed)
    runpy.run_path(str(ROOT / "Scripts/CI/original_editor_local_admission.py"))["validate_configuration"](admission)
    return {"mode": "debug-simulator", "configuration_path": path,
            "configuration_sha256": debug["sha256"], "sdk_source_sha": admission["source_sha"],
            "configuration_status": "PINNED_CONFIGURATION_REQUIRES_ORIGINAL_BINARY_ADMISSION",
            "release_qualification": "NOT_CLAIMED"}


def original_editor_build_arguments():
    admission = original_editor_admission(configuration())
    if admission["mode"] == "debug-simulator":
        return ["--original-editor-admission", admission["configuration_path"]]
    return ["--original-editor-routes"]


def miniapps_source_admission(config, inputs):
    producer = config["producer_source_sha"]
    consumer = config.get("consumer_sdk_source_sha", producer)
    require(inputs["hanlin_gitlink"] == consumer
            and git("rev-parse", "HEAD:Vendor/HanlinSDK") == consumer,
            "Consumer shared SDK differs from its explicit source pin")
    pin = config.get("miniapps_source_equivalence")
    if pin is None:
        require(consumer == producer,
                "Distinct MiniApps producer/consumer sources require a committed bridge review")
        return None
    helper = runpy.run_path(str(ROOT / "Scripts/CI/original_editor_hanlin_equivalence.py"))
    return helper["read_miniapps_review"](ROOT, pin, producer, consumer)


def verify_miniapps_source_ownership():
    config = configuration()
    inputs = json.loads(BUILD_INPUTS.read_text())
    admitted = miniapps_source_admission(config, inputs)
    helper = runpy.run_path(str(ROOT / "Scripts/CI/original_editor_hanlin_equivalence.py"))
    return helper["verify_miniapps_sources"](
        ROOT, config["producer_source_sha"], inputs["hanlin_gitlink"], admitted)


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
    bridge_admission = miniapps_source_admission(config, inputs)
    original = runpy.run_path(str(ROOT / "Scripts/CI/completion-focused-native.py"))
    editor_admission = original_editor_admission(config)
    return {"checkout_sha": head, "application_source_sha": source, "application_trees": trees,
            "producer_inputs": config,
            "miniapps_bridge_source_equivalence": bridge_admission,
            "original_editor_admission": editor_admission,
            "original_case_catalog_sha256": digest(ROOT / "docs/hq-integration/runtime27/R27_CASES.json"),
            "execution_inputs": original["exact_working_inputs"](["Scripts/CI", ".github/workflows", "Maktabah-iOSUITests", "tools", "MiniApps/FileWorkshop"])}


def prepare():
    require(not (OUT / "source-before.json").exists(), "Existing native evidence must not be overwritten")
    context = source_context()
    contract = json.loads((ROOT / "docs/hq-integration/runtime27/R27_CASES.json").read_text())
    oracles = {
        SELECTOR: "Original reader selection and note toolbar; actual TextStudio warm/cold callbacks; five durable SQLite result receipts, separately validated native apply and SQLite commit, native rich archive and newer-block preservation, cold native remount, duplicate callback, linked-note anchors and unchanged corpus",
        FILE_SELECTOR: "Actual UI import and execution of committed NativeScript File Workshop; original native file upload, cold native archive reopen and byte export, real readAttachment/writeAttachment/complete, UTF-8 edits, same-name distinct blocks, cold return, cancellation and replay with original SQLite receipts and unchanged corpus"}
    oracles[PICKER_SELECTOR] = "Actual original iPhone Hebrew/RTL chooser and native More/Edit: favorites, drag order, visibility, Done, window preference and persistence; actual screenshots and accessibility hierarchy; no request enqueued by settings edits"
    catalog = contract["cases"] + contract.setdefault("supplemental_cases", [])
    for selector in SELECTORS:
        matches = [row for row in catalog if row["case_id"] == selector]
        require(len(matches) <= 1, "Duplicate original native acceptance selector")
        if not matches:
            row = {"case_id": selector, "device": "iphone" if selector == PICKER_SELECTOR else "ipad11", "status": "NOT_RUN"}
            contract["supplemental_cases"].append(row)
        else:
            row = matches[0]
        require(row["device"] == ("iphone" if selector == PICKER_SELECTOR else "ipad11"),
                "Original MiniApps selection was assigned to the wrong native device")
        row["oracle"] = oracles[selector]
    contract.update(source_test_commit=context["application_source_sha"],
                    app_source=context["application_source_sha"],
                    application_source_sha=context["application_source_sha"],
                    execution_case_ids=SELECTORS, execution_groups=GROUPS, required_nonzero_cases=len(SELECTORS),
                    native_cases_executed=0, expected_per_device={"ipad11": len(IPAD_SELECTORS), "ipad13": 0, "iphone": 1},
                    diagnostic_only=True, hid_comparison=False,
                    scope="Actual two-app MiniApps consumer acceptance only; previously accepted unrelated suites are not replayed")
    runpy.run_path(str(ROOT / "Scripts/CI/runtime27.py"))["execution_groups"](contract)
    declarations = runpy.run_path(str(ROOT / "Scripts/CI/verify-faithful-xctest.py"))["validate_selections"](
        SELECTORS, ROOT / "Maktabah-iOSUITests")
    require(declarations["status"] == "DECLARATIONS_MATCH", "The selected original XCTest is absent")
    write(OUT / "declarations.json", declarations)
    write(MANIFEST, contract)
    write(OUT / "source-before.json", context)


def restore_producer():
    config = configuration()
    write(OUT / "miniapps-bridge-source-proof.json", verify_miniapps_source_ownership())
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
    runtime_closure = runpy.run_path(str(ROOT / "Scripts/CI/miniapps-consumer-runtime-closure.py"))["audit"](
        ROOT, primary_roots[0], OUT / "consumer-runtime-closure")
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
        "binary_identity": binaries(), "consumer_runtime_closure": runtime_closure,
        "native_ui_acceptance": "NOT_RUN_AT_EXPORT",
        "physical_signing_status": "NOT_VALIDATED_BY_SIMULATOR"})
    print("Retained original app and UI test products with complete file and archive hashes", flush=True)


def native_context(record):
    request = record["request"]
    value = json.loads(request["source"]["metadata"]["otzaria.original-editor.miniapps.v1"])
    nodes = [n for n in value["nodes"] if n.get("bodyText") is not None]
    require(value["schema"] == "otzaria.original-miniapps-context/1"
            and value["documentText"] == "\n".join(n["bodyText"] for n in nodes)
            and request["source"]["documentText"] == value["documentText"],
            "Actual original rich context is not its complete native text witness")
    return value, nodes


def expected_native_insert(record, overrides=None):
    context, nodes = native_context(record)
    overrides = overrides or {}
    bodies = [overrides.get(n["id"], n["bodyText"]) for n in nodes]
    text = "\n".join(i["text"] for i in record["result"]["items"] if i.get("text") is not None)
    require(record["result"]["operation"] == "insert", "Rich insertion changed its requested operation")
    if not context["blockIDs"]:
        require(context.get("selectionLocation") is None and context.get("selectionLength") is None,
                "Unselected native insertion has a forged range")
        bodies.append(text)
    else:
        require(len(context["blockIDs"]) == 1 and context.get("selectionLength") == 0,
                "Expected a single actual native caret")
        indices = [i for i, node in enumerate(nodes) if node["id"] == context["blockIDs"][0]]
        require(indices == [0], "The actual first original native block must own the insertion")
        encoded = bodies[0].encode("utf-16-le")
        offset = context["selectionLocation"] * 2
        require(0 <= offset <= len(encoded), "Native insertion offset is outside the actual body")
        bodies[0] = (encoded[:offset] + text.encode("utf-16-le") + encoded[offset:]).decode("utf-16-le")
    return bodies


def original_launch_revision(connection, context):
    source = context["source"]
    revision = source["revision"]
    baseline = context.get("baselineBodySHA256")
    if baseline is None:
        # Earlier requests already describe the live draft restored after saving.
        return revision
    require(isinstance(baseline, str) and re.fullmatch("[0-9a-f]{64}", baseline),
            "The durable launch has no valid original archive digest")
    saved_revision = revision + 1
    rows = connection.execute(
        "SELECT payload_digest,payload_base64 FROM otzaria_annotation_exchange_versions "
        "WHERE namespace='otzaria.local.annotation' AND lower(annotation_uuid)=lower(?) AND revision=?",
        (source["annotation"], saved_revision)).fetchall()
    require(len(rows) == 1, "The original launch baseline revision is missing or ambiguous")
    digest_value, encoded = rows[0]
    payload = base64.b64decode(encoded, validate=True)
    require(hashlib.sha256(payload).hexdigest() == digest_value, "The launch envelope digest differs")
    rich = json.loads(payload)["richBody"]
    body = base64.b64decode(rich["bytesBase64"], validate=True)
    require(rich["format"] == "anytype.native-protobuf-archive" and rich["formatVersion"] == 1
            and len(body) > 16 and body.startswith(b"ATOSNAP\x00")
            and int.from_bytes(body[8:12], "big") == 1
            and hashlib.sha256(body).hexdigest() == baseline,
            "The launch context does not name the original saved native archive")
    end = 16 + int.from_bytes(body[12:16], "big")
    require(16 < end < len(body), "The native launch frame has an invalid header")
    provenance = json.loads(body[16:end])["provenance"]
    require(provenance["annotationUUID"].lower() == source["annotation"].lower()
            and provenance["hostProfileID"] == source["profile"]
            and provenance["accountID"] == source["account"]
            and provenance["objectID"] == source["object"]
            and provenance["spaceID"] == source["space"]
            and provenance["capturedAgainstRevision"] == revision
            and provenance["sourceWitnessSHA256"] == source["witness"],
            "The launch archive provenance differs from the original request")
    return saved_revision


def verify_rich_returns(records):
    require(len(records) == 2, "Two actual original-rich-editor callbacks are required")
    warm = [r for r in records if r["shared_record"]["result"]["items"][0]["text"].startswith("MiniApps rich warm שלום ")]
    cold = [r for r in records if r["shared_record"]["result"]["items"][0]["text"].startswith("MiniApps rich cold שלום ")]
    require(len(warm) == len(cold) == 1, "Both native original-editor results must contain actual typed nonces")
    warm, cold = warm[0], cold[0]
    warm_context, warm_nodes = native_context(warm["shared_record"])
    cold_context, cold_nodes = native_context(cold["shared_record"])
    require(len(warm_nodes) == 2 and warm_nodes[0]["bodyText"].startswith("Original rich Alpha ")
            and warm_nodes[1]["bodyText"].startswith("Original rich Beta שלום "),
            "The actual launch must contain two independently edited original native blocks")
    require(len(cold_nodes) >= 2, "The real cold launch lost its independent original blocks")
    newer = cold_nodes[1]["bodyText"]
    require(newer.startswith("Newer unsaved rich Beta שלום ") and newer != warm_nodes[1]["bodyText"],
            "The other native block must really have changed while the first result was pending")
    expected_warm = expected_native_insert(warm["shared_record"], {warm_nodes[1]["id"]: newer})
    require([n["bodyText"] for n in cold_nodes] == expected_warm,
            "The real cold source does not preserve the prior warm result and newer original block")
    final_bodies = expected_native_insert(cold["shared_record"])
    require(newer in final_bodies, "Cold return lost the concurrent original native edit")
    require(len({tuple(r["original_receipt_rows"][0][:3]) for r in records}) == 1
            and all(r["original_receipt_rows"][0][3] == "\n".join(final_bodies) for r in records),
            "The two rich callbacks do not resolve to one final original note")
    document = json.loads(cold["shared_record"]["request"]["source"]["metadata"]["otzaria.annotation.v1"])
    connection = sqlite3.connect(Path(document["profile"]).as_uri() + "?mode=ro", uri=True)
    try:
        rows = connection.execute("""
            SELECT h.revision,v.mutation_id,v.payload_digest,v.payload_base64
            FROM otzaria_annotation_exchange_heads h
            JOIN otzaria_annotation_exchange_versions v
              ON v.namespace=h.namespace AND v.annotation_uuid=h.annotation_uuid AND v.revision=h.revision
            WHERE h.namespace='otzaria.local.annotation' AND lower(h.annotation_uuid)=lower(?)
            """, (cold_context["source"]["annotation"],)).fetchall()
        require(len(rows) == 1, "The actual native canonical head is missing or ambiguous")
        revision, mutation, payload_hash, encoded = rows[0]
        require(revision == original_launch_revision(connection, cold_context) + 1
                and mutation.lower() == cold["shared_record"]["request"]["id"].lower(),
                "The cold native body is not the one committed with the exact callback receipt")
        for returned, context in ((warm, warm_context), (cold, cold_context)):
            callback = connection.execute(
                "SELECT revision FROM otzaria_annotation_exchange_versions WHERE namespace='otzaria.local.annotation' "
                "AND lower(annotation_uuid)=lower(?) AND lower(mutation_id)=lower(?)",
                (context["source"]["annotation"], returned["shared_record"]["request"]["id"])).fetchall()
            require(callback == [(original_launch_revision(connection, context) + 1,)],
                    "A rich callback created zero, duplicate, or incorrectly based native revisions")
    finally:
        connection.close()
    payload = base64.b64decode(encoded, validate=True)
    require(hashlib.sha256(payload).hexdigest() == payload_hash, "Original native envelope digest differs")
    envelope = json.loads(payload)
    rich = envelope["richBody"]
    native_body = base64.b64decode(rich["bytesBase64"], validate=True)
    require(envelope["textPreview"] == "\n".join(final_bodies)
            and rich["format"] == "anytype.native-protobuf-archive" and rich["formatVersion"] == 1
            and native_body.startswith(b"ATOSNAP\x00"),
            "The return must persist the actual original native archive, not only a plain preview")
    return {"status": "ACTUAL_ORIGINAL_RICH_WARM_COLD_RECEIPTS_PASS",
            "native_revision": revision, "mutation_id": mutation, "payload_sha256": payload_hash,
            "native_body_sha256": hashlib.sha256(native_body).hexdigest(), "native_body_bytes": len(native_body),
            "newer_original_block_preserved": True,
            "native_block_topology_and_duplicate_callback": "ASSERTED_BY_ACTUAL_XCTEST"}




def stage_file_workshop(udid):
    """Stage only the committed installable input; XCTest performs the real import."""
    directory = ROOT / "MiniApps/FileWorkshop"
    paths = ["PACKAGE.json", "FileWorkshop.hanlinNativeScript", "source/script.json",
             "source/nativescript/app/package.json", "source/nativescript/app/bundle.mjs"]
    source_hashes = {}
    for relative in paths:
        path = directory / relative
        require(path.is_file() and not path.is_symlink(), "Missing original File Workshop package source")
        committed = subprocess.check_output(["git", "show", "HEAD:" + str(path.relative_to(ROOT))], cwd=ROOT)
        require(path.read_bytes() == committed, "File Workshop input is not the exact committed package")
        source_hashes[relative] = digest(path)
    package = json.loads((directory / "PACKAGE.json").read_text())
    archive = directory / "FileWorkshop.hanlinNativeScript"
    with zipfile.ZipFile(archive) as bundle:
        expected = {str(path.relative_to(directory / "source")): path.read_bytes()
                    for path in (directory / "source").rglob("*") if path.is_file()}
        require(len(bundle.namelist()) == len(expected) and set(bundle.namelist()) == set(expected),
                "File Workshop archive source membership differs")
        require(all(bundle.read(name) == value for name, value in expected.items()),
                "File Workshop archive differs from its original committed source")
    manifest = json.loads((directory / "source/script.json").read_text())
    require(manifest["hanlinAppID"] == FILE_WORKSHOP
            and package["app_id"] == FILE_WORKSHOP and package["archive"] == archive.name
            and package["sha256"] == digest(archive) and package["bytes"] == archive.stat().st_size
            and package["files"] == {name: hashlib.sha256(value).hexdigest() for name, value in expected.items()},
            "Wrong or incompletely bound real file MiniApp")
    data = resolve_native_container(udid, PRODUCER, "data").resolve(strict=True)
    destination = data / "Documents/FileWorkshop.hanlinNativeScript"
    destination.parent.mkdir(parents=True, exist_ok=True)
    require(not destination.exists() and not destination.is_symlink(), "File Workshop input is already staged")
    with destination.open("xb") as stream:
        stream.write(archive.read_bytes())
    require(digest(destination) == digest(archive), "Actual producer input archive copy differs")
    receipt = {"status": "COMMITTED_INPUT_STAGED_FOR_ACTUAL_IMPORT_UI",
               "package_id": FILE_WORKSHOP, "checkout_sha": git("rev-parse", "HEAD"),
               "source_hashes": source_hashes, "package_record": package,
               "archive_path": str(destination), "archive_sha256": digest(destination),
               "producer_data_container": str(data), "native_import_executed": False,
               "registry_or_bridge_mutation": False}
    write(OUT / "file-workshop-input-stage.json", receipt)
    return receipt


def actual_shared_file(group, item):
    require(item.get("kind") == "file" and item.get("text") is None
            and isinstance(item.get("name"), str) and item["name"], "Actual result is not an attached file")
    identity = uuid.UUID(item["attachmentID"])
    path = group / "MiniAppsBridge/v1/attachments" / str(identity)
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    with os.fdopen(descriptor, "rb") as stream:
        before = os.fstat(stream.fileno())
        require(stat.S_ISREG(before.st_mode), "Actual shared attachment is not a regular file")
        data = stream.read()
        after = os.fstat(stream.fileno())
    require((before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns)
            == (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns)
            and len(data) == before.st_size, "Actual attachment changed during readback")
    retained = OUT / "file-workshop-attachments" / str(identity)
    retained.parent.mkdir(parents=True, exist_ok=True)
    if retained.exists():
        require(retained.read_bytes() == data, "A shared attachment identity changed its bytes")
    else:
        with retained.open("xb") as output:
            output.write(data)
    return data, {"attachment_id": str(identity), "name": item["name"],
                  "type_identifier": item.get("typeIdentifier"), "bytes": len(data),
                  "sha256": hashlib.sha256(data).hexdigest(),
                  "retained_path": str(retained.relative_to(OUT))}


def verify_file_returns(records, group):
    require(len(records) == 3, "Two real file returns and one actual cancellation are required")
    records = sorted(records, key=lambda row: native_context(row["shared_record"])[0]["source"]["revision"])
    first, second, cancelled = records
    document_ids, annotation_ids, witnesses = set(), set(), []
    for row in records:
        record = row["shared_record"]
        request, result = record["request"], record.get("result") or {}
        document = json.loads(request["source"]["metadata"]["otzaria.annotation.v1"])
        context, _ = native_context(record)
        require(request["appID"] == FILE_WORKSHOP and request["source"]["kind"] == "native-annotation"
                and record["acknowledged"] is True, "File journey is not an acknowledged real native-editor request")
        require(document["annotationUUID"].lower() == context["source"]["annotation"].lower()
                and document["annotationID"] is not None and not document["isReaderSelection"],
                "Native file request lost its original source-linked annotation")
        document_ids.add(request["source"]["documentID"])
        annotation_ids.add((document["profile"], document["annotationID"], document["annotationUUID"]))
        input_items = [item for item in request["inputs"] if item.get("kind") == "file"]
        mapping = json.loads(request["source"]["metadata"].get("otzaria.original-editor.files.v1", "{}"))
        require({str(uuid.UUID(key)) for key in mapping} ==
                {str(uuid.UUID(item["attachmentID"])) for item in input_items}
                and len(set(mapping.values())) == len(input_items),
                "Actual file inputs do not identify distinct original native file blocks")
        inputs = [actual_shared_file(group, item) for item in input_items]
        outputs = [actual_shared_file(group, item) for item in result.get("items", [])]
        row["native_file_inputs"] = [entry for _, entry in inputs]
        row["native_file_outputs"] = [entry for _, entry in outputs]
        witnesses.append((context, document, inputs, outputs))
        rows = row["original_receipt_rows"]
        if row is cancelled:
            require(result.get("status") == "cancelled" and not result.get("items") and not rows,
                    "Actual file cancellation must not create a canonical result receipt")
        else:
            require(result.get("status") == "success" and result.get("operation") == "insert"
                    and len(outputs) == 1 and len(rows) == 1
                    and rows[0][0] == document["annotationID"]
                    and rows[0][1] == rows[0][2] == document["annotationUUID"]
                    and rows[0][5:10] == (document["bookID"], document["contentID"],
                        document["rangeLocation"], document["rangeLength"], document["context"])
                    and json.loads(rows[0][4]) == result,
                    "Actual file upload lacks its exact original SQLite receipt and source anchor")
    require(len(document_ids) == len(annotation_ids) == 1, "Actual file callbacks crossed native documents")
    a, b, c = witnesses
    require(not a[2] and len(b[2]) == 1 and len(c[2]) == 2,
            "Original native file export must observe zero, one, then two saved blocks")
    first_data, second_data = a[3][0][0], b[3][0][0]
    require(re.fullmatch(rb"NativeFile[0-9A-F]{32}", first_data)
            and re.fullmatch("קובץ בעברית\\n[0-9A-F-]{36}\\nNative file bytes", second_data.decode("utf-8")),
            "The original runtime must return actual user-entered nonce-bearing UTF-8 bytes")
    require(first["shared_record"]["result"].get("metadata", {}).get("fileMode") == "new-utf8"
            and second["shared_record"]["result"].get("metadata", {}).get("fileMode") == "edited-utf8",
            "The real file MiniApp did not execute both create and edit actions")
    require(b[2][0][0] == first_data and {data for data, _ in c[2]} == {first_data, second_data},
            "Cold native archive/FileDownload/Bridge readback does not match the actual returned file bytes")
    require(a[3][0][1]["name"] == b[3][0][1]["name"] == "document.txt"
            and a[3][0][1]["attachment_id"] != b[3][0][1]["attachment_id"],
            "Distinct original file blocks must preserve the same display filename without identity collision")
    context, document = c[:2]
    connection = sqlite3.connect(Path(document["profile"]).as_uri() + "?mode=ro", uri=True)
    try:
        versions = {}
        for row in records:
            request = row["shared_record"]["request"]
            actual = connection.execute(
                "SELECT revision,payload_digest FROM otzaria_annotation_exchange_versions "
                "WHERE lower(mutation_id)=lower(?)", (request["id"],)).fetchall()
            if row is cancelled:
                require(not actual, "Cancelled native file request created a canonical revision")
            else:
                source_context_value, _ = native_context(row["shared_record"])
                require(len(actual) == 1 and actual[0][0] == original_launch_revision(connection, source_context_value) + 1,
                        "A file callback created zero, duplicate, or incorrectly based native revisions")
                versions[request["id"]] = {"revision": actual[0][0], "payload_sha256": actual[0][1]}
        heads = connection.execute(
            "SELECT h.revision,v.mutation_id,v.payload_digest,v.payload_base64 "
            "FROM otzaria_annotation_exchange_heads h JOIN otzaria_annotation_exchange_versions v "
            "ON v.namespace=h.namespace AND v.annotation_uuid=h.annotation_uuid AND v.revision=h.revision "
            "WHERE h.namespace='otzaria.local.annotation' AND lower(h.annotation_uuid)=lower(?)",
            (context["source"]["annotation"],)).fetchall()
        require(len(heads) == 1 and heads[0][0] == original_launch_revision(connection, context),
                "Cancellation or replay changed the final canonical native revision")
    finally:
        connection.close()
    revision, mutation, payload_sha, encoded = heads[0]
    payload = base64.b64decode(encoded, validate=True)
    require(hashlib.sha256(payload).hexdigest() == payload_sha, "Actual native file envelope digest differs")
    envelope = json.loads(payload)
    rich = envelope["richBody"]
    native_body = base64.b64decode(rich["bytesBase64"], validate=True)
    require(rich["format"] == "anytype.native-protobuf-archive" and rich["formatVersion"] == 1
            and native_body.startswith(b"ATOSNAP\x00"), "Files were not saved in the original native archive")
    retained = OUT / "file-workshop-native-canonical"
    retained.mkdir(exist_ok=False)
    (retained / "annotation-envelope.json").write_bytes(payload)
    (retained / "original-native-archive.bin").write_bytes(native_body)
    return {"status": "ACTUAL_ORIGINAL_NATIVE_FILES_AND_RECEIPTS_PASS",
            "successful_file_callbacks": 2, "cancelled_file_requests": 1,
            "canonical_revision": revision, "canonical_mutation_id": mutation,
            "canonical_payload_sha256": payload_sha,
            "native_body_sha256": hashlib.sha256(native_body).hexdigest(),
            "native_body_bytes": len(native_body), "result_revisions": versions,
            "source_linked_annotation": list(annotation_ids)[0],
            "cold_reopen_cold_callback_and_replay": "ASSERTED_BY_ACTUAL_XCTEST",
            "native_upload_and_sqlite_receipt_atomic": False}


def verify_plain_file_return(records, group, udid):
    require(len(records) == 1, "One real legacy note file return and native share journey are required")
    row = records[0]
    record = row["shared_record"]
    request, result = record["request"], record.get("result") or {}
    document = json.loads(request["source"]["metadata"]["otzaria.annotation.v1"])
    rows = row["original_receipt_rows"]
    require(request["appID"] == FILE_WORKSHOP and request["source"]["kind"] == "annotation"
            and record["acknowledged"] is True and result.get("status") == "success"
            and result.get("operation") == "insert" and result.get("metadata", {}).get("fileMode") == "new-utf8"
            and document["annotationID"] is not None and not document["isReaderSelection"]
            and len(result.get("items", [])) == 1 and len(rows) == 1
            and rows[0][0] == document["annotationID"]
            and rows[0][1] == rows[0][2] == document["annotationUUID"]
            and rows[0][5:10] == (document["bookID"], document["contentID"],
                document["rangeLocation"], document["rangeLength"], document["context"])
            and json.loads(rows[0][4]) == result,
            "The original plain-note file return lacks an exact durable receipt and source anchor")
    item = result["items"][0]
    data, shared_proof = actual_shared_file(group, item)
    require(not [item for item in request["inputs"] if item.get("kind") == "file"]
            and re.fullmatch(rb"LegacyFile[0-9A-F]{32}", data)
            and data.decode("utf-8") == document["draftNote"],
            "The genuine legacy file must be created from actual user-entered note bytes")
    private = Path(capture("xcrun", "simctl", "get_app_container", udid, BUNDLE, "data")).resolve()
    retained = private / "Documents/MiniApps" / str(uuid.UUID(request["id"])).upper() / (
        str(uuid.UUID(item["attachmentID"])).upper() + "-" + Path(item["name"]).name)
    require(not retained.is_symlink() and retained.resolve().is_relative_to(private / "Documents/MiniApps"),
            "The retained attachment escaped the original private Documents root")
    descriptor = os.open(retained, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    with os.fdopen(descriptor, "rb") as stream:
        before = os.fstat(stream.fileno())
        require(stat.S_ISREG(before.st_mode), "The retained original attachment is not a regular file")
        private_data = stream.read()
        after = os.fstat(stream.fileno())
    require((before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns)
            == (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns)
            and len(private_data) == before.st_size and private_data == data,
            "The actual private file is missing, changed, or differs after ACK, cold reopen and replay")
    encoded = document["draftNote"].encode("utf-16-le")
    selection = document.get("selection")
    position = ((selection["location"] + selection["length"]) * 2 if selection else len(encoded))
    require(selection is None or selection["length"] == 0, "The legacy creation must keep original note text")
    require(0 <= position <= len(encoded), "Legacy source selection is invalid")
    expected = (encoded[:position] + retained.as_uri().encode("utf-16-le") + encoded[position:]).decode("utf-16-le")
    require(rows[0][3] == expected, "The original plain-note text/URL format was changed or inserted twice")
    connection = sqlite3.connect(Path(document["profile"]).as_uri() + "?mode=ro", uri=True)
    try:
        schema = connection.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='otzaria_annotation_exchange_versions'"
        ).fetchall()
        versions = connection.execute(
            "SELECT payload_base64 FROM otzaria_annotation_exchange_versions WHERE "
            "namespace='otzaria.local.annotation' AND lower(annotation_uuid)=lower(?)",
            (document["annotationUUID"],)).fetchall() if schema else []
        for version in versions:
            envelope = json.loads(base64.b64decode(version[0], validate=True))
            require(envelope.get("richBody") is None,
                    "The original legacy note was unexpectedly converted to a rich document")
    finally:
        connection.close()
    row["actual_retained_private_file"] = {"path": str(retained), "bytes": len(private_data),
        "sha256": hashlib.sha256(private_data).hexdigest()}
    row["actual_shared_file"] = shared_proof
    return {"status": "ACTUAL_LEGACY_FILE_BYTES_AND_ORIGINAL_NOTE_RECEIPT_PASS",
            "successful_file_callbacks": 1, "source_linked_annotation": list(rows[0][:3]),
            "retained_file": row["actual_retained_private_file"], "plain_format_preserved": True,
            "cold_reopen_native_activity_ui_and_duplicate_callback": "ASSERTED_BY_ACTUAL_XCTEST"}


class ActualMiniAppsProducer:
    def __init__(self):
        self.udid = None
        self.label = None
        self.completed_labels = set()
        self.before_request_ids = set()
        self.group = None
        self.corpus_group = None
        self.captured = False
        self.video = None
        self.video_log = None
        self.image_audits = []
        self.image_evidence = None
        self.state = {"status": "NOT_REACHED", "fixture_producer": False, "synthetic_results_written": False}

    def validate_selection(self, baseline, release_manifest, selection):
        require(not baseline and release_manifest is None and selection == SELECTORS, "Wrong native case selection")

    def stage(self, udid, container, label, selection):
        scopes = {group["label"]: group["case_ids"] for group in GROUPS}
        require(self.udid is None and label not in self.completed_labels and label in scopes
                and selection == scopes[label], "Wrong owned simulator scope")
        self.udid = udid
        self.label = label
        self.group = None
        self.captured = False
        self.video = self.video_log = None
        self.image_audits = []
        self.state = {"status": "NOT_REACHED", "fixture_producer": False, "synthetic_results_written": False}
        producer = PRODUCER_DIR / "HanlinMiniApps.app"
        require((OUT / "producer-admission.json").is_file(), "Actual producer product was not admitted")
        subprocess.run(["xcrun", "simctl", "install", udid, str(producer)], check=True, timeout=180)
        images = runpy.run_path(str(ROOT / "Scripts/CI/miniapps_runtime_image_origin.py"))
        products = ROOT / "build/DerivedData/Build/Products/Debug-iphonesimulator"
        runner = plistlib.loads((products / "Maktabah-iOSUITests-Runner.app/Info.plist").read_bytes())
        self.image_evidence = OUT / "image-origin" / label
        self.image_evidence.mkdir(parents=True, exist_ok=False)
        for role, artifact, bundle, required, names in [
            ("producer", producer, PRODUCER, ["Frameworks/NativeScript.framework/NativeScript"], ["Hanlin MiniApps"]),
            ("consumer", products / "Maktabah.app", BUNDLE, [], ["אוצריא", "Maktabah", "ChavrusaText"])
        ]:
            audit = images["ImageAudit"](ROOT, self.image_evidence / role, artifact,
                bundle_id=bundle, runner_bundle_id=runner["CFBundleIdentifier"],
                required_images=required, display_names=names)
            self.image_audits.append(audit)
        launch = subprocess.run(["xcrun", "simctl", "launch", udid, PRODUCER],
                                capture_output=True, text=True, check=True, timeout=60)
        (self.image_evidence / "producer-bootstrap-launch.log").write_text(launch.stdout + launch.stderr)
        match = re.fullmatch(re.escape(PRODUCER) + r":\s*(\d+)\s*", launch.stdout)
        require(match is not None, "Original producer launch returned no exact process identity")
        producer_audit = self.image_audits[0]
        producer_audit.sim = udid
        producer_audit.bootstrap(udid, int(match.group(1)), producer_audit.installed_app(int(match.group(1))))
        for audit in self.image_audits:
            audit.start(udid)
        consumer_group = resolve_native_container(udid, BUNDLE, GROUP)
        producer_group = resolve_native_container(udid, PRODUCER, GROUP)
        require(Path(consumer_group).resolve() == Path(producer_group).resolve(),
                "The two installed original apps do not resolve the same App Group")
        self.group = Path(consumer_group).resolve()
        self.corpus_group = resolve_native_container(udid, BUNDLE, "group.com.davidpovarsky.itorah").resolve()
        workshop = stage_file_workshop(udid) if label == "11-reader" else None
        self.before_request_ids = {path.name for path in (self.group / "MiniAppsBridge/v1/requests").glob("*.json")}
        corpus_profile = json.loads((ROOT / "Source/Otzaria/DataProfiles/miniTest10.profile.json").read_text())
        self.state.update(status="ACTUAL_PRODUCER_INSTALLED", udid=udid, group=str(self.group),
                          consumer_bundle=BUNDLE, producer_bundle=PRODUCER, shared_group_identifier=GROUP,
                          original_corpus_group=str(self.corpus_group))
        write(OUT / ("actual-two-app-stage.json" if label == "11-reader" else "actual-two-app-stage-phone.json"), self.state)
        self.video_log = (OUT / ("native-video-" + label + ".log")).open("w")
        self.video = subprocess.Popen(["xcrun", "simctl", "io", udid, "recordVideo", str(OUT / ("actual-two-app-" + label + ".mp4"))],
                                      stdout=self.video_log, stderr=subprocess.STDOUT)
        environment = {"TEST_RUNNER_MINIAPPS_NATIVE_SHARED_GROUP": str(self.group),
                "TEST_RUNNER_MINIAPPS_NATIVE_PRODUCER_BUNDLE": PRODUCER,
                "TEST_RUNNER_MINIAPPS_NATIVE_CORPUS_GROUP": str(self.corpus_group),
                "TEST_RUNNER_MINIAPPS_NATIVE_CORPUS_SHA256": corpus_profile["sourceDatabase"]["databaseSHA256"]}
        if workshop is not None:
            environment.update(TEST_RUNNER_MINIAPPS_FILE_WORKSHOP_ARCHIVE=workshop["archive_path"],
                               TEST_RUNNER_MINIAPPS_FILE_WORKSHOP_SHA256=workshop["archive_sha256"])
        else:
            environment["TEST_RUNNER_MINIAPPS_PICKER_EXPECTED_DEVICE"] = "iphone"
        return environment

    def redact_evidence(self, line):
        return line

    def configure_command(self, command, label):
        require(label == self.label and self.image_evidence is not None, "Wrong image-origin command scope")
        helper = runpy.run_path(str(ROOT / "Scripts/CI/miniapps_runtime_image_origin.py"))
        original = helper["create_bundled_ui_configuration"](
            ROOT, self.image_evidence,
            ROOT / "build/DerivedData/Build/Products/Debug-iphonesimulator/Maktabah.app",
            ROOT / "build/DerivedData")
        require(command[:2] == ["xcodebuild", "test-without-building"] and "-xctestrun" not in command,
                "MiniApps image-origin admission requires the original same-job UI command")
        kept = []
        index = 0
        while index < len(command):
            option = command[index]
            if option in {"-workspace", "-scheme", "-clonedSourcePackagesDirPath", "-derivedDataPath"}:
                require(index + 1 < len(command), "Incomplete original Xcode command")
                index += 2
            elif option == "-disableAutomaticPackageResolution":
                index += 1
            else:
                kept.append(option)
                index += 1
        kept[2:2] = ["-xctestrun", str(original)]
        write(self.image_evidence / "exact-ui-command.json", {"before": command, "after": kept,
            "scope": "Original generated targets and selectors; only UI application loader paths constrained"})
        return kept

    def finish_image_origins(self, label):
        attachment = ROOT / ("build/artifacts/visual-miniapps-phone" if label == "phone"
                             else "build/artifacts/visual-miniapps")
        reports = [audit.finish(
            log_paths=[ROOT / ("build/artifacts/test-simulator-" + label + ".log")],
            attachment_dirs=[attachment]) for audit in self.image_audits]
        result = {"status": "PASS" if len(reports) == 2 and all(r["status"] == "PASS" for r in reports)
                  else "IMAGE_ORIGIN_INCOMPLETE", "label": label, "reports": reports}
        write(OUT / ("image-origin-" + label + ".json"), result)

    def capture(self, udid, label):
        require(udid == self.udid and label == self.label, "Wrong producer evidence simulator")
        if self.captured:
            return
        self.captured = True
        for audit in self.image_audits:
            audit.stop_observing()
        if self.video is not None:
            self.video.terminate()
            try:
                self.video.wait(timeout=30)
            except subprocess.TimeoutExpired:
                self.video.kill()
                self.video.wait(timeout=10)
            self.video_log.close()
        if label == "phone":
            self.capture_phone_picker(udid)
            self.finish_image_origins(label)
            return
        report = {"status": "INCOMPLETE", "records": [], "rich_records": [], "file_records": [], "plain_file_records": [],
                  "fixture_producer": False, "synthetic_results_written": False}
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
                if request["appID"] == FILE_WORKSHOP:
                    kind = request["source"].get("kind")
                    require(kind in ("native-annotation", "annotation"), "Unexpected original file entry point")
                    collection = "file_records" if kind == "native-annotation" else "plain_file_records"
                    report[collection].append({"shared_record": record, "original_receipt_rows": rows})
                    continue
                if request["source"].get("kind") == "native-annotation":
                    verified = (record["acknowledged"] is True and result.get("status") == "success"
                                and result.get("operation") == "insert" and len(rows) == 1
                                and rows[0][0] == document["annotationID"]
                                and rows[0][1] == rows[0][2] == document["annotationUUID"]
                                and rows[0][5:10] == (document["bookID"], document["contentID"],
                                    document["rangeLocation"], document["rangeLength"], document["context"])
                                and json.loads(rows[0][4]) == result)
                    require(verified, "An actual original-rich-editor return lacks its exact durable receipt")
                    report["rich_records"].append({"shared_record": record, "original_receipt_rows": rows,
                        "same_original_annotation_verified": verified})
                    continue
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
            report["original_rich_editor"] = verify_rich_returns(report["rich_records"])
            rich_identities = {tuple(r["original_receipt_rows"][0][:3]) for r in report["rich_records"]}
            require(rich_identities.isdisjoint(identities)
                    and tuple(reader["original_receipt_rows"][0][:3]) not in rich_identities,
                    "Rich editor callbacks crossed another original document")
            report["original_native_files"] = verify_file_returns(report["file_records"], self.group)
            file_identities = {tuple(r["original_receipt_rows"][0][:3]) for r in report["file_records"]
                               if r["original_receipt_rows"]}
            require(len(file_identities) == 1 and file_identities.isdisjoint(identities | rich_identities)
                    and tuple(reader["original_receipt_rows"][0][:3]) not in file_identities,
                    "Native file callbacks crossed another original document")
            report["original_legacy_files"] = verify_plain_file_return(report["plain_file_records"], self.group, udid)
            legacy_identity = tuple(report["plain_file_records"][0]["original_receipt_rows"][0][:3])
            require(legacy_identity not in identities | rich_identities | file_identities
                    and legacy_identity != tuple(reader["original_receipt_rows"][0][:3]),
                    "The plain-note file callback crossed another original document")
            report["actual_callbacks"] = 8
            report["actual_file_cancellations"] = 1
            report["plain_editor_and_reader_callbacks"] = 3
            report["original_rich_editor_callbacks"] = 2
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
        self.finish_image_origins(label)

    def capture_phone_picker(self, udid):
        evidence = {"status": "INCOMPLETE", "udid": udid, "device": "iphone",
                    "language": "he", "locale": "he_IL", "actual_ui_result": "REQUIRED_SEPARATELY",
                    "fixture_producer": False, "synthetic_results_written": False}
        try:
            require(self.group is not None, "The actual iPhone shared container was not resolved")
            requests = self.group / "MiniAppsBridge/v1/requests"
            after = {path.name for path in requests.glob("*.json")}
            require(after == self.before_request_ids, "Editing the real picker unexpectedly enqueued a request")
            for name in ["catalog.json", "preferences.json"]:
                path = self.group / "MiniAppsBridge/v1" / name
                require(path.is_file() and not path.is_symlink(), "Missing actual shared picker state")
                destination = OUT / ("phone-actual-" + name)
                shutil.copyfile(path, destination)
                evidence[name] = {"path": str(destination), "sha256": digest(destination)}
            catalog = json.loads((OUT / "phone-actual-catalog.json").read_text())
            require(len(catalog["items"]) >= 2 and
                    any(item["id"] == "nativeapp.textstudio" for item in catalog["items"]),
                    "Phone picker did not consume the installed original producer catalog")
            evidence["status"] = "ACTUAL_PHONE_PICKER_STATE_RETAINED"
            evidence["native_editing_rtl_and_persistence"] = "ASSERTED_AND_CAPTURED_BY_ACTUAL_XCTEST"
        except Exception as error:
            evidence["error"] = type(error).__name__ + ": " + str(error)
        write(OUT / "phone-picker-state.json", evidence)
        result = ROOT / "build/artifacts/result-phone.xcresult"
        if result.is_dir():
            subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(result),
                            "--output-path", str(ROOT / "build/artifacts/visual-miniapps-phone")],
                           check=True, timeout=180)

    def cleanup(self, udid):
        if self.udid is not None:
            try:
                self.capture(udid, self.label)
            finally:
                self.completed_labels.add(self.label)
                self.udid = self.label = None


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
              "required_case_ids": SELECTORS, "full_native116_acceptance": False,
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
        require(len(devices) == len(GROUPS)
                and {device["label"] for device in devices} == {group["label"] for group in GROUPS}
                and all(device["status"] == "EXECUTED_PASS" and device.get("ownedSimulatorCleanup") == "PASS"
                        for device in devices)
                and report.get("executed_ui_pass") == len(SELECTORS)
                and not any(report.get(key, 0) for key in ["executed_ui_fail", "executed_ui_skip", "ui_not_run"]),
                "The original two-app XCTest did not execute and pass")
        wire = json.loads((OUT / "native-wire-evidence.json").read_text())
        require(wire["status"] == "ACTUAL_SHARED_RECORD_AND_ORIGINAL_SQLITE_RECEIPT_PASS", "Original saved callback receipt is incomplete")
        picker = json.loads((OUT / "phone-picker-state.json").read_text())
        require(picker["status"] == "ACTUAL_PHONE_PICKER_STATE_RETAINED",
                "Actual original iPhone picker evidence is incomplete")
        report["iphone_hebrew_picker"] = picker
        report["producer_admission"] = json.loads((OUT / "producer-admission.json").read_text())
        bridge_proof = verify_miniapps_source_ownership()
        require(bridge_proof == json.loads((OUT / "miniapps-bridge-source-proof.json").read_text()),
                "Original shared MiniApps source changed during native acceptance")
        report["miniapps_bridge_source_ownership"] = bridge_proof
        origins = [json.loads((OUT / ("image-origin-" + group["label"] + ".json")).read_text())
                   for group in GROUPS]
        require(all(row["status"] == "PASS" and len(row["reports"]) == 2
                    and {p["bundle_id"] for p in row["reports"]} == {BUNDLE, PRODUCER}
                    for row in origins), "Actual paired application image-origin coverage is incomplete")
        report["actual_loaded_image_origins"] = origins
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
                       *original_editor_build_arguments(), "--derived-data", "build/DerivedData",
                       "--simulator-data-profile", "miniTest10"],
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
