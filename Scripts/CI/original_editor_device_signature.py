#!/usr/bin/env python3
"""Sign owned device copies while retaining the exact admitted SDK code.

The Simulator route continues to require complete byte equality. This module is
only for Release/iphoneos. Mach-O layouts follow Apple's mach-o/loader.h; only
the two __LINKEDIT sizes, LC_CODE_SIGNATURE.datasize and a sole FAT slice's size
are normalized. The FAT offset, alignment and zero padding remain bound.
Every other byte preceding the already present signature remains bound.

Primary signing guidance: developer.apple.com/documentation/xcode/
using-the-latest-code-signature-format (sign nested code first; frameworks must
not receive entitlements or provisioning profiles).
"""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import runpy
import shutil
import stat
import struct
import subprocess
import tempfile
import uuid

SCHEMA = "otzaria.original-editor.production-admission/1"
TARGET = "Maktabah-iOS"
BUNDLE = "com.davidpovarsky.chavrusatext"


def require(value, message):
    if not value:
        raise RuntimeError(message)


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, sort_keys=True, indent=2) + "\n")


def macho_identity(path, *, expected_platform=2):
    """Bind all code/data in one signed arm64 dylib, excluding signature storage.

    The diagnostic platform parameter permits a real Simulator signing control;
    production callers always use the default iOS platform, 2.
    """
    path = Path(path)
    require(path.is_file() and not path.is_symlink(), "Missing or redirected Mach-O")
    initial = path.stat()
    require(32 < initial.st_size <= 2 * 1024**3, "Unbounded native image")
    with path.open("rb") as stream:
        prefix = stream.read(8)
        wrapper = b""
        slice_offset, slice_bytes = 0, initial.st_size
        container = {"format": "thin", "slice_offset": 0}
        fat_magic, slices = struct.unpack(">II", prefix)
        if fat_magic in {0xCAFEBABE, 0xCAFEBABF}:
            require(slices == 1, "Only one actual arm64 slice is admitted")
            fat64 = fat_magic == 0xCAFEBABF
            entry = stream.read(32 if fat64 else 20)
            require(len(entry) == (32 if fat64 else 20), "Truncated architecture wrapper")
            if fat64:
                cpu, subtype, slice_offset, slice_bytes, alignment, reserved = struct.unpack(">IIQQII", entry)
                require(reserved == 0, "Unexpected FAT64 reserved bits")
            else:
                cpu, subtype, slice_offset, slice_bytes, alignment = struct.unpack(">IIIII", entry)
            require(cpu == 0x0100000C and subtype & 0xFFFFFF == 0 and 2 <= alignment <= 16
                    and 8 + len(entry) <= slice_offset <= 65536
                    and slice_offset % (1 << alignment) == 0 and slice_bytes > 32
                    and slice_offset + slice_bytes == initial.st_size,
                    "Unbounded or foreign architecture wrapper")
            padding = stream.read(slice_offset - 8 - len(entry))
            require(len(padding) == slice_offset - 8 - len(entry) and not any(padding),
                    "Unexpected data outside the sole native slice")
            normalized_wrapper = bytearray(prefix + entry + padding)
            size_offset, size_bytes = (24, 8) if fat64 else (20, 4)
            normalized_wrapper[size_offset:size_offset + size_bytes] = b"\0" * size_bytes
            wrapper = bytes(normalized_wrapper)
            container = {"format": "fat64" if fat64 else "fat32", "slice_offset": slice_offset,
                         "alignment_power": alignment}
        stream.seek(slice_offset)
        header = stream.read(32)
        require(len(header) == 32, "Truncated Mach-O header")
        magic, cpu, subtype, kind, count, command_bytes, flags, reserved = struct.unpack("<8I", header)
        require(magic == 0xFEEDFACF and cpu == 0x0100000C and subtype & 0xFFFFFF == 0
                and kind == 6, "Only an arm64 MH_DYLIB is admitted")
        require(1 <= count <= 4096 and count * 8 <= command_bytes <= 16 * 1024**2
                and command_bytes < slice_bytes - 32, "Invalid Mach-O command bounds")
        commands = stream.read(command_bytes)
        require(len(commands) == command_bytes, "Truncated Mach-O commands")
        signature = linkedit = image_uuid = platform = None
        offset = 0
        for _ in range(count):
            require(offset + 8 <= len(commands), "Truncated load command")
            command, size = struct.unpack_from("<II", commands, offset)
            require(size >= 8 and size % 8 == 0 and offset + size <= len(commands),
                    "Invalid load command size")
            if command == 0x1D:
                require(signature is None and size == 16, "Ambiguous code signature command")
                signature = (offset + 32, *struct.unpack_from("<II", commands, offset + 8))
            elif command == 0x19:
                require(size >= 72, "Truncated segment command")
                name = commands[offset + 8:offset + 24].rstrip(b"\0")
                sections = struct.unpack_from("<I", commands, offset + 64)[0]
                require(size == 72 + sections * 80, "Invalid segment section bounds")
                if name == b"__LINKEDIT":
                    require(linkedit is None and sections == 0, "Ambiguous __LINKEDIT")
                    vmaddr, vmsize, fileoff, filesize = struct.unpack_from("<4Q", commands, offset + 24)
                    linkedit = (offset + 32, vmaddr, vmsize, fileoff, filesize)
            elif command == 0x1B:
                require(image_uuid is None and size == 24, "Ambiguous Mach-O UUID")
                image_uuid = str(uuid.UUID(bytes=commands[offset + 8:offset + 24])).upper()
            elif command == 0x32:
                require(platform is None and size >= 24, "Ambiguous build platform")
                platform, minimum, sdk, tools = struct.unpack_from("<4I", commands, offset + 8)
                require(size == 24 + 8 * tools, "Invalid build tool bounds")
            offset += size
        require(offset == len(commands) and signature and linkedit and image_uuid
                and platform == expected_platform, "Incomplete or wrong device Mach-O identity")
        signature_command, signature_offset, signature_size = signature
        segment_command, _, vmsize, fileoff, filesize = linkedit
        require(32 + command_bytes <= fileoff < signature_offset and signature_offset % 16 == 0
                and signature_size >= 12 and signature_offset + signature_size == slice_bytes
                and fileoff + filesize == slice_bytes and vmsize >= filesize,
                "Signature must occupy the exact final __LINKEDIT extent")
        stream.seek(slice_offset + signature_offset)
        signature_header = stream.read(12)
        blob_magic, blob_bytes, blob_count = struct.unpack(">III", signature_header)
        require(blob_magic == 0xFADE0CC0 and 12 <= blob_bytes <= signature_size
                and blob_count * 8 <= blob_bytes - 12, "Invalid embedded signature envelope")
        normalized = bytearray(header + commands)
        normalized[signature_command + 12:signature_command + 16] = b"\0" * 4
        normalized[segment_command + 32:segment_command + 40] = b"\0" * 8
        normalized[segment_command + 48:segment_command + 56] = b"\0" * 8
        value = hashlib.sha256(wrapper + normalized)
        stream.seek(slice_offset + len(normalized))
        remaining = signature_offset - len(normalized)
        while remaining:
            chunk = stream.read(min(1024**2, remaining))
            require(chunk, "Truncated unsigned image payload")
            value.update(chunk)
            remaining -= len(chunk)
        final = path.stat()
        require((initial.st_dev, initial.st_ino, initial.st_size, initial.st_mtime_ns)
                == (final.st_dev, final.st_ino, final.st_size, final.st_mtime_ns),
                "Native image changed while its identity was read")
    return {"architecture": "arm64", "container": container, "platform": platform, "uuid": image_uuid,
            "signature_offset": signature_offset, "canonical_sha256": value.hexdigest(),
            "normalization": "signature-size+__LINKEDIT-sizes+single-FAT-slice-size-only"}


