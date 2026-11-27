#!/usr/bin/env python3
"""Real original-account UI exchange; private raw artifacts, immutable read-only proof.

Run only after the exact SDK/app build is qualified and while the separate peer
CAS owner has released this test Space's shared Archive tree. This controller
reuses the original simulator matrix and its actual log/xcresult zero-skip gates.
It never reads a recovery key, writes application SQLite, supplies a body/account,
or turns a local native result into a remote-device acknowledgement.
"""
import base64
from contextlib import closing, redirect_stderr, redirect_stdout
import hashlib
import json
import os
import plistlib
import shutil
import subprocess
from pathlib import Path
import re
import runpy
import sqlite3
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
LOCAL = runpy.run_path(str(ROOT / "Scripts/CI/production-annotation-native.py"))
require, digest, write = (LOCAL[name] for name in ("require", "digest", "write"))
OUT = ROOT / "build/ordinary-native-exchange-private"
ARTIFACTS = ROOT / "build/artifacts"
SELECTION = OUT / "selection.json"
SUITE = "ProductionAnnotationEditorAcceptanceTests"
EXCHANGE = SUITE + "/testOrdinarySharedNoteUpdatesSameObjectAndReceivesSavedContent"
ROLES = ("chiddush", "article", "research")
SELECTORS = [EXCHANGE] + [
    SUITE + "/testOrdinaryNativeCopy" + role.title() + "LifecyclePreservesIdentity"
    for role in ROLES
]
GROUPS = [{"label": "11-reader", "size": "11", "hid_comparison": False, "case_ids": SELECTORS}]
PREFIX = "ORDINARY_NATIVE_EXCHANGE "
ACCOUNT = "AA5y2wipdZPPGiMoK3hckf6DUJQHHehNPt6BgyenPamSnfQm"
SPACE = "bafyreigdy7rjfil42wczgnam5njdwy5e2pcio23p2jls4ycgtzmp3usdqa.2xu9o61hnno0b"
PROTECTED_ROOT = "bafyreiarjeh5gi2eb6cespoglsvraum4ku226iainadbhfkncyvsavgadm"
FIELDS = {"stage", "annotation_id", "annotation_uuid", "revision", "payload_sha256",
          "native_body_sha256", "native_object_id", "remote_device_acknowledgement",
          "sqlite_open_mode", "qualification_mode"}
EXCHANGE_STAGES = ["ordinary-native-copy", "discard-remained-private", "same-object-update",
                   "received-and-cold-reopened"]
LIFECYCLE = ["annotation-archive", "annotation-restore", "{role}-promote",
             "{role}-replace-promoted-document", "{role}-archive", "{role}-restore",
             "annotation-revert-promotion"]
ALL_STAGES = set(EXCHANGE_STAGES)
for role in ROLES:
    ALL_STAGES.update(x.format(role=role) for x in LIFECYCLE)
    ALL_STAGES.add(role + "-lifecycle-cold")
EXPECTED_OBSERVATIONS = 4 + 3 * 9

