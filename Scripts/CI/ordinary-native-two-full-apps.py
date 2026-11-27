#!/usr/bin/env python3
"""Run the ordinary Anytype exchange in two complete, independent Otzaria apps.

The input manifest pins genuine Apple build products and their source receipt.
The only app-data transfer is the unchanged file saved by the original JSON
export UI, then selected in the other app's original security-scoped import UI.
All subsequent changes cross original AnySync and are accepted through the
original native read/update/receive screens. SQLite is never written here.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import sqlite3
import subprocess
import sys
import time
import traceback
import uuid


SELECTOR = "Maktabah-iOSUITests/ProductionAnnotationEditorAcceptanceTests/testOrdinaryOriginalNativeTwoAppExchangePhase"
BUNDLE = "com.davidpovarsky.chavrusatext"
PROTECTED = "2F225B23-3149-4384-906F-8865483CBE41"


def require(value, message):
    if not value:
        raise RuntimeError(message)


def digest(path):
    with Path(path).open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def run(*args, timeout=120):
    completed = subprocess.run([str(x) for x in args], capture_output=True, timeout=timeout)
    require(completed.returncode == 0, "Original Apple command failed: " + str(args[0]))
    return completed.stdout.decode().strip()


def check_pin(record):
    require(type(record) is dict and set(record) == {"path", "bytes", "sha256"}
            and type(record["bytes"]) is int and record["bytes"] >= 0
            and isinstance(record["path"], str) and isinstance(record["sha256"], str),
            "Use an exact path/size/hash witness")
    path = Path(record["path"])
    require(witness(path) == record, "A retained original input changed")
    return path



ROOT = Path(__file__).resolve().parents[2]
INPUT_SCHEMA = "otzaria.original.two-full-apps.inputs.v2"
PRIVATE_BUILD_ROOT = Path("/Users/m1/builds")
PRODUCTION_SCHEMA = "otzaria.original.two-full-apps.production.v1"
RELEASE_ID = 455390662
CORPUS_BYTES = 4_355_063_808
CORPUS_SHA256 = "8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01"
GROUP = "group.com.davidpovarsky.itorah"
INSTALL_TIMEOUT = 3_900  # Original production installer: 3600 + launch90 + terminate60.
SOURCE_KEYS = ("checkout_sha", "application_source_sha", "application_trees")


def witness(path):
    path = Path(path)
    require(path.is_absolute() and path.resolve(strict=True) == path
            and path.is_file() and not path.is_symlink(), "Redirected evidence input")
    return {"path": str(path), "bytes": path.stat().st_size, "sha256": digest(path)}


def reject_fixture_overrides(environment):
    forbidden = ("OTZARIA_ORIGINAL_EDITOR_QUALIFICATION", "OTZARIA_ORIGINAL_EDITOR_PROCESS_RESUME",
                 "OTZARIA_SHARED_ROOT_OVERRIDE", "OTZARIA_PRODUCTION_DB_PATH",
                 "OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE", "STUDY_WORKSPACE_TESTING_NAMESPACE",
                 "SMOKE_SCENARIO", "FAITHFUL_VIEWPORT_DIRECTORY",
                 "OTZARIA_ANNOTATION_ACCEPTANCE_DATABASE")
    for key, value in environment.items():
        require(not any(key.endswith(name) for name in forbidden), "An inherited test override is forbidden")
        if key.endswith("OTZARIA_DATA_PROFILE"):
            require(value == "production", "The paired route must use production")


def original_contracts():
    import runpy
    ci = ROOT / "Scripts/CI"
    return {name: runpy.run_path(str(ci / filename)) for name, filename in {
        "local": "production-annotation-native.py",
        "exchange": "ordinary-native-exchange-ui.py",
        "v40": "library-v40-focused-native.py",
        "containers": "miniapps-simulator-containers.py",
    }.items()}


def validate_product_files(records, images):
    require(type(records) is list and bool(records), "A complete original product-image closure is required")
    expected = {str(ROOT / relative): {"path": str(ROOT / relative), **value}
                for relative, value in images.items()}
    observed = {}
    for record in records:
        path = check_pin(record)
        require(str(path) not in observed, "Duplicate product image")
        observed[str(path)] = record
    require(observed == expected, "Product images differ from the original complete built-image closure")
    return expected


def bind_xctestrun(test_run, app):
    products = ROOT / "build/DerivedData/Build/Products"
    require(test_run.parent == products and test_run.suffix == ".xctestrun",
            "Use the original xctestrun beside the qualified build products")
    runner = products / "Debug-iphonesimulator/Maktabah-iOSUITests-Runner.app"
    bundle = runner / "PlugIns/Maktabah-iOSUITests.xctest"
    value = plistlib.loads(test_run.read_bytes())
    targets = []

    def collect(node, label=""):
        if isinstance(node, dict):
            if "TestBundlePath" in node:
                targets.append((label, node))
            for key, child in node.items():
                collect(child, key if isinstance(child, dict) else label)
        elif isinstance(node, list):
            for child in node:
                collect(child, label)
    collect(value)
    matches = [(label, target) for label, target in targets
               if "Maktabah-iOSUITests" in {label, target.get("BlueprintName"), target.get("TestTargetName")}]
    require(len(matches) == 1, "Require one original UI test target/configuration")
    target = matches[0][1]
    require(target.get("IsUITestBundle") is True, "The paired selector must belong to the real UI runner")

    def resolve(raw, host=None, allow_platform=False):
        require(isinstance(raw, str) and raw and "\x00" not in raw
                and ".." not in Path(raw).parts, "Malformed xctestrun product reference")
        if raw.startswith("__PLATFORMS__/") and allow_platform:
            require(raw.count("__PLATFORMS__") == 1 and "__TEST" not in raw,
                    "Ambiguous platform reference")
            return raw
        expanded = raw.replace("__TESTROOT__", str(products))
        if host is not None:
            expanded = expanded.replace("__TESTHOST__", str(host))
        require("__" not in expanded, "Unresolved xctestrun product placeholder")
        path = Path(expanded)
        require(path.is_absolute() and path.exists() and path.resolve(strict=True) == path
                and path.is_relative_to(products), "XCTest product escapes the actual built products")
        return str(path)

    host = resolve(target.get("TestHostPath"))
    actual_bundle = resolve(target.get("TestBundlePath"), host)
    target_app = resolve(target.get("UITargetAppPath"), host)
    require((host, actual_bundle, target_app) == (str(runner), str(bundle), str(app)),
            "xctestrun app, test host or test bundle differs from the qualified product")
    references = []

    def inspect(node):
        if isinstance(node, dict):
            for key, child in node.items():
                if key in {"EnvironmentVariables", "TestingEnvironmentVariables"}:
                    require(type(child) is dict, "Malformed XCTest environment")
                    reject_fixture_overrides(child)
                if key in {"CommandLineArguments", "TestHostArguments", "UITargetAppArguments"}:
                    require(type(child) is list and all(isinstance(x, str) for x in child),
                            "Malformed XCTest arguments")
                    require(not any("smokeScenario" in x or "studyWorkspaceTestingNamespace" in x
                                    or "miniTest10" in x or "OTZARIA_SHARED_ROOT_OVERRIDE" in x
                                    for x in child), "Fixture launch arguments remain in xctestrun")
                if key in {"TestBundlePath", "TestHostPath", "UITargetAppPath", "ProductPath"}:
                    references.append(resolve(child, host))
                elif key == "DependentProductPaths":
                    require(type(child) is list and child, "Missing original dependent products")
                    references.extend(resolve(x, host, allow_platform=True) for x in child)
                else:
                    inspect(child)
        elif isinstance(node, list):
            for child in node:
                inspect(child)
    inspect(target)
    return {"xctestrun": witness(test_run), "test_host": host, "test_bundle": actual_bundle,
            "target_app": target_app, "references": sorted(set(references))}


def admitted_context(inputs, contracts):
    require(inputs.get("schema") == INPUT_SCHEMA, "Require source-bound production input schema v2")
    reject_fixture_overrides(os.environ)
    require(os.environ.get("OTZARIA_NATIVE_SPACE_ARCHIVE_LEASE") == "ordinary-ui-exclusive",
            "The original peer CAS owner must release the Space's Archive tree")
    require(os.environ.get("OTZARIA_ANYTYPE_NETWORK_FIXTURE_ROOT") == inputs["networkFixtureRoot"],
            "The original fixture root must be explicitly bound to this run")
    source = contracts["local"]["source_context"]()
    require(inputs["source"] == {key: source[key] for key in SOURCE_KEYS},
            "Caller source identity differs from the original admitted checkout/application")
    v40 = contracts["v40"]
    v40_source = v40["source_context"](source["checkout_sha"], allow_build_projection=True)
    app = ROOT / "build/DerivedData/Build/Products/Debug-iphonesimulator/Maktabah.app"
    require(Path(inputs["app"]) == app and app.resolve(strict=True) == app, "Wrong original built app")
    build = v40["qualified_build_context"](app)
    build_receipt = check_pin(inputs["buildReceipt"])
    require(build_receipt == ROOT / "build/hq-stage2/result.json"
            and witness(build_receipt) == build["build_receipt"], "Unbound original build receipt")
    parsed_build = json.loads(build_receipt.read_bytes())
    info = plistlib.loads((app / "Info.plist").read_bytes())
    require(info.get("CFBundleIdentifier") == BUNDLE and info.get("UIFileSharingEnabled") is True
            and info.get("OtzariaDefaultDataProfile") == "production"
            and parsed_build.get("simulator_embedded_data_profile") == "production"
            and parsed_build.get("built_app_info_sha256") == digest(app / "Info.plist"),
            "Require the actual original app built with embedded production defaults")
    fixture = check_pin(inputs["fixtureHelper"])
    require(fixture == ROOT / "Scripts/CI/prepare-faithful-ipad-fixtures.py",
            "Require the unchanged original native installer helper")
    images = validate_product_files(inputs["productFiles"], build["complete_native_images"])
    test_run = check_pin(inputs["xctestrun"])
    test_binding = bind_xctestrun(test_run, app)
    network = contracts["exchange"]["network_fixture"]()
    require(network.get("root") == inputs["networkFixtureRoot"], "Original network fixture was not admitted")
    pointer = check_pin(inputs["networkFixturePointer"])
    require(pointer == Path(network["root"]) / "source-pointer.json"
            and digest(pointer) == network["pointer_sha256"], "Original fixture pointer changed")
    config = check_pin(inputs["networkConfiguration"]) if "networkConfiguration" in inputs else None
    run("codesign", "--verify", "--deep", "--strict", app)
    release, manifest, statistics, provenance = v40["metadata_context"]()
    return {"source": source, "v40_source": v40_source, "build": build, "product_files": images,
            "xctestrun_binding": test_binding, "fixture_helper": witness(fixture),
            "network_fixture": network, "network_configuration": witness(config) if config else None,
            "app_info": witness(app / "Info.plist"),
            "official_metadata": {name: witness(v40["METADATA"] / name) for name in
                ("v40_release.raw", v40["ARCHIVE"] + ".manifest.json", "library_stats.json", "build_provenance.json")}}


def owned_container(udid, contracts):
    # This is the existing original MCM reader, used to independently corroborate
    # the normal simctl result. It never creates a substitute container.
    require(str(uuid.UUID(udid)).upper() == udid and udid != PROTECTED, "Invalid owned simulator")
    path = Path(run("xcrun", "simctl", "get_app_container", udid, BUNDLE, "data", timeout=45))
    data = Path.home() / "Library/Developer/CoreSimulator/Devices" / udid / "data"
    original = contracts["containers"]
    observed = original["metadata_container"](data, "Containers/Data/Application", BUNDLE)
    require(path == observed, "Native simctl and actual Apple MCM data identity differ")
    return observed


def installed_images(udid, app, context, contracts):
    data = Path.home() / "Library/Developer/CoreSimulator/Devices" / udid / "data"
    installed, initial = contracts["containers"]["installed_app"](data, BUNDLE, app)
    result = {}
    for source, record in context["product_files"].items():
        source = Path(source)
        if source.is_relative_to(app):
            actual = installed / source.relative_to(app)
            record_actual = witness(actual)
            require(record_actual["sha256"] == record["sha256"]
                    and record_actual["bytes"] == record["bytes"], "Installed original native image changed")
            result[str(source.relative_to(app))] = {key: record_actual[key] for key in ("bytes", "sha256")}
    require(result, "No installed original image closure")
    return {"installed_app": str(installed), "native_images": result, "original_mcm_image_check": initial}


def production_observation(udid, directory, contracts):
    v40 = contracts["v40"]
    container = owned_container(udid, contracts)
    native_path = directory / "build/artifacts/production-native-fixture-install-11-reader.json"
    native = json.loads(native_path.read_bytes())
    require(native.get("passed") is True and native.get("profileID") == "production"
            and native.get("shaMatched") is True and native.get("bookCount") == 8259,
            "Original complete production installation was not observed")
    final = Path(native["finalPath"])
    require(final.is_absolute() and final.resolve(strict=True) == final, "Redirected production corpus")
    data = Path.home() / "Library/Developer/CoreSimulator/Devices" / udid / "data"
    require(final.is_relative_to(data), "Corpus belongs to another simulator")
    original = contracts["containers"]
    if final.is_relative_to(data / "Containers/Shared/AppGroup"):
        owner = original["metadata_container"](data, "Containers/Shared/AppGroup", GROUP)
        require(final == owner / "Otzaria/seforim.db", "Foreign or nonproduction App Group corpus")
    else:
        owner = container
        # This is the genuine Debug AppConfig.appSupportDir fallback, not an override.
        require(final == owner / "Library/Application Support/Maktabah-Debug/Otzaria/seforim.db",
                "Unexpected original production app fallback path")
    metadata_name = original["METADATA"]
    release, manifest, statistics, provenance = v40["metadata_context"]()
    corpus = v40["inspect_database"](final, statistics, provenance)
    require(corpus["database"]["bytes"] == CORPUS_BYTES
            and corpus["database"]["sha256"] == CORPUS_SHA256, "Actual full v40 bytes changed")
    installation_path = final.parent / "seforim-installation.json"
    installation = json.loads(installation_path.read_bytes())
    require(installation.get("releaseID") == RELEASE_ID
            and installation.get("repository") == "Otzaria/SeforimLibrary"
            and installation.get("assetID") == 782942035, "Original installed release identity differs")
    with sqlite3.connect(final.as_uri() + "?mode=ro&immutable=1", uri=True) as connection:
        rows = connection.execute("SELECT id,title FROM book WHERE id=103").fetchall()
    require(len(rows) == 1 and rows[0][0] == 103 and isinstance(rows[0][1], str) and rows[0][1],
            "Actual production Library target is missing")
    return {"schema": PRODUCTION_SCHEMA, "udid": udid, "bundle_id": BUNDLE, "profile": "production",
            "release_id": RELEASE_ID, "data_container": str(container),
            "documents_directory": str(container / "Documents"),
            "data_container_metadata": witness(container / metadata_name),
            "corpus_owner_container": str(owner), "corpus_owner_metadata": witness(owner / metadata_name),
            "installed_database": corpus["database"],
            "corpus": {"counts": corpus["counts"], "schema_meta": corpus["schema_meta"]},
            "installation_manifest": witness(installation_path), "install_receipt": witness(native_path),
            "target_book": {"book_id": rows[0][0], "title": rows[0][1]}}


def install_production(udid, directory, fixture_helper, inputs, contracts):
    v40 = contracts["v40"]
    reserve = inputs.get("reservedOtherBytes")
    require(type(reserve) is int and reserve >= 0, "An explicit concurrent growth estimate is required")
    required = v40["WORK_BYTES"] + v40["DEFAULT_OS_MARGIN_BYTES"] + reserve
    free = shutil.disk_usage(ROOT).free
    write(directory / "production-disk-admission.json", {
        "free_bytes": free, "required_bytes": required, "work_bytes": v40["WORK_BYTES"],
        "os_margin_bytes": v40["DEFAULT_OS_MARGIN_BYTES"], "reserved_other_bytes": reserve})
    require(free >= required, "Insufficient original full-v40 installation reserve")
    (directory / "sim_udid.txt").write_text(udid + "\n")
    command = [sys.executable, str(fixture_helper), "--profile", "production",
               "--release-id", str(RELEASE_ID), "--artifact-label", "11-reader"]
    write(directory / "production-installer-command.json", {"command": command, "timeout_seconds": INSTALL_TIMEOUT})
    with (directory / "library-fixture.log").open("w") as log:
        installed = subprocess.run(command, cwd=directory, stdout=log, stderr=subprocess.STDOUT,
                                   timeout=INSTALL_TIMEOUT)
    require(installed.returncode == 0, "Original production installation failed")
    result = production_observation(udid, directory, contracts)
    path = directory / "production-receipt.json"
    write(path, result)
    return result, witness(path)


def cleanup_owned(owned):
    """Every owned device is attempted; one timeout never skips the other."""
    records = []
    valid = len(owned) == len(set(owned))
    for udid in owned:
        row = {"udid": udid, "steps": [], "deleted_verified_absent": False}
        records.append(row)
        try:
            require(str(uuid.UUID(udid)).upper() == udid and udid != PROTECTED,
                    "Refuse cleanup of a nonowned/protected simulator")
        except BaseException as error:
            row["ownership_error"] = type(error).__name__
            valid = False
            continue
        for operation in ("shutdown", "delete"):
            step = {"operation": operation}
            row["steps"].append(step)
            try:
                value = subprocess.run(["xcrun", "simctl", operation, udid], capture_output=True, timeout=90)
                step["exit"] = value.returncode
                # Exact native cleanup output remains in this private receipt.
                step["stdout_base64"] = base64.b64encode(value.stdout).decode("ascii")
                step["stderr_base64"] = base64.b64encode(value.stderr).decode("ascii")
                step["stdout_sha256"] = hashlib.sha256(value.stdout).hexdigest()
                step["stderr_sha256"] = hashlib.sha256(value.stderr).hexdigest()
                if operation == "delete" and value.returncode != 0:
                    valid = False
            except BaseException as error:
                step["error_type"] = type(error).__name__
                if isinstance(error, subprocess.TimeoutExpired):
                    step["timeout_seconds"] = error.timeout
                    for key in ("stdout", "stderr"):
                        raw = getattr(error, key) or b""
                        if isinstance(raw, str):
                            raw = raw.encode("utf-8")
                        step[key + "_base64"] = base64.b64encode(raw).decode("ascii")
                valid = False
        try:
            devices = json.loads(run("xcrun", "simctl", "list", "devices", "-j", timeout=45))["devices"]
            present = any(item.get("udid") == udid for group in devices.values() for item in group)
            data_root = Path.home() / "Library/Developer/CoreSimulator/Devices" / udid
            row["deleted_verified_absent"] = not present and not data_root.exists()
            valid = valid and row["deleted_verified_absent"]
        except BaseException as error:
            row["verification_error"] = type(error).__name__
            valid = False
    return {"passed": valid, "devices": records}


def retain_original_storage(directory, actual):
    database = Path(actual["container"]) / "Library/Application Support/Maktabah-Debug/Annotations.sqlite"
    with sqlite3.connect(database.as_uri() + "?mode=ro", uri=True) as source:
        require(source.execute("PRAGMA quick_check").fetchone() == ("ok",), "The actual local SQLite is inconsistent")
        with sqlite3.connect(directory / "observed-annotations.sqlite") as retained:
            source.backup(retained)
        rows = source.execute("SELECT id FROM annotations WHERE lower(ckRecordId)=lower(?)",
                              (actual["annotationUUID"],)).fetchall()
        require(rows == [(actual["rowID"],)], "Actual original import/receive created a duplicate annotation")
        locations = source.execute("SELECT backendLocator FROM annotations WHERE id=?",
                                   (actual["rowID"],)).fetchall()
        require(len(locations) == 1 and isinstance(locations[0][0], str),
                "The original saved note has no actual source locator")
        locator = json.loads(locations[0][0])
        require(locator == actual["actualSavedNoteSource"] and locator.get("backend") == "otzaria"
                and locator.get("workKey") == "book:103", "Saved note is not anchored to the actual production book")
        versions = source.execute("""SELECT v.revision,v.payload_digest,v.payload_base64
            FROM otzaria_annotation_exchange_heads h
            JOIN otzaria_annotation_exchange_versions v
            ON v.namespace=h.namespace AND v.annotation_uuid=h.annotation_uuid AND v.revision=h.revision
            WHERE h.namespace='otzaria.local.annotation' AND lower(h.annotation_uuid)=lower(?)""",
            (actual["annotationUUID"],)).fetchall()
        require(len(versions) == 1, "Require one current saved original rich version")
        revision, payload_digest, encoded = versions[0]
        payload = base64.b64decode(encoded, validate=True)
        envelope = json.loads(payload)
        rich = envelope["richBody"]
        body = base64.b64decode(rich["bytesBase64"], validate=True)
        require(revision == actual["revision"]
                and hashlib.sha256(payload).hexdigest() == payload_digest == actual["payloadSHA256"]
                and rich["format"] == "anytype.native-protobuf-archive"
                and hashlib.sha256(body).hexdigest() == actual["bodySHA256"],
                "The independent original SQLite/body read differs from the UI observation")
    (directory / "observed-original-rich-body.bin").write_bytes(body)
    write(directory / "independent-storage.json", {
        "sqliteOpenMode": "read-only", "annotationRowsForUUID": len(rows), "revision": revision,
        "retainedSQLiteSHA256": digest(directory / "observed-annotations.sqlite"),
        "originalRichBodySHA256": hashlib.sha256(body).hexdigest(), "payloadSHA256": payload_digest})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--inputs", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    arguments = parser.parse_args()
    require(sys.platform == "darwin" and os.environ.get("GITHUB_ACTIONS") != "true",
            "This private original-account acceptance belongs on the owned Apple host")
    require(arguments.inputs.is_file() and arguments.inputs.stat().st_size <= 16 * 1024 * 1024,
            "A bounded original input manifest is required")
    inputs = json.loads(arguments.inputs.read_bytes())
    out = arguments.out.absolute()
    require(out.is_relative_to(PRIVATE_BUILD_ROOT) and out != PRIVATE_BUILD_ROOT and not out.exists()
            and out.resolve() == out, "Require a fresh canonical owned result directory")
    os.umask(0o077)
    out.mkdir(parents=True, mode=0o700)
    receipt = {"schema": "otzaria.original.two-full-apps.result.v1", "status": "RUNNING_NOT_ACCEPTED",
               "inputs": witness(arguments.inputs.absolute()), "replicas": {}, "phases": [],
               "controllerApplicationSQLiteWrites": 0, "accountMaterialReadByController": False,
               "nativeResponseAcknowledgementsModified": False, "dataProfile": "production"}
    write(out / "result.json", receipt)
    owned, contracts, before = [], None, None
    successful_phases = False
    try:
        contracts = original_contracts()
        before = admitted_context(inputs, contracts)
        write(out / "original-admission-before.json", before)
        app = Path(inputs["app"])
        test_run = Path(inputs["xctestrun"]["path"])
        fixture_helper = Path(inputs["fixtureHelper"]["path"])
        fixture_root = Path(inputs["networkFixtureRoot"])
        network_configuration = (Path(inputs["networkConfiguration"]["path"])
                                 if "networkConfiguration" in inputs else None)
        # The recovery key is never opened by this controller. Only the original
        # XCTest login helper reads it and uses the original expiring Paste.
        info = plistlib.loads((app / "Info.plist").read_bytes())
        display_name = info["CFBundleDisplayName"]
        localized = app / "en.lproj/InfoPlist.strings"
        if localized.exists():
            display_name = plistlib.loads(localized.read_bytes()).get("CFBundleDisplayName", display_name)
        devices = json.loads(run("xcrun", "simctl", "list", "devicetypes", "-j"))["devicetypes"]
        device_type = next(x["identifier"] for x in devices if x["name"] == "iPad Pro 11-inch (M5)")
        runtimes = json.loads(run("xcrun", "simctl", "list", "runtimes", "-j"))["runtimes"]
        sdk = run("xcrun", "--sdk", "iphonesimulator", "--show-sdk-version")
        selected = [x for x in runtimes if x.get("isAvailable")
                    and x["identifier"] == inputs["runtimeIdentifier"]
                    and x["version"] == inputs["runtimeVersion"]
                    and x["version"].split(".")[:2] == sdk.split(".")[:2]
                    and x["version"].split(".")[0] == "27"]
        require(len(selected) == 1 and device_type in
                {item["identifier"] for item in selected[0]["supportedDeviceTypes"]},
                "Require the explicit original SDK-matched supported iPad runtime")
        runtime = selected[0]["identifier"]
        receipt["runtime"] = {"sdk": sdk, "runtime": selected[0], "deviceType": device_type}
        for replica in ["A", "B"]:
            directory = out / ("replica-" + replica)
            directory.mkdir(mode=0o700)
            udid = run("xcrun", "simctl", "create", "Otzaria original full peer " + replica + " " + str(uuid.uuid4()),
                       device_type, runtime)
            require(str(uuid.UUID(udid)).upper() == udid and udid != PROTECTED, "Require a fresh disposable app replica")
            owned.append(udid)
            write(directory / "ownership.json", {"udid": udid, "createdForThisRun": True})
            run("xcrun", "simctl", "boot", udid)
            run("xcrun", "simctl", "bootstatus", udid, "-b", timeout=240)
            run("xcrun", "simctl", "install", udid, app)
            container = owned_container(udid, contracts)
            if network_configuration is not None:
                document = container / "Documents/otzaria-original-anysync.yaml"
                document.parent.mkdir(exist_ok=True)
                require(not document.exists(), "The new app must have no prior configuration document")
                shutil.copy2(network_configuration, document)
                require(digest(document) == inputs["networkConfiguration"]["sha256"], "Client configuration transfer changed bytes")
            production, production_pin = install_production(udid, directory, fixture_helper, inputs, contracts)
            images = installed_images(udid, app, before, contracts)
            receipt["replicas"][replica] = {
                "udid": udid, "initialContainer": str(container), "production": production,
                "productionReceipt": production_pin, "installedImagesBefore": images}
            write(out / "result.json", receipt)
        require(len(set(owned)) == 2, "Two distinct complete app installations are mandatory")

        def phase(name, replica, operation, *, local=None, remote=None, copied_export=None, reimport=False):
            state = receipt["replicas"][replica]
            udid = state["udid"]
            container = owned_container(udid, contracts)
            require(str(container) == state["production"]["data_container"],
                    "The original production container changed before a phase")
            check_pin(state["productionReceipt"])
            require(installed_images(udid, app, before, contracts) == state["installedImagesBefore"],
                    "The actual installed app changed before a phase")
            directory = out / "phases" / name
            directory.mkdir(parents=True, mode=0o700)
            case_input = {"schema": "otzaria.original.two-full-apps.phase-input.v1",
                          "phase": operation, "replica": replica}
            if local is not None:
                case_input["local"] = local
            if remote is not None:
                case_input["remote"] = remote
            if copied_export is not None:
                source = Path(copied_export["exportPath"])
                require(source.name == "maktabah_annotations.json"
                        and digest(source) == copied_export["exportSHA256"], "The actual UI export changed")
                destination = container / "Documents" / source.name
                destination.parent.mkdir(exist_ok=True)
                require(not destination.exists(), "Do not overwrite any app document")
                shutil.copy2(source, destination)
                require(digest(destination) == copied_export["exportSHA256"], "Export transfer changed bytes")
                case_input["exportFilename"] = source.name
                write(directory / "original-json-file-transfer.json", {
                    "source": str(source), "destination": str(destination),
                    "sha256": digest(destination), "transformation": "none", "sqliteWrites": 0})
            if reimport:
                case_input["reimportFilename"] = "maktabah_annotations.json"
            write(directory / "input.json", case_input)
            environment = os.environ.copy()
            environment.update({
                "TEST_RUNNER_OTZARIA_ORDINARY_PRODUCTION_RECEIPT": state["productionReceipt"]["path"],
                "TEST_RUNNER_OTZARIA_ORDINARY_PRODUCTION_RECEIPT_SHA256": state["productionReceipt"]["sha256"],
                "TEST_RUNNER_OTZARIA_ANYTYPE_NETWORK_UI": "test-owned-original-account",
                "TEST_RUNNER_OTZARIA_ANYTYPE_NETWORK_FIXTURE_ROOT": str(fixture_root),
                "TEST_RUNNER_OTZARIA_ANYTYPE_PAIRED_PHASE_ROOT": str(directory),
                "TEST_RUNNER_OTZARIA_ANYTYPE_PAIRED_APP_NAME": display_name})
            if network_configuration is not None:
                environment["TEST_RUNNER_OTZARIA_ANYTYPE_NETWORK_CONFIGURATION_FILENAME"] = "otzaria-original-anysync.yaml"
            command = ["xcodebuild", "test-without-building", "-xctestrun", str(test_run),
                       "-parallel-testing-enabled", "NO", "-destination", "platform=iOS Simulator,id=" + udid,
                       "-resultBundlePath", str(directory / "Native.xcresult"),
                       "-test-timeouts-enabled", "YES", "-default-test-execution-time-allowance", "900",
                       "-maximum-test-execution-time-allowance", "900", "-only-testing:" + SELECTOR]
            write(directory / "actual-command.json", command)
            # Authentication UI logs and xcresult remain in the private owned
            # directory. They must not be printed or uploaded by this controller.
            with (directory / "actual-xctest-private.log").open("w") as log:
                completed = subprocess.run(command, env=environment, stdout=log, stderr=subprocess.STDOUT, timeout=1200)
            summary = json.loads(run("xcrun", "xcresulttool", "get", "test-results", "summary",
                                     "--path", directory / "Native.xcresult"))
            write(directory / "actual-summary.json", summary)
            observed = {"name": name, "replica": replica, "selector": SELECTOR, "appleExit": completed.returncode,
                        "passedTests": summary.get("passedTests"), "failedTests": summary.get("failedTests"),
                        "skippedTests": summary.get("skippedTests")}
            receipt["phases"].append(observed)
            write(out / "result.json", receipt)
            require(completed.returncode == 0 and summary.get("passedTests") == 1
                    and summary.get("failedTests") == 0 and summary.get("skippedTests") == 0,
                    "A genuine full-app UI phase failed; retain its actual Apple result")
            actual = json.loads((directory / "actual-ui-result.json").read_bytes())
            require(actual["schema"] == "otzaria.original.two-full-apps.phase-result.v1"
                    and actual["replica"] == replica and actual["phase"] == operation
                    and Path(actual["container"]) == owned_container(udid, contracts) == container
                    and actual.get("dataProfile") == "production"
                    and actual.get("productionReceiptSHA256") == state["productionReceipt"]["sha256"]
                    and actual.get("targetBookID") == 103
                    and actual["productionWorkspace"].get("workKey") == "book:103"
                    and actual["productionWorkspace"].get("path") ==
                        str(container / "Library/Application Support/ChavrusaText/StudyWorkspace/workspace-v1.json")
                    and all(isinstance(actual["productionWorkspace"].get(key), str)
                            and actual["productionWorkspace"][key] for key in ("profile", "group", "document"))
                    and actual.get("actualSavedNoteSource")
                    and actual["sqliteOpenMode"] == "read-only"
                    and actual["nativeResponseRemoteDeviceAcknowledgement"] is False,
                    "The actual UI evidence is not bound to this app phase")
            observed["resultSHA256"] = digest(directory / "actual-ui-result.json")
            retain_original_storage(directory, actual)
            write(out / "result.json", receipt)
            return actual

        first = phase("01-a-create", "A", "create-and-export")
        second = phase("02-b-receive-edit", "B", "import-receive-update", remote=first, copied_export=first)
        third = phase("03-a-receive-edit", "A", "receive-update", local=first, remote=second)
        fourth = phase("04-b-receive-final", "B", "receive-final", local=second, remote=third, reimport=True)
        fifth = phase("05-a-receive-final", "A", "receive-final", local=third, remote=fourth)
        results = [first, second, third, fourth, fifth]
        require(len({x["annotationUUID"] for x in results}) == 1
                and len({x["objectID"] for x in results}) == 1,
                "Exchange changed the original UUID or native object identity")
        require(fourth["secondText"] == fifth["secondText"]
                and "saved-by-full-app-B-" in fifth["secondText"]
                and "saved-by-full-app-A-" in fifth["secondText"]
                and fourth["preview"] == fifth["preview"]
                and fourth["bodySHA256"] == fifth["bodySHA256"],
                "The two actual apps did not converge on the same complete original rich body")
        require(all(x["actualOrdinaryReceiveAndColdReopen"] for x in results[1:]),
                "Every received version must cold-reopen in the complete app")
        successful_phases = True
        receipt.update(status="PHASES_PASSED_FINAL_ADMISSION_AND_CLEANUP_PENDING", annotationUUID=fifth["annotationUUID"],
                       nativeObjectID=fifth["objectID"], convergedOriginalBodySHA256=fifth["bodySHA256"],
                       completeAppReplicas=2, verifiedDirectionCount=2, repeatedJSONImportPreservedRichVersion=True)
    except BaseException as error:
        receipt.update(status="FAILED", primaryErrorType=type(error).__name__)
        (out / "primary-failure-private.log").write_text(traceback.format_exc())
    finally:
        final_failures = []
        try:
            if before is not None:
                try:
                    after = admitted_context(inputs, contracts)
                    write(out / "original-admission-after.json", after)
                    require(after == before, "Original source, build, images or fixture changed during acceptance")
                except BaseException as error:
                    final_failures.append({"stage": "original-final-admission", "errorType": type(error).__name__})
                    (out / "final-admission-failure-private.log").write_text(traceback.format_exc())
                for replica, state in receipt["replicas"].items():
                    try:
                        directory = out / ("replica-" + replica)
                        check_pin(state["productionReceipt"])
                        observed = production_observation(state["udid"], directory, contracts)
                        write(directory / "production-after.json", observed)
                        require(observed == state["production"], "Installed original full v40 corpus/owner changed")
                        images = installed_images(state["udid"], app, before, contracts)
                        state["installedImagesAfter"] = images
                        require(images == state["installedImagesBefore"], "Installed original app images changed")
                    except BaseException as error:
                        final_failures.append({"stage": "replica-" + replica, "errorType": type(error).__name__})
                        (out / ("replica-" + replica + "-final-failure-private.log")).write_text(traceback.format_exc())
        except BaseException as error:
            final_failures.append({"stage": "retain-final-evidence", "errorType": type(error).__name__})
        finally:
            cleanup = cleanup_owned(owned)
        receipt["finalAdmissionFailures"] = final_failures
        receipt["ownedSimulatorCleanup"] = cleanup
        success = (successful_phases and "primaryErrorType" not in receipt
                   and not final_failures and cleanup["passed"] and len(owned) == 2)
        receipt["status"] = "PASS_TWO_FULL_ORIGINAL_APPS_BIDIRECTIONAL_SYNC" if success else "FAILED"
        write(out / "result.json", receipt)
    print(json.dumps({"status": receipt["status"], "phases": len(receipt["phases"]), "evidence": str(out)}))
    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(main())