def resources_without_signature(records, executable):
    """Keep every non-signature member, including Info.plist and file modes."""
    require(all(name == "_CodeSignature/CodeResources" for name in records if name.startswith("_CodeSignature/")),
            "Unexpected member inside the signature directory")
    return {name: row for name, row in records.items()
            if name not in {executable, "_CodeSignature", "_CodeSignature/CodeResources"}}


def command(args, evidence, label, *, timeout=90):
    result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    write(Path(evidence) / (label + ".json"), {"command": args, "returncode": result.returncode,
          "stdout": result.stdout, "stderr": result.stderr})
    require(result.returncode == 0, "Device signature command failed: " + label)
    return result


def signature(path, evidence, label, *, team=None, identity=None, framework=True):
    args = ["codesign", "--verify", "--strict"]
    if team:
        require(re.fullmatch(r"[A-Z0-9]{10}", team), "Invalid signing team")
        args += ["-R", '=anchor apple generic and certificate leaf[subject.OU] = "' + team + '"']
    command([*args, str(path)], evidence, label + "-verify")
    displayed = command(["codesign", "--display", "--verbose=4", str(path)], evidence, label + "-display")
    values = {}
    for line in (displayed.stdout + "\n" + displayed.stderr).splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            if key in {"Identifier", "TeamIdentifier", "CDHash"}:
                require(key not in values, "Ambiguous code signature metadata")
                values[key] = value
    require(values.get("Identifier"), "Missing signed bundle identity")
    if framework:
        entitlements = command(["codesign", "--display", "--entitlements", ":-", str(path)],
                               evidence, label + "-entitlements").stdout.strip()
        require(not entitlements or plistlib.loads(entitlements.encode()) == {},
                "Framework signatures must not contain entitlements")
        require(not any(p.name in {"embedded.mobileprovision", "embedded.provisionprofile"}
                        for p in Path(path).rglob("*")), "Framework contains a provisioning profile")
    if team:
        require(values.get("TeamIdentifier") == team, "Actual signature has the wrong team")
        with tempfile.TemporaryDirectory(prefix=".device-signature-cert-", dir=evidence) as temporary:
            prefix = str(Path(temporary) / "certificate-")
            command(["codesign", "--display", "--extract-certificates=" + prefix, str(path)],
                    evidence, label + "-certificate")
            leaf = Path(prefix + "0")
            require(leaf.is_file() and 0 < leaf.stat().st_size <= 64 * 1024, "No actual signing certificate")
            values["leaf_certificate_sha1"] = hashlib.sha1(leaf.read_bytes()).hexdigest().upper()
        if identity is not None:
            require(values["leaf_certificate_sha1"] == identity, "Actual certificate differs from expanded signing identity")
    return values