def network_fixture():
    path = os.environ.get("OTZARIA_ANYTYPE_NETWORK_FIXTURE_ROOT")
    if path is None:
        return {"account_id": ACCOUNT, "space_id": SPACE, "object_id": PROTECTED_ROOT}
    root = Path(path)
    require(root.is_absolute() and root.resolve(strict=True) == root
            and root.is_dir() and root.stat().st_uid == os.getuid() and not root.stat().st_mode & 0o077,
            "The ordinary account must use a real, private, owned network fixture directory")

    receipt_pins = {}

    def receipt(relative):
        file = root / relative
        require(file.is_file() and not file.is_symlink()
                and file.resolve(strict=True).is_relative_to(root)
                and 0 < file.stat().st_size <= 4096,
                "Invalid original peer fixture receipt")
        raw = file.read_bytes()
        value = json.loads(raw)
        require(file.read_bytes() == raw, "Original fixture receipt changed during admission")
        receipt_pins[relative] = {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}
        return value

    original = receipt("source-pointer.json")
    account, space, protected = (original[key] for key in ("account_id", "space_id", "object_id"))
    require(re.fullmatch(r"[A-Za-z0-9]{20,180}", account)
            and re.fullmatch(r"[a-z0-9.]{20,180}", space)
            and re.fullmatch(r"b[a-z2-7]{20,160}", protected),
            "Original fixture metadata is invalid")
    reverse = receipt("reverse-pointer.json")
    require(all(reverse.get(key) == original[key] for key in ("account_id", "space_id", "object_id"))
            and reverse.get("block_id") != original.get("block_id")
            and hex256(original.get("text_sha256")) and hex256(reverse.get("text_sha256")),
            "The genuine peer revision must preserve the original identity")
    pids = set()
    for role in ("producer", "consumer"):
        readback = receipt(role + "-readback.json")
        stop = receipt("evidence/" + role + "/stop.json")
        pid = readback.get("pid")
        expected_body = reverse["text_sha256"] if role == "producer" else original["text_sha256"]
        require(readback.get("status") == "ACTUAL_ORIGINAL_REMOTE_BODY_READBACK"
                and readback.get("phase") == role and readback.get("lan_sync_disabled") is True
                and readback.get("same_account") == account and readback.get("same_space") == space
                and readback.get("same_object") == protected and readback.get("body_sha256") == expected_body
                and type(pid) is int and pid > 0 and pid not in pids
                and stop == {"returned": True, "application_absent": True},
                "Both original network processes must witness this fixture and stop")
        pids.add(pid)
    return {"account_id": account, "space_id": space, "object_id": protected,
            "root": str(root), "pointer_sha256": digest(root / "source-pointer.json"),
            "receipt_pins": receipt_pins}

SCHEMAS = {
    ".native-import-history": "otzaria.original.annotation.native-commit.v1",
    ".native-revision-history": "otzaria.original.annotation.revision-result.v1",
    ".native-lifecycle-history": "otzaria.original.annotation.lifecycle-result.v1",
}
CASE_NAMES = "|".join(re.escape(x.split("/", 1)[1]) for x in SELECTORS)
# Retain actual XCTest summary lines verbatim. All other unstructured UI output
# is suppressed: it may contain an original authentication field on failure.
SAFE_TEST_LINE = re.compile(
    r"^\s*Test Case '(?:-\[(?:[A-Za-z_]\w*\.)?" + SUITE + r" (?:" + CASE_NAMES
    + r")\]|(?:[A-Za-z_]\w*\.)?" + SUITE + r"\.(?:" + CASE_NAMES + r")\(\))' "
    r"(?:started\.|(?:passed|failed) \([0-9.]+ seconds\)\.)\s*$")
SAFE_SUITE_LINE = re.compile(
    r"^\s*Test Suite '(?:[A-Za-z_]\w*\.)?(?:"
    + SUITE + r"|Selected tests|All tests|Maktabah-iOSUITests\.xctest)' "
    r"(?:started|passed|failed) at [0-9: .+TZ-]+\.?\s*$")
SAFE_TOTAL_LINE = re.compile(
    r"^\s*Executed [0-9]+ tests?, with [0-9]+ failures? "
    r"(?:\([0-9]+ unexpected\) )?in [0-9.]+ \([0-9.]+\) seconds\s*$")


def private_route():
    require(sys.platform == "darwin", "This acceptance route must run on the real Apple host")
    require(os.environ.get("GITHUB_ACTIONS") != "true",
            "Raw original-account authentication results must not enter automatic CI uploads")
    require(os.environ.get("OTZARIA_NATIVE_SPACE_ARCHIVE_LEASE") == "ordinary-ui-exclusive",
            "Obtain the peer CAS owner's exclusive Archive phase before this UI run")
    for path in (OUT, ARTIFACTS, ARTIFACTS / "runtime27"):
        path.mkdir(parents=True, exist_ok=True)
        require(path.resolve() == path and path.stat().st_uid == os.getuid(),
                "Require original owned private artifact directories")
        path.chmod(0o700)



