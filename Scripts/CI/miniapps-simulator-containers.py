#!/usr/bin/env python3
"""Read actual owned Simulator containers when its container-query service stalls.

This is used only by the MiniApps acceptance lane after a real simctl timeout.
It never creates a container, changes app entitlements or substitutes app data.
The original native installer, app launch, XCTest and saved-result proof remain
mandatory. Other native lanes keep the original simctl behavior.
"""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import runpy
import subprocess
import uuid
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
ENABLED = "OTZARIA_MINIAPPS_NATIVE_CONTAINER_RECOVERY"
OWNED = "OTZARIA_MINIAPPS_NATIVE_OWNED_SIMULATOR"
AUDIT = ROOT / "build/artifacts/miniapps-native/container-resolution.jsonl"
METADATA = ".com.apple.mobile_container_manager.metadata.plist"
CONSUMER = "com.davidpovarsky.chavrusatext"
PRODUCER = "com.itorah.hanlinminiapps"


def require(value, message):
    if not value:
        raise RuntimeError(message)


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def actual_directory(path, parent=None):
    path = Path(path)
    require(path.is_absolute() and path.is_dir() and not path.is_symlink(),
            "Native container directory is missing or redirected")
    require(path.resolve(strict=True) == path, "Native container path contains a redirection")
    if parent is not None:
        require(path.parent == Path(parent), "Native container is outside the exact owned parent")
    return path


def owned_data_path(udid):
    require(str(uuid.UUID(udid)).upper() == udid and os.environ.get(OWNED) == udid,
            "Container recovery requires the exact disposable Simulator owned by this lane")
    state = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "-j"],
                                              text=True, timeout=45))
    matches = [entry for values in state["devices"].values() for entry in values
               if entry.get("udid") == udid]
    require(len(matches) == 1 and matches[0].get("state") == "Booted",
            "Owned Simulator is not uniquely booted")
    expected = Path.home() / "Library/Developer/CoreSimulator/Devices" / udid / "data"
    actual = Path(matches[0]["dataPath"])
    require(actual == expected, "CoreSimulator reported a different owned dataPath")
    return actual_directory(actual)


def metadata_container(data, relative, identifier):
    """Read unique Apple-created metadata; absence/ambiguity never authorizes mkdir."""
    data = actual_directory(data)
    parent = actual_directory(data / relative)
    matches = []
    for path in sorted(parent.iterdir()):
        if not path.is_dir() or path.is_symlink():
            continue
        metadata = path / METADATA
        if not metadata.is_file() or metadata.is_symlink():
            continue
        try:
            value = plistlib.loads(metadata.read_bytes())
        except (plistlib.InvalidFileException, ValueError):
            continue
        if value.get("MCMMetadataIdentifier") == identifier:
            matches.append(path)
    require(len(matches) == 1, "Expected one actual MCM container for " + identifier)
    container = actual_directory(matches[0], parent)
    require(str(uuid.UUID(container.name)).upper() == container.name,
            "Native MCM container has a noncanonical identifier")
    return container


def installed_app(data, bundle, source_app):
    container = metadata_container(data, "Containers/Bundle/Application", bundle)
    matches = []
    for app in sorted(container.glob("*.app")):
        if app.is_dir() and not app.is_symlink() and (app / "Info.plist").is_file():
            info = plistlib.loads((app / "Info.plist").read_bytes())
            if info.get("CFBundleIdentifier") == bundle:
                matches.append(app)
    require(len(matches) == 1, "Expected one installed app with the original bundle identity")
    app = actual_directory(matches[0], container)
    source_app = Path(source_app)
    original_info = plistlib.loads((source_app / "Info.plist").read_bytes())
    require(original_info.get("CFBundleIdentifier") == bundle, "Original built app has a different identity")
    executable = original_info.get("CFBundleExecutable")
    require(isinstance(executable, str) and executable and Path(executable).name == executable,
            "Invalid original executable identity")
    images = ["Info.plist", executable] + [path.name for path in sorted(source_app.glob("*.dylib"))]
    hashes = {}
    for name in images:
        original, copied = source_app / name, app / name
        require(original.is_file() and copied.is_file() and not copied.is_symlink(),
                "Installed original app image is missing or redirected")
        require(digest(original) == digest(copied), "Installed original app image differs: " + name)
        hashes[name] = digest(copied)
    return app, hashes