def bind_reviewed_configuration(configuration, admitted):
    fields = ("source_sha", "control_sha", "native_source_tree", "configuration", "platform",
              "qualification_sha256", "signing_team_id", "distribution_root", "run_id",
              "run_attempt", "local_execution_sha256")
    for field in fields:
        require(field in configuration and field in admitted and configuration[field] == admitted[field],
                "Device receipt belongs to a different committed SDK: " + field)
    run = admitted["run_id"]
    require(isinstance(run, str) and run.startswith("local-") and str(uuid.UUID(run[6:])) == run[6:]
            and type(admitted["run_attempt"]) in {int, str} and str(admitted["run_attempt"]) == "1"
            and re.fullmatch(r"[a-f0-9]{64}", admitted["local_execution_sha256"]),
            "Device signing must retain the actual local producer owner")


def context(root, admission_receipt, receipt_sha256, target, evidence):
    root = Path(root).resolve(strict=True)
    sdk = runpy.run_path(str(root / "Scripts/CI/hq-original-editor-distribution.py"))
    def owned(path):
        path = Path(path)
        relative = path.relative_to(root).as_posix() if path.is_absolute() else path.as_posix()
        return sdk["owned_path"](root, relative, build=True)
    admission_receipt, evidence = owned(admission_receipt), owned(evidence)
    require(re.fullmatch(r"[a-f0-9]{64}", receipt_sha256) and digest(admission_receipt) == receipt_sha256,
            "Device distribution admission receipt changed")
    admitted = sdk["read_json"](admission_receipt)
    require(admitted.get("schema") == SCHEMA and admitted.get("configuration") == "Release"
            and admitted.get("platform") == "iphoneos" and admitted.get("architectures") == ["arm64"],
            "Only the qualified Release device distribution is admitted")
    require(re.fullmatch(r"[A-Z0-9]{10}", admitted.get("signing_team_id", "")), "Unbound device signing team")
    for field in ("source_sha", "control_sha", "native_source_tree"):
        require(re.fullmatch(r"[a-f0-9]{40}", admitted.get(field, "")), "Unbound original producer source: " + field)
    require(re.fullmatch(r"[a-f0-9]{64}", admitted.get("qualification_sha256", "")), "Unbound device qualification")
    reviewed = sdk["owned_path"](root, admitted["admission_path"])
    require(admitted["admission_path"].startswith("Scripts/CI/")
            and digest(reviewed) == admitted["admission_sha256"], "Reviewed device admission changed")
    committed = subprocess.check_output(["git", "show", "HEAD:" + admitted["admission_path"]], cwd=root, timeout=90)
    require(committed == reviewed.read_bytes(), "Device admission is not the committed source")
    bind_reviewed_configuration(json.loads(committed), admitted)
    distribution = sdk["owned_path"](root, admitted["distribution_root"], build=True)
    require(sdk["inventory"](distribution) == admitted["distribution_files"], "Original device distribution changed")
    require(digest(distribution / "QUALIFICATION.json") == admitted["qualification_sha256"], "Device qualification bytes changed")
    for key, suffix in (("dynamic_frameworks", ".framework"), ("resource_bundles", ".bundle")):
        names = admitted[key]
        require(type(names) is list and len(names) == len(set(names))
                and all(re.fullmatch(r"[A-Za-z0-9_.+-]+" + re.escape(suffix), n) for n in names),
                "Malformed original device product list")
    require("AnytypeOriginalEditor.framework" in admitted["dynamic_frameworks"], "Missing original editor framework")
    target = sdk["app_bundle"](root, target)
    evidence.mkdir(parents=True, exist_ok=True)
    return root, sdk, admitted, distribution, target, evidence