RUN_TOKEN_ENV = "OTZARIA_ORDINARY_EXCHANGE_RUN_TOKEN"


def claim_execution():
    """One actual run per prepared attempt; interrupted attempts stay retained."""
    require(not (OUT / "private-controller.log").exists()
            and not (OUT / "matrix-claim.json").exists(), "Retain the previous attempt before another run")
    token = str(uuid.uuid4())
    record = {"token": token, "parent_pid": os.getpid(), "source_receipt_sha256":
              digest(OUT / "source-before.json"), "selection_sha256": digest(SELECTION)}
    with (OUT / "run-claim.json").open("x") as stream:
        json.dump(record, stream, sort_keys=True)
        stream.write("\n")
    return token


def claim_matrix():
    """Direct or repeated matrix invocation cannot consume a prior attempt."""
    token = os.environ.get(RUN_TOKEN_ENV)
    require(isinstance(token, str) and str(uuid.UUID(token)) == token,
            "Only the one-use original controller may start the matrix")
    record = json.loads((OUT / "run-claim.json").read_text())
    require(record["token"] == token and record["parent_pid"] == os.getppid()
            and record["source_receipt_sha256"] == digest(OUT / "source-before.json")
            and record["selection_sha256"] == digest(SELECTION),
            "The matrix does not belong to this prepared parent execution")
    with (OUT / "matrix-claim.json").open("x") as stream:
        json.dump({"token": token, "pid": os.getpid(), "parent_pid": os.getppid()},
                  stream, sort_keys=True)
        stream.write("\n")


def context():
    return {**LOCAL["source_context"](), "original_network_fixture": network_fixture()}


def build_context():
    return LOCAL["qualified_build_context"]()


def prepare():
    private_route()
    require(not (OUT / "source-before.json").exists()
            and not (ARTIFACTS / "faithful-ipad-matrix.json").exists(),
            "Retain the previous attempt before starting another ordinary-account journey")
    source = context()
    contract = json.loads((ROOT / "docs/hq-integration/runtime27/R27_CASES.json").read_text())
    existing = {x["case_id"] for x in contract["cases"] + contract.get("supplemental_cases", [])}
    require(not existing.intersection(SELECTORS), "Dedicated cases must preserve Native116/Release114")
    for selector in SELECTORS:
        contract.setdefault("supplemental_cases", []).append({
            "case_id": selector, "device": "ipad11", "status": "NOT_RUN",
            "oracle": "Original ordinary UI and genuine account/Space; same root/UUID, exact saved SQLite body, native history and actual cold process reopen"})
    sha = source["application_source_sha"]
    contract.update(source_test_commit=sha, app_source=sha, application_source_sha=sha,
        execution_case_ids=SELECTORS, execution_groups=GROUPS,
        required_nonzero_cases=len(SELECTORS), native_cases_executed=0,
        expected_per_device={"ipad11": 4, "ipad13": 0, "iphone": 0},
        diagnostic_only=True, hid_comparison=False,
        scope="Separate original-account ordinary UI; no remote ACK, native5000 or full matrix credit")
    runpy.run_path(str(ROOT / "Scripts/CI/runtime27.py"))["execution_groups"](contract)
    declarations = runpy.run_path(str(ROOT / "Scripts/CI/verify-faithful-xctest.py"))[
        "validate_selections"](SELECTORS, ROOT / "Maktabah-iOSUITests")
    require(declarations["status"] == "DECLARATIONS_MATCH", "Actual XCTest methods are absent")
    write(OUT / "declarations.json", declarations)
    write(SELECTION, contract)
    write(OUT / "source-before.json", source)
    write(OUT / "qualified-build-before.json", build_context())
    write(OUT / "PRIVACY.json", {
        "raw_xcresult_and_authentication_artifacts": "PRIVATE_MAC_ONLY",
        "automatic_attachment_export": False, "automatic_CI_upload": False,
        "account_key_read_by_controller": False,
        "unstructured_test_output": "suppressed; actual XCTest status lines retained verbatim",
        "publication": "Only independently reviewed, bounded sanitized result documents"})