def entitled_groups(app):
    # Xcode places Simulator capabilities in the actual executable, while its
    # separate ad-hoc signature legitimately carries an empty entitlement plist.
    # Validate that signature and the frozen reader; never rewrite either image.
    subprocess.run(["codesign", "--verify", "--strict", str(app)], check=True,
                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=45)
    reader_path = Path(__file__).with_name("miniapps-simulator-entitlements.py")
    require(digest(reader_path) == "aa1cfcd4f371dd25a637bc56ab281ef94f8bcdcc2bb415b9125dd0b0aa0b27a8",
            "Simulator entitlement reader differs from the frozen SDK source")
    info = plistlib.loads((app / "Info.plist").read_bytes())
    executable = info.get("CFBundleExecutable")
    require(isinstance(executable, str) and executable and Path(executable).name == executable,
            "Invalid installed executable identity")
    read = runpy.run_path(str(reader_path))["read_simulator_entitlements"]
    proof = read(app / executable)
    groups = proof["entitlements"].get("com.apple.security.application-groups", [])
    require(isinstance(groups, list) and all(isinstance(value, str) for value in groups),
            "Installed App Group entitlement is malformed")
    audit({"status": "ACTUAL_SIMULATOR_ENTITLEMENTS_VERIFIED", "installed_app": str(app),
           "signature": "AD_HOC_CODE_SIGNATURE_VERIFIED", "simulator_entitlements": proof,
           "reader_source_sha": "a774de24926ca13d563c45c42917d03b8c04296f",
           "physical_signing_status": "NOT_QUALIFIED_BY_SIMULATOR"})
    return groups

def expected_app(bundle):
    if bundle == CONSUMER:
        return ROOT / "build/DerivedData/Build/Products/Debug-iphonesimulator/Maktabah.app"
    if bundle == PRODUCER:
        return ROOT / "build/miniapps-producer/HanlinMiniApps.app"
    raise RuntimeError("Container recovery is limited to the two original MiniApps participants")


def audit(record):
    AUDIT.parent.mkdir(parents=True, exist_ok=True)
    with AUDIT.open("a") as stream:
        stream.write(json.dumps({"at": datetime.now(timezone.utc).isoformat(), **record},
                                sort_keys=True) + "\n")
        stream.flush()


def prior_timeout(udid, bundle, kind):
    if not AUDIT.is_file():
        return None
    for line in reversed(AUDIT.read_text().splitlines()):
        row = json.loads(line)
        if (row.get("udid"), row.get("bundle"), row.get("kind")) == (udid, bundle, kind):
            if row.get("simctl_status") == "TIMEOUT":
                return row.get("simctl_error")
    return None


def resolve_container(udid, bundle, kind, timeout=45, source_app=None):
    command = ["xcrun", "simctl", "get_app_container", udid, bundle, kind]
    if os.environ.get(ENABLED) != "1":
        return Path(subprocess.check_output(command, text=True, timeout=timeout).strip())
    require(bundle in {CONSUMER, PRODUCER}, "Unexpected app in the two-app native lane")
    require(kind in {"app", "data"} or kind.startswith("group."), "Unexpected native container kind")
    data = owned_data_path(udid)
    record = {"udid": udid, "owned_data_path": str(data), "bundle": bundle, "kind": kind}
    error = prior_timeout(udid, bundle, kind)
    if error is None:
        try:
            value = subprocess.check_output(command, text=True, timeout=timeout).strip()
            require(bool(value) and "\n" not in value and "\r" not in value, "Invalid native container response")
            path = actual_directory(Path(value))
            require(path.is_relative_to(data), "Native container is outside the owned Simulator")
            audit({**record, "status": "SIMCTL_RESOLVED", "simctl_status": "PASS", "path": str(path)})
            return path
        except subprocess.TimeoutExpired as failure:
            error = str(failure)
            audit({**record, "status": "NATIVE_QUERY_TIMEOUT", "simctl_status": "TIMEOUT",
                   "simctl_error": error, "timeout_seconds": timeout})
    # The original timeout stays a failure record. Read OS metadata and exact
    # installed bytes; do not repeat a known-stalled query or restart/reinstall.
    record.update(simctl_status="TIMEOUT", simctl_error=error, timeout_seconds=timeout)
    try:
        app, hashes = installed_app(data, bundle, source_app or expected_app(bundle))
        if kind == "app":
            path = app
            metadata = app.parent / METADATA
        elif kind == "data":
            path = metadata_container(data, "Containers/Data/Application", bundle)
            metadata = path / METADATA
        else:
            groups = entitled_groups(app)
            require(kind in groups, "Installed original app does not declare the requested group")
            path = metadata_container(data, "Containers/Shared/AppGroup", kind)
            metadata = path / METADATA
            record["installed_app_groups"] = groups
        record.update(status="ACTUAL_MCM_IDENTITY_RESOLVED", path=str(path),
                      metadata_path=str(metadata), metadata_sha256=digest(metadata),
                      installed_app=str(app), installed_image_sha256=hashes,
                      native_ui_acceptance="STILL_REQUIRED", container_created=False)
        audit(record)
        return path
    except Exception as failure:
        audit({**record, "status": "METADATA_IDENTITY_REJECTED",
               "error": type(failure).__name__ + ": " + str(failure)})
        raise