def signing_environment(admitted, environ):
    require(environ.get("TARGET_NAME") == TARGET and environ.get("PRODUCT_BUNDLE_IDENTIFIER") == BUNDLE
            and environ.get("CONFIGURATION") == "Release" and environ.get("PLATFORM_NAME") == "iphoneos",
            "Device embedding requires the actual Maktabah Release/iphoneos target")
    require(environ.get("CODE_SIGNING_ALLOWED") == "YES", "Device code signing is disabled")
    identity = environ.get("EXPANDED_CODE_SIGN_IDENTITY", "").upper()
    require(re.fullmatch(r"[A-F0-9]{40}", identity), "A real expanded signing identity is required")
    team = environ.get("DEVELOPMENT_TEAM")
    require(team == admitted["signing_team_id"], "Actual development team differs from the reviewed route")
    return identity, team


def framework_identity(sdk, framework):
    info = plistlib.loads((framework / "Info.plist").read_bytes())
    executable = info.get("CFBundleExecutable", "")
    require(re.fullmatch(r"[A-Za-z0-9_+-]+", executable) and info.get("CFBundleIdentifier"),
            "Invalid original framework executable or identifier")
    files = sdk["inventory"](framework, metadata=True)
    return {"executable": executable, "executable_mode": files[executable]["mode"],
            "identifier": info["CFBundleIdentifier"],
            "code": macho_identity(framework / executable),
            "resources": resources_without_signature(files, executable), "files": files}


def same_code_and_resources(source, destination):
    require(all(source[k] == destination[k] for k in ("executable", "executable_mode", "identifier", "code", "resources")),
            "Embedded device framework changed code or non-signature resources")


def embed(root, admission_receipt, receipt_sha256, target, evidence):
    root, sdk, admitted, distribution, target, evidence = context(
        root, admission_receipt, receipt_sha256, target, evidence)
    identity, team = signing_environment(admitted, os.environ)
    receipts = []
    for index, name in enumerate(admitted["dynamic_frameworks"]):
        source, destination = distribution / "Frameworks" / name, target / "Frameworks" / name
        original = framework_identity(sdk, source)
        source_signature = signature(source, evidence, "source-device-" + str(index))
        require(source_signature["Identifier"] == original["identifier"], "Original signed identifier differs from Info.plist")
        require(not destination.is_symlink() and not any(p.is_symlink() for p in destination.parents),
                "Redirected framework destination")
        if destination.exists():
            before = framework_identity(sdk, destination)
            same_code_and_resources(original, before)
            disposition = "REUSED_SAME_CODE_AND_RESOURCES"
        else:
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copytree(source, destination, copy_function=shutil.copy2)
            require(sdk["inventory"](destination, metadata=True) == original["files"], "Initial device framework copy differs")
            disposition = "COPIED_MISSING"
        command(["codesign", "--force", "--sign", identity, "--timestamp=none",
                 "--preserve-metadata=identifier,flags", str(destination)], evidence, "device-sign-" + str(index))
        signed = framework_identity(sdk, destination)
        same_code_and_resources(original, signed)
        signed_signature = signature(destination, evidence, "embedded-device-" + str(index), team=team, identity=identity)
        require(signed_signature["Identifier"] == original["identifier"], "Re-sign changed framework identifier")
        receipts.append({"name": name, "disposition": disposition, "source_files": original["files"],
                         "embedded_files": signed["files"], "canonical_code": signed["code"],
                         "source_signature": source_signature, "embedded_signature": signed_signature})
    bundles = []
    for name in admitted["resource_bundles"]:
        source, destination = distribution / "Bundles" / name, target / name
        disposition = sdk["compare_or_copy"](source, destination)
        bundles.append({"name": name, "disposition": disposition, "files": sdk["inventory"](destination, metadata=True)})
    require(sdk["inventory"](distribution) == admitted["distribution_files"], "Signing changed the original distribution")
    result = {"status": "SIGNED_ORIGINAL_DEVICE_PRODUCTS_PRESENT", "schema": "otzaria.original-editor.device-embedding/1",
              "admission_receipt_sha256": receipt_sha256, "target": str(target), "configuration": "Release",
              "platform": "iphoneos", "signing_team_id": team, "expanded_code_sign_identity": identity,
              "source_sha": admitted["source_sha"], "control_sha": admitted["control_sha"],
              "qualification_sha256": admitted["qualification_sha256"], "frameworks": receipts,
              "resource_bundles": bundles, "original_distribution_unchanged": True,
              "original_code_and_non_signature_resources_unchanged": True, "source_products_overwritten": 0,
              "main_app_signing_owner": "XCODE_AFTER_OWNED_FRAMEWORK_EMBED", "device_ui_acceptance": False}
    write(evidence / "device-app-embedding.json", result)
    return result


