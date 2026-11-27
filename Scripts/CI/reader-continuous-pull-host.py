#!/usr/bin/env python3
"""Owned, pinned idb stream for the separate full-v40 portrait retreat case.

This host never installs tools, changes app data, sets scroll offsets, or seeds
Reader state. It writes only the existing passive viewport request and its own
IPC. Successful operations contain one HID RPC, repeated held DOWN positions,
and one final UP, as in the pinned companion's original swipe implementation.
Transport completion alone is not UI acceptance. The separate XCTest compares
all source samples with its independent v40 catalog and checks document/TOC.
"""
from __future__ import annotations

import argparse
import asyncio
import fcntl
import hashlib
import json
import logging
import math
import os
from pathlib import Path
import plistlib
import re
import secrets
import subprocess
import sys
import tarfile
import tempfile
import threading
import time
import uuid
import zipfile

BUNDLE = "com.davidpovarsky.chavrusatext"
WHEEL = "fb_idb-1.7.8-py3-none-any.whl"
ARCHIVE = "idb-companion.macos-arm64.tar.gz"
PINS = {WHEEL: "ed8557a4c54ffee53006c1fe63f070cda567949312ab24be56faf987c5a3d04b",
        ARCHIVE: "44369a2df0b62e3a1764de61bd09280999c7e9b27ea8f20bff1ea3a9db0302a2"}
MODES = ("paragraph", "chapter")
MAX_NATIVE = 65_536


def require(value, reason):
    if not value:
        raise ValueError(reason)


def digest(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def regular(path, maximum):
    path = Path(path)
    require(not path.is_symlink() and path.is_file() and path.resolve(strict=True) == path
            and path.stat().st_size <= maximum, "Expected bounded regular evidence")
    data = path.read_bytes()
    require(len(data) <= maximum, "Evidence grew beyond its bound")
    return data


def read_json(path, maximum=MAX_NATIVE):
    value = json.loads(regular(path, maximum))
    require(isinstance(value, dict), "Expected an evidence object")
    return value


def write_json(path, value):
    path = Path(path)
    require(not path.exists() and not path.is_symlink(), "Never overwrite retained evidence")
    temporary = path.with_name(path.name + "." + uuid.uuid4().hex + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2))
    temporary.replace(path)


def canonical_uuid(value):
    require(isinstance(value, str) and str(uuid.UUID(value)).upper() == value, "Expected canonical UUID")
    return value


def command(args, timeout=8):
    value = subprocess.run(args, text=True, capture_output=True, timeout=timeout)
    require(value.returncode == 0, "Owned host command failed: " + Path(args[0]).name)
    return value.stdout.strip()