def b64(value):
    require(isinstance(value, str), "Missing actual encoded bytes")
    data = base64.b64decode(value, validate=True)
    require(base64.b64encode(data).decode("ascii") == value, "Noncanonical encoded bytes")
    return data


def hex256(value):
    return isinstance(value, str) and re.fullmatch("[0-9a-f]{64}", value) is not None


def validate_observation(value):
    require(type(value) is dict and set(value) == FIELDS, "Unexpected ordinary exchange fields")
    require(value["stage"] in ALL_STAGES and value["qualification_mode"] is False
            and value["remote_device_acknowledgement"] is False
            and value["sqlite_open_mode"] == "read-only", "Unexpected ordinary exchange scope")
    require(type(value["annotation_id"]) is int and value["annotation_id"] > 0
            and type(value["revision"]) is int and value["revision"] > 0,
            "Missing actual persistent note identity/revision")
    require(str(uuid.UUID(value["annotation_uuid"])).upper() == value["annotation_uuid"],
            "Noncanonical actual note UUID")
    require(hex256(value["payload_sha256"]) and hex256(value["native_body_sha256"]),
            "Missing original saved body digests")
    require(isinstance(value["native_object_id"], str)
            and re.fullmatch(r"b[a-z2-7]{20,160}", value["native_object_id"]) is not None
            and value["native_object_id"] != network_fixture()["object_id"],
            "Require a distinct UI-created original native root")


def verify_response(record):
    require(record.get("remoteDeviceAcknowledgement") is False,
            "Local native evidence cannot acknowledge a remote device")
    raw = b64(record.get("nativeResponseBytes"))
    require(0 < len(raw) <= 2 * 1024 * 1024
            and hashlib.sha256(raw).hexdigest() == record.get("nativeResponseSHA256"),
            "The original response bytes do not match their retained digest")


def verify_source(record, note, row, nested):
    source = record.get("source") if nested else record
    fixture = network_fixture()
    require(isinstance(source, dict)
            and source.get("namespace") == "otzaria.local.annotation"
            and source.get("annotationUUID") == note
            and source.get("savedRevision") == row["revision"]
            and source.get("payloadDigest") == row["payload_sha256"]
            and source.get("bodyDigest") == row["native_body_sha256"]
            and source.get("accountID") == fixture["account_id"] and source.get("spaceID") == fixture["space_id"]
            and record.get("objectID") == row["native_object_id"],
            "The retained native action is not bound to this exact saved note and original Space")
    verify_response(record)