def verify(root, admission_receipt, receipt_sha256, target, evidence, *, expected_team=None, after_archive=False):
    root, sdk, admitted, distribution, target, evidence = context(
        root, admission_receipt, receipt_sha256, target, evidence)
    embedding = sdk["read_json"](evidence / "device-app-embedding.json", maximum=64 * 1024**2)
    team, identity = embedding.get("signing_team_id"), embedding.get("expanded_code_sign_identity")
    require(embedding.get("schema") == "otzaria.original-editor.device-embedding/1"
            and embedding.get("status") == "SIGNED_ORIGINAL_DEVICE_PRODUCTS_PRESENT"
            and embedding.get("admission_receipt_sha256") == receipt_sha256
            and team == admitted["signing_team_id"] and (expected_team is None or expected_team == team)
            and re.fullmatch(r"[A-F0-9]{40}", identity or ""), "Missing exact original device embed receipt")
    require(after_archive or embedding["target"] == str(target), "Unexpected app product relocation before archive")
    prefix = "after-archive-" if after_archive else "built-"
    rows = []
    require([row["name"] for row in embedding["frameworks"]] == admitted["dynamic_frameworks"], "Device framework receipt list changed")
    for index, name in enumerate(admitted["dynamic_frameworks"]):
        source, destination = distribution / "Frameworks" / name, target / "Frameworks" / name
        original, signed = framework_identity(sdk, source), framework_identity(sdk, destination)
        same_code_and_resources(original, signed)
        saved = embedding["frameworks"][index]
        require(saved["source_files"] == original["files"] and saved["canonical_code"] == signed["code"],
                "Original signed distribution or embedded code receipt changed")
        actual_signature = signature(destination, evidence, prefix + "device-" + str(index), team=team, identity=identity)
        require(actual_signature["Identifier"] == signed["identifier"], "Embedded signature identifier changed")
        rows.append({"name": name, "canonical_code": signed["code"], "signature": actual_signature,
                     "embedded_files": signed["files"]})
    for name in admitted["resource_bundles"]:
        require(sdk["inventory"](target / name, metadata=True) == sdk["inventory"](distribution / "Bundles" / name, metadata=True),
                "Embedded original device resource bundle changed")
    app_info = plistlib.loads((target / "Info.plist").read_bytes())
    require(app_info.get("CFBundleIdentifier") == BUNDLE, "Wrong actual signed app bundle")
    app_signature = signature(target, evidence, prefix + "device-app", team=team, identity=identity, framework=False)
    require(app_signature["Identifier"] == BUNDLE, "Actual main app signed identifier differs")
    require(sdk["inventory"](distribution) == admitted["distribution_files"], "Original device distribution changed after build")
    result = {"status": "ORIGINAL_DEVICE_CODE_AND_REAL_SIGNATURES_VERIFIED", "after_archive": bool(after_archive),
              "target": str(target), "original_embedding_target": embedding["target"],
              "admission_receipt_sha256": receipt_sha256, "embedding_receipt_sha256": digest(evidence / "device-app-embedding.json"),
              "source_sha": admitted["source_sha"], "control_sha": admitted["control_sha"],
              "signing_team_id": team, "expanded_code_sign_identity": identity,
              "frameworks": rows, "resource_bundles": admitted["resource_bundles"], "app_signature": app_signature,
              "original_distribution_unchanged": True, "device_ui_acceptance": False, "testflight_acceptance": False}
    write(evidence / (prefix + "device-app-verification.json"), result)
    return result
