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
    path = Path(record["path"])
    require(path.is_absolute() and path.is_file() and not path.is_symlink()
            and digest(path) == record["sha256"], "A retained build or fixture input changed")
    return path


def retain_original_storage(directory, actual):
    database = Path(actual["container"]) / "Library/Application Support/Maktabah-Debug/Annotations.sqlite"
    with sqlite3.connect(database.as_uri() + "?mode=ro", uri=True) as source:
        require(source.execute("PRAGMA quick_check").fetchone() == ("ok",), "The actual local SQLite is inconsistent")
        with sqlite3.connect(directory / "observed-annotations.sqlite") as retained:
            source.backup(retained)
        rows = source.execute("SELECT id FROM annotations WHERE lower(ckRecordId)=lower(?)",
                              (actual["annotationUUID"],)).fetchall()
        require(rows == [(actual["rowID"],)], "Actual original import/receive created a duplicate annotation")
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
    inputs = json.loads(arguments.inputs.read_bytes())
    require(inputs["schema"] == "otzaria.original.two-full-apps.inputs.v1", "Unknown input schema")
    out = arguments.out.absolute()
    require(str(out).startswith("/Users/m1/builds/") and not out.exists(), "Require a fresh owned result directory")
    out.mkdir(parents=True, mode=0o700)
    require(out.resolve() == out, "The paired evidence directory cannot be redirected")
    os.umask(0o077)
    app = Path(inputs["app"])
    test_run = check_pin(inputs["xctestrun"])
    fixture_helper = check_pin(inputs["fixtureHelper"])
    build_receipt = check_pin(inputs["buildReceipt"])
    for item in inputs["productFiles"]:
        check_pin(item)
    require(app.is_dir() and (app / "Maktabah").is_file(), "Require the complete real Otzaria app")
    run("codesign", "--verify", "--deep", "--strict", app)
    info = plistlib.loads((app / "Info.plist").read_bytes())
    require(info["CFBundleIdentifier"] == BUNDLE and info.get("UIFileSharingEnabled") is True,
            "The original app's normal Files integration is required")
    display_name = info["CFBundleDisplayName"]
    localized = app / "en.lproj/InfoPlist.strings"
    if localized.exists():
        display_name = plistlib.loads(localized.read_bytes()).get("CFBundleDisplayName", display_name)
    fixture_root = Path(inputs["networkFixtureRoot"])
    pointer = check_pin(inputs["networkFixturePointer"])
    require(pointer.parent == fixture_root and pointer.name == "source-pointer.json",
            "Require the preserved original account fixture pointer")
    # The recovery key is intentionally never opened by this controller. Only
    # the existing XCTest original-login helper reads it and uses expiring Paste.
    receipt = {"schema": "otzaria.original.two-full-apps.result.v1", "status": "RUNNING",
               "inputsSHA256": digest(arguments.inputs), "buildReceiptSHA256": digest(build_receipt),
               "source": inputs["source"], "replicas": {}, "phases": [],
               "controllerSQLiteWrites": 0, "accountMaterialReadByController": False,
               "nativeResponseAcknowledgementsModified": False}
    write(out / "result.json", receipt)
    owned = []
    try:
        devices = json.loads(run("xcrun", "simctl", "list", "devicetypes", "-j"))["devicetypes"]
        device_type = next(x["identifier"] for x in devices if x["name"] == "iPad Pro 11-inch (M5)")
        runtimes = json.loads(run("xcrun", "simctl", "list", "runtimes", "-j"))["runtimes"]
        runtime = next(x["identifier"] for x in runtimes if x.get("isAvailable") and x["version"] == inputs["runtimeVersion"])
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
            container = Path(run("xcrun", "simctl", "get_app_container", udid, BUNDLE, "data"))
            require(udid in container.parts, "The app container must belong to its independent simulator")
            (directory / "sim_udid.txt").write_text(udid + "\n")
            with (directory / "library-fixture.log").open("w") as log:
                installed = subprocess.run([sys.executable, str(fixture_helper), "--artifact-label", "11-reader"],
                    cwd=directory, stdout=log, stderr=subprocess.STDOUT, timeout=240)
            require(installed.returncode == 0, "The retained original read-only library fixture failed verification")
            receipt["replicas"][replica] = {"udid": udid, "initialContainer": str(container)}
            write(out / "result.json", receipt)
        require(len(set(owned)) == 2, "Two distinct complete app installations are mandatory")

        def phase(name, replica, operation, *, local=None, remote=None, copied_export=None, reimport=False):
            state = receipt["replicas"][replica]
            udid = state["udid"]
            container = Path(run("xcrun", "simctl", "get_app_container", udid, BUNDLE, "data"))
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
                "TEST_RUNNER_FAITHFUL_VIEWPORT_DIRECTORY": str(container / "Documents"),
                "TEST_RUNNER_OTZARIA_ANNOTATION_ACCEPTANCE_DATABASE": str(container / "Library/Application Support/Maktabah-Debug/Annotations.sqlite"),
                "TEST_RUNNER_OTZARIA_ANYTYPE_NETWORK_UI": "test-owned-original-account",
                "TEST_RUNNER_OTZARIA_ANYTYPE_NETWORK_FIXTURE_ROOT": str(fixture_root),
                "TEST_RUNNER_OTZARIA_ANYTYPE_PAIRED_PHASE_ROOT": str(directory),
                "TEST_RUNNER_OTZARIA_ANYTYPE_PAIRED_APP_NAME": display_name})
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
                                     "--path", directory / "Native.xcresult", "--format", "json"))
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
                    and udid in Path(actual["container"]).parts
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
        receipt.update(status="PASS_TWO_FULL_ORIGINAL_APPS_BIDIRECTIONAL_SYNC", annotationUUID=fifth["annotationUUID"],
                       nativeObjectID=fifth["objectID"], convergedOriginalBodySHA256=fifth["bodySHA256"],
                       completeAppReplicas=2, verifiedDirectionCount=2, repeatedJSONImportPreservedRichVersion=True)
    except BaseException as error:
        receipt.update(status="FAILED", errorType=type(error).__name__)
        raise
    finally:
        cleanup = []
        for udid in owned:
            require(udid != PROTECTED, "Never mutate the retained 5000-note simulator")
            stopped = subprocess.run(["xcrun", "simctl", "shutdown", udid], capture_output=True, timeout=90)
            deleted = subprocess.run(["xcrun", "simctl", "delete", udid], capture_output=True, timeout=90)
            cleanup.append({"udid": udid, "shutdownExit": stopped.returncode, "deleteExit": deleted.returncode})
        receipt["ownedSimulatorCleanup"] = cleanup
        write(out / "result.json", receipt)
    print(json.dumps({"status": receipt["status"], "phases": len(receipt["phases"]), "evidence": str(out)}))


if __name__ == "__main__":
    main()