def verify_tools(root):
    root = Path(root)
    require(root.is_absolute() and root.resolve(strict=True) == root and root.is_dir(), "Require existing pinned tool directory")
    require(all(digest(root / name) == sha for name, sha in PINS.items()), "Original idb release digests differ")
    sites = list((root / "client/lib").glob("python*/site-packages"))
    require(len(sites) == 1, "Require the one existing original idb environment")
    source_hashes = {}
    with zipfile.ZipFile(root / WHEEL) as wheel:
        for name in wheel.namelist():
            if name.startswith("idb/") and name.endswith(".py"):
                data = regular(sites[0] / name, 4_000_000)
                require(data == wheel.read(name), "Installed idb source differs from the pinned wheel")
                source_hashes[name] = hashlib.sha256(data).hexdigest()
    require("idb/grpc/client.py" in source_hashes and "idb/grpc/idb_pb2.py" in source_hashes,
            "Original streaming client and protobuf are required")
    binary_hashes = {}
    with tarfile.open(root / ARCHIVE) as archive:
        for name in ("idb_companion", "Resources/libShimulator-iOS.dylib"):
            data = regular(root / "companion" / name, 256 * 1024 * 1024)
            member = archive.extractfile("./" + name)
            require(member is not None and data == member.read(), "Installed companion differs from its pinned archive")
            binary_hashes[name] = hashlib.sha256(data).hexdigest()
    python = root / "client/bin/python"
    require(python.is_file() and os.access(python, os.X_OK), "Retained idb interpreter is unavailable")
    return {"version": "1.7.8", "root": str(root), "python": str(python),
            "companion": str(root / "companion/idb_companion"), "assetSHA256": PINS,
            "installedSourceSHA256": source_hashes, "installedBinarySHA256": binary_hashes}


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def validate_request(request, token, udid, screen):
    require(type(request.get("schema")) is int and request["schema"] == 1 and request.get("token") == token and token,
            "Invalid owned request token/schema")
    canonical_uuid(request.get("nonce"))
    require(request.get("udid") == udid and request.get("mode") in MODES,
            "Unexpected simulator or Reader mode")
    require(request.get("orientation") == "portrait", "This case covers portrait only")
    require(re.fullmatch(r"full-v32-reader-[0-9A-F-]{36}", request.get("viewportName", "")) is not None,
            "Use the original bounded viewport basename")
    canonical_uuid(request["viewportName"][len("full-v32-reader-"):])
    require(type(request.get("appPID")) is int and request["appPID"] > 0
            and type(request.get("renderGeneration")) is int and request["renderGeneration"] > 0
            and type(request.get("textViewObject")) is int
            and type(request.get("sourceUTF16Length")) is int and request["sourceUTF16Length"] > 0,
            "Original Reader identity is incomplete")
    canonical_uuid(request.get("documentID"))
    require(re.fullmatch(r"otzaria\|book:[1-9][0-9]*\|line:[0-9]+", request.get("locator", "")) is not None,
            "An actual original Otzaria canonical unit is required")
    require(finite(request.get("createdAt")) and 0 <= time.time() - request["createdAt"] < 30,
            "Stale request")
    w, h = screen.get("width_points"), screen.get("height_points")
    density = screen.get("density")
    require(type(w) is int and type(h) is int and 0 < w < h and finite(density) and density > 0
            and type(screen.get("width")) is int and type(screen.get("height")) is int
            and abs(screen["width"] - w * density) <= 1 and abs(screen["height"] - h * density) <= 1,
            "Require actual portrait idb point dimensions; never infer missing points from pixels")
    window, frame = request.get("window"), request.get("readerFrame")
    require(isinstance(window, dict) and isinstance(frame, dict)
            and all(finite(v.get(k)) for v in (window, frame) for k in ("x", "y", "width", "height")),
            "Finite original AX geometry required")
    require(abs(window["x"]) <= 0.5 and abs(window["y"]) <= 0.5
            and abs(window["width"] - w) <= 0.5 and abs(window["height"] - h) <= 0.5,
            "The original app window and idb point coordinate space must match exactly")
    require(0 <= frame["x"] < frame["x"] + frame["width"] <= w
            and 0 <= frame["y"] < frame["y"] + frame["height"] <= h and frame["height"] > 360,
            "Original Reader frame must be wholly inside the portrait display")
    points = request.get("points")
    require(isinstance(points, list) and len(points) == 3
            and all(isinstance(p, dict) and all(finite(p.get(k)) for k in ("x", "y")) for p in points),
            "Require start, armed endpoint, and retreat endpoint in points")
    for point in points:
        require(frame["x"] + 8 <= point["x"] <= frame["x"] + frame["width"] - 8
                and frame["y"] + 8 <= point["y"] <= frame["y"] + frame["height"] - 8,
                "Every waypoint must stay inside the actual original Reader")
    require(all(abs(p["x"] - points[0]["x"]) <= 0.5 for p in points)
            and abs(points[1]["y"] - points[0]["y"] - 240) <= 0.000001
            and abs(points[2]["y"] - points[0]["y"] - 20) <= 0.000001,
            "Only the explicit top-edge 240-point pull and 20-point retreat are admitted")


def overscroll(report):
    require(all(finite(report.get(k)) for k in ("contentOffsetY", "topInset", "viewportHeight", "contentHeight")),
            "Original viewport geometry is unavailable")
    return -(report["contentOffsetY"] + report["topInset"])