class ExchangeEvidence:
    def __init__(self):
        self.udid = None
        self.captured = False
        self.copied_bytes = 0
        self.state = {"status": "NOT_REACHED", "observations": [], "history_files": [],
                      "qualification_mode": False, "original_sqlite_writes": 0,
                      "account_material_read": False, "body_or_identity_injected": False,
                      "remote_device_acknowledgement": False}

    def persist(self):
        write(OUT / "storage-observations.json", self.state)

    def validate_selection(self, baseline, release_manifest, selection):
        require(not baseline and release_manifest is None and selection == SELECTORS,
                "This callback belongs only to the four dedicated ordinary UI journeys")

    def stage(self, udid, container, label, selection):
        require(self.udid is None and label == "11-reader" and selection == SELECTORS,
                "Wrong owned simulator/selection")
        actual = LOCAL["owned_container"](udid)
        require(actual == Path(container).resolve(strict=True), "Original matrix container differs")
        self.udid = udid
        database = LOCAL["original_debug_database"](actual)
        self.state.update(status="ORIGINAL_LOCAL_FOLDER_OBSERVED", udid=udid,
                          initial_database_path=str(database))
        self.persist()
        # Only XCTest receives the observation path and an opt-in label.
        # The app receives no identity, credential, injected body or bypass.
        environment = {"TEST_RUNNER_OTZARIA_ANNOTATION_ACCEPTANCE_DATABASE": str(database),
                       "TEST_RUNNER_OTZARIA_ANYTYPE_NETWORK_UI": "test-owned-original-account"}
        root = network_fixture().get("root")
        if root is not None:
            environment["TEST_RUNNER_OTZARIA_ANYTYPE_NETWORK_FIXTURE_ROOT"] = root
        configuration = os.environ.get("OTZARIA_ANYTYPE_NETWORK_CONFIGURATION_PATH")
        if configuration is not None:
            original = Path(configuration)
            require(original.is_absolute() and original.is_file() and not original.is_symlink()
                    and 0 < original.stat().st_size <= 1024 * 1024
                    and digest(original) == os.environ.get("OTZARIA_ANYTYPE_NETWORK_CONFIGURATION_SHA256"),
                    "The original network configuration requires its exact witnessed source digest")
            destination = actual / "Documents/otzaria-original-anysync.yaml"
            require(not destination.exists(), "Retain an existing app document instead of overwriting it")
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(original, destination)
            require(digest(destination) == digest(original), "Original configuration transfer changed bytes")
            app_path = Path(subprocess.check_output([
                "xcrun", "simctl", "get_app_container", udid,
                "com.davidpovarsky.chavrusatext", "app"], text=True).strip())
            info = plistlib.loads((app_path / "Info.plist").read_bytes())
            environment["TEST_RUNNER_OTZARIA_ANYTYPE_PAIRED_APP_NAME"] = info.get("CFBundleDisplayName", info["CFBundleName"])
            environment["TEST_RUNNER_OTZARIA_ANYTYPE_NETWORK_CONFIGURATION_FILENAME"] = destination.name
            self.state["original_network_configuration"] = {
                "sha256": digest(destination), "transformation": "none", "selection": "original UI"}
            self.persist()
        return environment

    def redact_evidence(self, line):
        if PREFIX in line:
            require(line.count(PREFIX) == 1, "Ambiguous structured exchange observation")
            encoded = line.split(PREFIX, 1)[1].strip()
            require(len(encoded.encode()) <= 4096, "Oversized structured exchange observation")
            value = json.loads(encoded)
            validate_observation(value)
            prior = self.state["observations"]
            require(len(prior) < EXPECTED_OBSERVATIONS
                    and (value["annotation_uuid"], value["stage"]) not in {
                        (x["annotation_uuid"], x["stage"]) for x in prior},
                    "Repeated or excess actual UI observations")
            prior.append(value)
            self.persist()
            # Re-encoding only validated fixed fields prevents accidental log suffixes.
            return PREFIX + json.dumps(value, sort_keys=True) + "\n"
        if SAFE_TEST_LINE.fullmatch(line) or SAFE_SUITE_LINE.fullmatch(line) or SAFE_TOTAL_LINE.fullmatch(line):
            return line
        return ""

    def histories(self, database, note):
        result = {suffix: [] for suffix in SCHEMAS}
        for suffix, schema in SCHEMAS.items():
            parent = Path(str(database) + suffix) / note
            if not parent.exists():
                continue
            require(parent.resolve() == parent and parent.is_dir(), "Aliased original history")
            pending, visited = [parent], 0
            while pending:
                current = pending.pop()
                for path in sorted(current.iterdir()):
                    visited += 1
                    require(visited <= 160 and not path.is_symlink(), "Unbounded or aliased original history")
                    if path.is_dir():
                        pending.append(path)
                        continue
                    require(path.is_file() and path.suffix == ".json"
                            and path.stat().st_size <= 64 * 1024 * 1024, "Unexpected history file")
                    raw = path.read_bytes()
                    self.copied_bytes += len(raw)
                    require(self.copied_bytes <= 128 * 1024 * 1024, "History copy budget exceeded")
                    value = json.loads(raw)
                    relative = path.relative_to(parent)
                    dest = OUT / "retained-note-history" / note / suffix[1:] / relative
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    dest.write_bytes(raw)
                    self.state["history_files"].append({
                        "path": str(dest.relative_to(OUT)), "bytes": len(raw),
                        "sha256": hashlib.sha256(raw).hexdigest()})
                    if value.get("schema") == schema:
                        result[suffix].append(value)
        return result

    def capture(self, udid, label):
        require(udid == self.udid and label == "11-reader", "Wrong original capture request")
        if self.captured:
            return
        self.captured = True
        try:
            database = LOCAL["original_debug_database"](LOCAL["owned_container"](udid))
            require(database.is_file(), "Original annotation database is absent")
            observations = self.state["observations"]
            notes = {}
            for row in observations:
                notes.setdefault(row["annotation_uuid"], []).append(row)
            with closing(sqlite3.connect(database.as_uri() + "?mode=ro", uri=True, timeout=5)) as db:
                # A consistent private artifact copy preserves partial failure data.
                # The original connection remains read-only; this is no app write.
                with closing(sqlite3.connect(OUT / "retained-local-annotations.sqlite")) as retained:
                    db.backup(retained)
                require(db.execute("PRAGMA quick_check").fetchall() == [("ok",)],
                        "The real annotation database failed SQLite integrity")
                history = {note: self.histories(database, note) for note in notes}
                require(len(observations) == EXPECTED_OBSERVATIONS and len(notes) == 4,
                        "All four actual journeys and their 31 observations are required")
                kinds = []
                final = []
                for note, rows in notes.items():
                    stages = [x["stage"] for x in rows]
                    if stages == EXCHANGE_STAGES:
                        role = None
                        kinds.append("exchange")
                    else:
                        roles = [x for x in ROLES if stages ==
                            ["ordinary-native-copy"] + [s.format(role=x) for s in LIFECYCLE] + [x + "-lifecycle-cold"]]
                        require(len(roles) == 1, "Missing, reordered or repeated lifecycle steps")
                        role = roles[0]
                        kinds.append(role)
                    first, last = rows[0], rows[-1]
                    require(all(x["annotation_id"] == first["annotation_id"]
                                and x["native_object_id"] == first["native_object_id"] for x in rows),
                            "A journey changed the permanent local identity or native root")
                    initial = first["revision"]
                    wanted = ([initial, initial, initial + 1, initial + 2] if role is None
                              else [initial] * 4 + [initial + 1] * 5)
                    require([x["revision"] for x in rows] == wanted, "Unexpected local Save/Receive revisions")
                    for row in rows:
                        values = db.execute("""
                            SELECT v.payload_digest,v.payload_base64
                            FROM otzaria_annotation_exchange_versions v
                            WHERE v.namespace='otzaria.local.annotation'
                            AND lower(v.annotation_uuid)=lower(?) AND v.revision=?
                            """, (note, row["revision"])).fetchall()
                        require(len(values) == 1, "Exactly one immutable original version is required")
                        sha, encoded = values[0]
                        raw = b64(encoded)
                        require(hashlib.sha256(raw).hexdigest() == sha == row["payload_sha256"],
                                "Original SQLite envelope differs from the observed saved bytes")
                        envelope = json.loads(raw)
                        rich = envelope["richBody"]
                        body = b64(rich["bytesBase64"])
                        require(envelope.get("schemaVersion") == 1
                                and envelope.get("namespace") == "otzaria.local.annotation"
                                and str(uuid.UUID(envelope["annotationUUID"])).upper() == note
                                and envelope.get("deletionState") == "active"
                                and rich.get("format") == "anytype.native-protobuf-archive"
                                and rich.get("formatVersion") == 1 and len(body) > 16
                                and hashlib.sha256(body).hexdigest() == row["native_body_sha256"],
                                "Original SQLite rich body differs from the actual UI observation")
                    head = db.execute("""
                        SELECT a.id,h.revision FROM annotations a
                        JOIN otzaria_annotation_exchange_heads h
                        ON h.namespace='otzaria.local.annotation'
                        AND lower(h.annotation_uuid)=lower(a.ckRecordId)
                        WHERE lower(a.ckRecordId)=lower(?)
                        """, (note,)).fetchall()
                    require(head == [(first["annotation_id"], last["revision"])],
                            "The current head is not the UI-created permanent note")
                    native = history[note]
                    imports = native[".native-import-history"]
                    require(len(imports) == 1 and imports[0].get("status") == "LOCAL_NATIVE_IMPORT_READBACK_VERIFIED",
                            "One actual original import readback is required")
                    verify_source(imports[0], note, first, False)
                    revisions = native[".native-revision-history"]
                    lifecycle = native[".native-lifecycle-history"]
                    if role is None:
                        require(len(revisions) == 1 and not lifecycle
                                and revisions[0].get("kind") == "verified", "Actual update history is incomplete")
                        verify_source(revisions[0], note, rows[2], True)
                        require(rows[0]["payload_sha256"] == rows[1]["payload_sha256"]
                                and rows[0]["native_body_sha256"] == rows[1]["native_body_sha256"],
                                "A discarded private edit changed the saved body")
                    else:
                        require(not revisions and len(lifecycle) == 7, "Seven actual lifecycle results are required")
                        expected = [
                            ("archive", None, True, rows[1]), ("restore", None, False, rows[2]),
                            ("promote", role, False, rows[3]),
                            ("replace-promoted-document", role, False, rows[4]),
                            ("archive", role, True, rows[5]), ("restore", role, False, rows[6]),
                            ("revert-promotion", None, False, rows[7])]
                        used = set()
                        for action, document_role, archived, row in expected:
                            matches = [(i, x) for i, x in enumerate(lifecycle)
                                if x.get("action", {}).get("name") == action
                                and x.get("action", {}).get("role") == (role if action == "promote" else None)
                                and x.get("documentRole") == document_role and x.get("isArchived") is archived]
                            require(len(matches) == 1 and matches[0][0] not in used,
                                    "Lifecycle history does not match the original operation/role/state")
                            index, record = matches[0]
                            used.add(index)
                            require(record.get("kind") == "verified", "An original lifecycle result is not verified")
                            verify_source(record, note, row, True)
                    final.append(last)
                require(sorted(kinds) == sorted(["exchange", *ROLES])
                        and len({x["native_object_id"] for x in final}) == 4
                        and len({x["annotation_id"] for x in final}) == 4,
                        "Four distinct original journeys and native roots are required")
            self.state.update(status="ACTUAL_ORDINARY_UI_STORAGE_AND_HISTORY_VERIFIED",
                quick_check="ok", final_annotations=final, observed_database_path=str(database),
                retained_sqlite_sha256=digest(OUT / "retained-local-annotations.sqlite"))
        except BaseException as error:
            self.state.update(status="COLLECTION_FAILED", error_type=type(error).__name__)
            raise
        finally:
            self.persist()

    def cleanup(self, udid):
        if self.udid is not None:
            self.capture(udid, "11-reader")
        self.persist()