def validate_native(report, request, request_id, requested_at, previous_uptime):
    require(report.get("requestID") == request_id and finite(report.get("capturedAt"))
            and requested_at <= report["capturedAt"] <= time.time() + 1,
            "Only the fresh original viewport response is admissible")
    selection = report.get("nativeSelectionObservation", {})
    source = report.get("fullV32SourceObservation", {})
    require(selection.get("schema") == source.get("schema") == 1
            and selection.get("requestID") == request_id
            and selection.get("processID") == source.get("processID") == request["appPID"]
            and selection.get("locator") == request["locator"]
            and selection.get("renderGeneration") == request["renderGeneration"]
            and selection.get("textViewObject") == report.get("object") == request["textViewObject"]
            and selection.get("sourceUTF16Length") == source.get("sourceUTF16Length") == request["sourceUTF16Length"],
            "The original current Reader process, owner, locator, generation or source changed")
    require(selection.get("status") in ("EMPTY", "AVAILABLE") and source.get("status") == "AVAILABLE"
            and all(obj.get(key) is True for obj in (report, selection)
                    for key in ("usesTextKit2BeforeObservation", "usesTextKit2AfterObservation")),
            "Require the available original TextKit 2 source observation")
    uptime = source.get("observedUptime")
    require(finite(uptime) and uptime > previous_uptime and finite(selection.get("observedUptime")),
            "Original observations must advance monotonically")
    return uptime


class NativeProbe:
    def __init__(self, container, artifacts, request, stop, admission_guard):
        self.container, self.artifacts, self.request, self.stop = container, artifacts, request, stop
        self.admission_guard = admission_guard
        self.uptime = 0.0
        self.samples = {}
        self.serial = 0

    async def capture(self, phase, criterion):
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            require(not self.stop.exists(), "Owner stopped the continuous contact operation")
            self.admission_guard()
            ident = str(uuid.uuid4()).upper()
            prefix = self.container / "Documents" / self.request["viewportName"]
            temporary = Path(str(prefix) + "." + ident + ".tmp")
            requested = time.time()
            temporary.write_text(ident)
            temporary.replace(Path(str(prefix) + ".request"))
            response_path = Path(str(prefix) + ".viewport.json")
            reply = None
            for _ in range(80):
                require(not self.stop.exists(), "Owner stopped the continuous contact operation")
                if response_path.exists():
                    value = read_json(response_path)
                    if value.get("requestID") == ident:
                        reply = value
                        break
                await asyncio.sleep(0.025)
            require(reply is not None, "Fresh original viewport response timed out")
            self.admission_guard()
            self.uptime = validate_native(reply, self.request, ident, requested, self.uptime)
            self.serial += 1
            require(self.serial <= 48, "Bounded native observation limit exceeded")
            write_json(self.artifacts / (self.request["nonce"] + "-" + phase + "-" + ident + ".json"), reply)
            if criterion(overscroll(reply)):
                self.samples[phase] = reply
                return reply
            await asyncio.sleep(0.05)
        raise ValueError("Actual native viewport never satisfied the " + phase + " criterion")


async def one_contact(client, request, probe):
    """The injected client is the original idb Client in native operation.

    Async-iterator suspension holds the *same* open RPC between original native
    observations. No second swipe, automatic tap or implicit release is used.
    """
    from idb.common.types import HIDDelay, HIDDirection, HIDPress, HIDTouch, Point
    events, failure, held = [], [], []
    current = request["points"][0]
    up_emitted = False
    began = False

    def press(point, direction):
        events.append({"sequence": len(events) + 1, "kind": "touch", "direction": direction.name,
                       "point": dict(point), "hostMonotonic": time.monotonic()})
        return HIDPress(action=HIDTouch(point=Point(x=point["x"], y=point["y"])), direction=direction)

    async def stream():
        nonlocal current, up_emitted, began
        try:
            began = True
            yield press(current, HIDDirection.DOWN)
            yield HIDDelay(duration=0.05)
            for phase, destination, criterion in (
                ("armed", request["points"][1], lambda value: value >= 80),
                ("retreated", request["points"][2], lambda value: 0 <= value < 80),
            ):
                start = dict(current)
                count = math.ceil(abs(destination["y"] - start["y"]) / 10)
                for step in range(1, count + 1):
                    current = {key: start[key] + (destination[key] - start[key]) * step / count for key in ("x", "y")}
                    yield press(current, HIDDirection.DOWN)
                    yield HIDDelay(duration=0.015)
                captured = await probe.capture(phase, criterion)
                held.append({"phase": phase, "lastDownSequence": len(events),
                             "requestID": captured["requestID"], "hostMonotonic": time.monotonic()})
        except Exception as error:
            failure.append(str(error))
        # A failed native criterion still releases in this same stream. A
        # cancelled/broken transport uses the explicitly disqualifying cleanup
        # below; yielding from async-generator finalization would be invalid.
        if began:
            up_emitted = True
            yield press(current, HIDDirection.UP)

    await probe.capture("before", lambda value: abs(value) <= 3)
    transport_failure = None
    try:
        # NativeProbe has bounded waits. This final transport bound is larger
        # than both holds; a transport error never qualifies as UI completion.
        await asyncio.wait_for(client.hid(stream()), timeout=40)
    except Exception as error:
        transport_failure = type(error).__name__
        failure.append("Original HID stream failed: " + transport_failure)
    result = {"schema": 1, "nonce": request["nonce"], "mode": request["mode"], "udid": request["udid"],
              "appPID": request["appPID"], "documentID": request["documentID"], "locator": request["locator"],
              "rpcCount": 1, "events": events, "heldBoundaries": held, "upEmitted": up_emitted,
              "transportCompleted": transport_failure is None, "accepted": False,
              "scope": "One original idb contact; native source samples still require independent XCTest catalog comparison"}
    if transport_failure and began:
        # Failure-only owned cleanup. This second RPC is explicitly disqualifying
        # and cannot be mistaken for the successful one-contact acceptance path.
        result["emergencyReleaseAttempted"] = True
        result["rpcCount"] += 1
        try:
            await asyncio.wait_for(client.send_events([HIDPress(
                action=HIDTouch(point=Point(x=current["x"], y=current["y"])), direction=HIDDirection.UP)]), 5)
            result["emergencyReleaseDelivered"] = True
        except Exception:
            result["emergencyReleaseDelivered"] = False
    if not failure:
        try:
            await probe.capture("released", lambda value: abs(value) <= 3)
        except Exception as error:
            failure.append(str(error))
    result["nativeSamples"] = probe.samples
    result["errors"] = failure
    result["accepted"] = not failure and up_emitted and len([e for e in events if e["direction"] == "UP"]) == 1
    return result


def actual_app(udid, expected_pid):
    app = Path(command(["xcrun", "simctl", "get_app_container", udid, BUNDLE, "app"]))
    info = plistlib.loads(regular(app / "Info.plist", 2_000_000))
    require(info.get("CFBundleIdentifier") == BUNDLE and Path(info["CFBundleExecutable"]).name == info["CFBundleExecutable"],
            "The actual owned application bundle differs")
    executable = app / info["CFBundleExecutable"]
    require(executable.resolve(strict=True) == executable and executable.is_file(), "Original app executable missing")
    fields = command(["/bin/ps", "-ww", "-p", str(expected_pid), "-o", "pid=,comm="], timeout=3).split(None, 1)
    require(fields == [str(expected_pid), str(executable)], "Actual Darwin PID/executable does not match original Reader")
    return {"pid": expected_pid, "executable": str(executable), "sha256": digest(executable)}