def matrix():
    private_route()
    claim_matrix()
    require(context() == json.loads((OUT / "source-before.json").read_text()), "Source changed before UI")
    require(not os.environ.get("FAITHFUL_RUNTIME27_RELEASE_MANIFEST")
            and not os.environ.get("FAITHFUL_DIAGNOSTIC_CASES"), "Dedicated selection cannot be mixed")
    os.environ["VALIDATING_BASELINE"] = "false"
    os.environ["FAITHFUL_RUNTIME27_MANIFEST"] = str(SELECTION)
    callback = ExchangeEvidence()
    try:
        return runpy.run_path(str(ROOT / "Scripts/CI/run-faithful-ipad-matrix.py"))["main"](live_provider=callback)
    finally:
        callback.persist()


def execute():
    private_route()
    require(context() == json.loads((OUT / "source-before.json").read_text()), "Source changed before run")
    require(build_context() == json.loads((OUT / "qualified-build-before.json").read_text()),
            "Qualified actual SDK/app changed before run")
    require(RUN_TOKEN_ENV not in os.environ, "A parent execution token cannot be inherited")
    token = claim_execution()
    driver = runpy.run_path(str(ROOT / "Scripts/CI/runtime27.py"))
    controller = driver["runtime27_interruption"].InterruptController().install()
    os.environ[RUN_TOKEN_ENV] = token
    try:
        # Post-test xcresult validators may print authentication failure details.
        # Keep their entire stdout/stderr private, even after line-level filtering.
        with (OUT / "private-controller.log").open("x") as private:
            with redirect_stdout(private), redirect_stderr(private):
                return driver["run_logged"](
                    [sys.executable, "Scripts/CI/ordinary-native-exchange-ui.py", "matrix"],
                    "ordinary-native-exchange-matrix.log", 4200, interrupt_controller=controller)
    finally:
        os.environ.pop(RUN_TOKEN_ENV, None)
        controller.restore()


def collect():
    private_route()
    report = {"status": "FAILED", "scope": "ORDINARY_ORIGINAL_ACCOUNT_UI",
              "required_case_ids": SELECTORS, "qualification_mode": False,
              "remote_device_acknowledgement": False, "full_native116_accepted": False,
              "full_release114_accepted": False, "native5000_accepted": False,
              "physical_ipad_accepted": False, "raw_evidence_publication": "PRIVATE_MAC_ONLY"}
    try:
        require(context() == json.loads((OUT / "source-before.json").read_text()), "Source changed during UI")
        require(build_context() == json.loads((OUT / "qualified-build-before.json").read_text()),
                "Qualified SDK/app inputs changed during UI")
        storage = json.loads((OUT / "storage-observations.json").read_text())
        require(storage["status"] == "ACTUAL_ORDINARY_UI_STORAGE_AND_HISTORY_VERIFIED",
                "Original stored evidence did not verify")
        report.update(context(), storage_receipt_sha256=digest(OUT / "storage-observations.json"))
        runpy.run_path(str(ROOT / "Scripts/CI/runtime27.py"))["collect_cases"](
            report, json.loads(SELECTION.read_text()))
        devices = json.loads((ARTIFACTS / "faithful-ipad-matrix.json").read_text()).get("devices", [])
        require(len(devices) == 1 and devices[0].get("label") == "11-reader"
                and devices[0].get("status") == "EXECUTED_PASS"
                and devices[0].get("ownedSimulatorCleanup") == "PASS"
                and report.get("executed_ui_pass") == 4
                and all(report.get(x, 0) == 0 for x in ("executed_ui_fail", "executed_ui_skip", "ui_not_run")),
                "Every actual case must execute and pass with original xcresult and zero skips")
        report["status"] = "ORDINARY_ORIGINAL_ACCOUNT_UI_AND_STORAGE_PASS"
        return 0
    except Exception as error:
        report["error_type"] = type(error).__name__
        return 1
    finally:
        write(OUT / "result-private.json", report)


if __name__ == "__main__":
    os.chdir(ROOT)
    os.umask(0o077)
    operations = {"prepare": prepare, "run": execute, "matrix": matrix, "collect": collect}
    require(len(sys.argv) == 2 and sys.argv[1] in operations, "Expected prepare, run, matrix or collect")
    raise SystemExit(operations[sys.argv[1]]() or 0)