def current_admission(control, udid, expected=None):
    """A fresh integration-owner callback receipt precedes all app-data reads.

    The callback must invoke RetainedV40Installation.current_database, which
    binds the original installation manifest. This host independently checks
    simctl's actual current container and that same small immutable manifest.
    It never hashes the 4.35-GB database or searches another container.
    """
    record = read_json(control / "current-admission.json")
    require(record.get("status") == "READY" and finite(record.get("observedAt"))
            and 0 <= time.time() - record["observedAt"] < 10, "Original owner admission is unavailable or stale")
    current = Path(command(["xcrun", "simctl", "get_app_container", udid, BUNDLE, "data"], timeout=5))
    require(str(current) == record.get("container") and current.resolve(strict=True) == current,
            "Integration admission does not name the actual owned current container")
    database, manifest = Path(record["database"]), record["manifest"]
    require(database.is_relative_to(current) and database.resolve(strict=True) == database
            and database.is_file() and database.stat().st_size == 4_355_063_808,
            "Owner-admitted full-v40 database is outside the actual current container")
    path = database.parent / "seforim-installation.json"
    raw = regular(path, 131_072)
    require(manifest == {"path": str(path), "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()},
            "Original installation manifest differs from its fresh owner receipt")
    installed = json.loads(raw)
    require(installed.get("releaseID") == 455390662 and installed.get("releaseTag") == "v40-20261123094345",
            "The retained installation must be the exact production v40 release")
    binding = {"container": str(current), "database": str(database), "manifest": manifest}
    require(expected is None or binding == expected, "Container/database/manifest changed after cohort admission")
    return binding


async def serve(args):
    from idb.common.types import DomainSocketAddress
    from idb.grpc.client import Client
    tools_before = verify_tools(Path(args.tools_root))
    token = os.environ.pop("READER_CONTINUOUS_PULL_HOST_TOKEN")
    original_container, artifacts = Path(args.container), Path(args.artifacts)
    stop, ready = Path(args.stop), Path(args.ready)
    seen, modes, operations = set(), set(), []
    retained_admission = None
    control = ready.parent
    outcome = {"schema": 1, "status": "FAILED_OR_INCOMPLETE", "udid": args.udid,
               "scope": "Host transport and original bounded observations; separate real XCTest must pass", "uiAcceptance": False}
    try:
        async with Client.build(DomainSocketAddress(args.socket), logging.getLogger("reader-continuous-pull"),
                                exchange_metadata=False) as client:
            require(client.companion.udid.upper() == args.udid, "Direct companion is bound to another simulator")
            write_json(ready, {"udid": args.udid, "schema": 1})
            deadline = time.monotonic() + 900
            while not stop.exists() and time.monotonic() < deadline:
                admission_record = read_json(control / "current-admission.json") if (control / "current-admission.json").exists() else {}
                if admission_record.get("status") != "READY":
                    require(retained_admission is None, "Owner admission became unavailable during the cohort")
                    await asyncio.sleep(0.1)
                    continue
                try:
                    admission = current_admission(control, args.udid, retained_admission)
                except (ValueError, FileNotFoundError) as error:
                    # XCTest may relocate data before its case begins. Wait
                    # for the owner's fresh matching receipt without reading
                    # any stale/foreign container. After first admission this
                    # is a strict cohort failure, including between modes.
                    require(retained_admission is None, str(error))
                    outcome["lastPreAdmissionError"] = str(error)
                    await asyncio.sleep(0.25)
                    continue
                current = Path(admission["container"])
                pending = current / "Documents" / ("reader-continuous-pull-" + token + ".pending")
                nonce = canonical_uuid(regular(pending, 64).decode()) if pending.exists() else None
                if nonce is not None and nonce not in seen:
                    seen.add(nonce)
                    require(len(seen) <= 2, "Only the two distinct mode operations belong to this case")
                    path = current / "Documents" / ("reader-continuous-pull-" + token + "-" + nonce + ".request.json")
                    request = read_json(path)
                    require(canonical_uuid(request.get("nonce")) == nonce,
                            "Request basename does not match its one-use nonce")
                    retained_admission = admission
                    description = await asyncio.wait_for(client.describe(), 8)
                    require(description.udid.upper() == args.udid and description.screen_dimensions is not None,
                            "Missing actual owned simulator display dimensions")
                    dimensions = {key: getattr(description.screen_dimensions, key)
                                  for key in ("width", "height", "density", "width_points", "height_points")}
                    validate_request(request, token, args.udid, dimensions)
                    require(request["mode"] not in modes, "A repeated mode cannot replace the other original reading mode")
                    modes.add(request["mode"])
                    identity = actual_app(args.udid, request["appPID"])
                    def guard():
                        current_admission(control, args.udid, retained_admission)
                        fields = command(["/bin/ps", "-ww", "-p", str(identity["pid"]), "-o", "pid=,comm="], timeout=3).split(None, 1)
                        require(fields == [str(identity["pid"]), identity["executable"]],
                                "Original process/path changed during the same contact")
                    probe = NativeProbe(current, artifacts, request, stop, guard)
                    result = await one_contact(client, request, probe)
                    result.update(screenDimensions=dimensions, originalContainer=str(original_container), actualContainer=str(current),
                                  containerRelocatedBeforeCohort=current != original_container, processBefore=identity,
                                  admittedInstallation=retained_admission)
                    result["processAfter"] = actual_app(args.udid, request["appPID"])
                    require(result["processAfter"] == identity, "Original executable or process changed during the contact")
                    guard()
                    after = (await asyncio.wait_for(client.describe(), 8)).screen_dimensions
                    require(after is not None and {key: getattr(after, key) for key in dimensions} == dimensions,
                            "Original idb display coordinate space changed during the contact")
                    operations.append(result)
                    write_json(artifacts / (nonce + "-operation.json"), result)
                    write_json(path.with_name(path.name.replace(".request.json", ".ack.json")), result)
                await asyncio.sleep(0.5)
            require(stop.exists(), "Owner never completed the bounded UI session")
            require(modes == set(MODES) and len(operations) == 2 and all(x["accepted"] for x in operations),
                    "Both original mode operations must complete with one contact and original native observations")
            require(verify_tools(Path(args.tools_root)) == tools_before, "Pinned HID inputs changed during the case")
            outcome["status"] = "HOST_CONTINUOUS_CONTACT_OBSERVATIONS_COMPLETE_UI_VERIFICATION_REQUIRED"
    except Exception as error:
        outcome["errorType"] = type(error).__name__
        outcome["error"] = str(error).replace(token, "<redacted>")
    finally:
        outcome.update(operations=operations, tools=tools_before)
        write_json(artifacts / "RESULT.json", outcome)
    return 0 if outcome["status"].startswith("HOST_CONTINUOUS") else 1


class ContinuousPullHost:
    """Call start() before run_original_case; merge its runner environment.

    Always call stop() afterward. The caller retains same-build/corpus/SDK and
    xcresult/zero-skip qualification; this helper never claims those gates.
    """
    def __init__(self, udid, app_container, artifacts, tools_root, container_resolver):
        self.udid = canonical_uuid(udid)
        self.container = Path(app_container)
        require(self.container.is_absolute() and self.container.resolve(strict=True) == self.container,
                "Pass the observed actual original application data container")
        self.artifacts, self.tools_root = Path(artifacts), Path(tools_root)
        require(self.artifacts.is_absolute(), "Use an explicit absolute evidence directory")
        self.processes, self.logs = [], []
        self.token = secrets.token_hex(24)
        self.control = None
        self.contact_lock = None
        require(callable(container_resolver), "Integration-owner installation resolver is required")
        self.container_resolver = container_resolver
        self.resolver_stop = threading.Event()
        self.resolver_thread = None

    def _resolve_installation(self):
        sequence = 0
        while not self.resolver_stop.is_set():
            sequence += 1
            try:
                value = self.container_resolver()
                require(isinstance(value, dict) and set(value) == {"container", "database", "manifest"},
                        "Owner resolver must return container/database/manifest witness")
                record = {**value, "status": "READY", "sequence": sequence, "observedAt": time.time()}
            except Exception as error:
                record = {"status": "UNAVAILABLE", "sequence": sequence, "observedAt": time.time(),
                          "errorType": type(error).__name__}
            # This is our own changing admission IPC, not retained run evidence.
            temporary = self.control / ("admission-" + uuid.uuid4().hex + ".tmp")
            temporary.write_text(json.dumps(record, sort_keys=True))
            temporary.replace(self.control / "current-admission.json")
            self.resolver_stop.wait(1)

    def start(self):
        require(sys.platform == "darwin", "The native idb host requires the authorized Mac")
        require(not self.artifacts.exists(), "Never overwrite a previous continuous-contact run")
        self.artifacts.mkdir(parents=True)
        require(self.artifacts.resolve(strict=True) == self.artifacts, "Evidence directory must not traverse a symlink")
        tools = verify_tools(self.tools_root)
        write_json(self.artifacts / "tools-before.json", tools)
        self.control = Path(tempfile.mkdtemp(prefix="otzaria-reader-pull-", dir="/tmp")).resolve(strict=True)
        socket, ready, stop = self.control / "companion.sock", self.control / "ready.json", self.control / "stop"
        commands = [
            [tools["companion"], "--udid", self.udid, "--grpc-domain-sock", str(socket)],
            [tools["python"], "-B", str(Path(__file__).resolve()), "serve", "--udid", self.udid,
             "--container", str(self.container), "--artifacts", str(self.artifacts), "--tools-root", str(self.tools_root),
             "--socket", str(socket), "--ready", str(ready), "--stop", str(stop)],
        ]
        try:
            # This dedicated per-UDID lock never touches the idb registry. The
            # integration owner must also serialize other native input suites.
            descriptor = os.open("/tmp/otzaria-reader-continuous-" + self.udid + ".lock",
                                 os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
            self.contact_lock = os.fdopen(descriptor, "r+")
            fcntl.flock(self.contact_lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.resolver_thread = threading.Thread(target=self._resolve_installation, name="owned-reader-pull-admission", daemon=True)
            self.resolver_thread.start()
            for index, args in enumerate(commands):
                environment = os.environ.copy()
                environment.pop("READER_CONTINUOUS_PULL_HOST_TOKEN", None)
                environment.update(IDB_COMPANION_TMPDIR=str(self.control), TMPDIR=str(self.control), PYTHONDONTWRITEBYTECODE="1")
                if index == 1:
                    environment["READER_CONTINUOUS_PULL_HOST_TOKEN"] = self.token
                log = (self.artifacts / ("owned-process-" + str(index) + ".log")).open("w")
                self.logs.append(log)
                process = subprocess.Popen(args, env=environment, stdout=log, stderr=subprocess.STDOUT)
                self.processes.append(process)
                expected = socket if index == 0 else ready
                deadline = time.monotonic() + 25
                while not expected.exists():
                    require(process.poll() is None and time.monotonic() < deadline, "Owned HID process did not become ready")
                    time.sleep(0.1)
            require(read_json(ready).get("udid") == self.udid, "Unexpected direct simulator readiness")
            return {"TEST_RUNNER_READER_CONTINUOUS_PULL_TOKEN": self.token}
        except BaseException:
            self._end_processes()
            raise

    def _end_processes(self):
        for process in reversed(self.processes):
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=8)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=3)
        for log in self.logs:
            log.close()
        self.resolver_stop.set()
        if self.resolver_thread is not None:
            self.resolver_thread.join(timeout=55)
            require(not self.resolver_thread.is_alive(), "Owned installation resolver did not stop")
        if self.contact_lock is not None:
            self.contact_lock.close()
            self.contact_lock = None

    def stop(self):
        require(self.control is not None, "Owned host was not started")
        (self.control / "stop").touch(exist_ok=False)
        try:
            require(len(self.processes) == 2, "Owned host process set is incomplete")
            self.processes[1].wait(timeout=55)
        finally:
            self._end_processes()
        result = read_json(self.artifacts / "RESULT.json", 2_000_000)
        require(self.processes[1].returncode == 0
                and result.get("status") == "HOST_CONTINUOUS_CONTACT_OBSERVATIONS_COMPLETE_UI_VERIFICATION_REQUIRED",
                "Continuous contact host failed or did not observe both genuine mode operations")
        return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["serve"])
    for name in ("udid", "container", "artifacts", "tools-root", "socket", "ready", "stop"):
        parser.add_argument("--" + name, required=True)
    sys.exit(asyncio.run(serve(parser.parse_args())))
