"""Admit an actual source-bound MiniApps Simulator product built on the shared Mac.

This is artifact admission, never evidence of native UI or physical signing.
GitHub products continue through the original GitHub-specific lane.
"""
from pathlib import Path, PurePosixPath
import hashlib
import json
import os
import plistlib
import re
import stat
import subprocess
import zipfile


def require(value, message):
    if not value:
        raise RuntimeError(message)


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def valid_digest(value):
    return isinstance(value, str) and re.fullmatch(r"[a-f0-9]{64}", value) is not None


def contained_file(directory, name):
    require(isinstance(name, str), "Local producer evidence filename is absent")
    relative = PurePosixPath(name)
    require(not relative.is_absolute() and ".." not in relative.parts and relative.parts,
            "Local producer evidence path leaves its export")
    directory = Path(directory).resolve()
    path = (directory / name).resolve(strict=True)
    require(path.is_relative_to(directory) and path.is_file(), "Local producer evidence is outside its export")
    return path


def app_inventory(app):
    app = Path(app)
    inventory = {}
    for path in sorted(app.rglob("*")):
        name = path.relative_to(app).as_posix()
        mode = path.lstat().st_mode & 0o777
        if path.is_symlink():
            target = os.readlink(path)
            require(not Path(target).is_absolute() and path.resolve(strict=True).is_relative_to(app.resolve()),
                    "Local producer app symlink leaves the original product")
            inventory[name] = {"kind": "symlink", "target": target}
        elif path.is_file():
            inventory[name] = {"kind": "file", "bytes": path.stat().st_size, "mode": mode, "sha256": digest(path)}
        elif path.is_dir():
            inventory[name] = {"kind": "directory", "mode": mode}
        else:
            raise RuntimeError("Local producer contains an unsupported product entry")
    return inventory


def validate_source_identity(identity, sdk_root, source_sha):
    require(isinstance(identity, dict) and identity.get("commit") == source_sha,
            "Local producer source identity differs from the consumer SDK")
    sdk_root = Path(sdk_root)
    tree = subprocess.check_output(["git", "-C", str(sdk_root), "rev-parse", source_sha + "^{tree}"],
                                   text=True, timeout=30).strip()
    require(identity.get("tree") == tree, "Local producer source tree differs from its immutable commit")
    files = identity.get("tracked_file_sha256")
    require(isinstance(files, dict) and files, "Local producer has no original source-file identity")
    require(all(isinstance(path, str) and path and "\n" not in path and "\r" not in path
                and not PurePosixPath(path).is_absolute() and ".." not in PurePosixPath(path).parts
                and valid_digest(expected) for path, expected in files.items()),
            "Invalid local producer source-file inventory")
    names = sorted(files)
    requested = "".join(source_sha + ":" + name + "\n" for name in names).encode()
    result = subprocess.run(["git", "-C", str(sdk_root), "cat-file", "--batch"],
                            input=requested, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120)
    require(result.returncode == 0, "Cannot read the exact original producer source objects")
    cursor = 0
    for name in names:
        end = result.stdout.find(b"\n", cursor)
        require(end >= cursor, "Incomplete original producer source objects")
        header = result.stdout[cursor:end].split()
        require(len(header) == 3 and header[1] == b"blob", "Original producer source file is missing: " + name)
        size = int(header[2])
        start = end + 1
        content = result.stdout[start:start + size]
        require(len(content) == size and result.stdout[start + size:start + size + 1] == b"\n",
                "Incomplete original producer source file: " + name)
        require(hashlib.sha256(content).hexdigest() == files[name], "Producer source bytes differ: " + name)
        cursor = start + size + 1
    require(cursor == len(result.stdout), "Unexpected extra producer source objects")


def validate_export(config, sdk_root, bundle_id):
    specification = config["local_producer_manifest"]
    path = Path(specification["path"]).resolve(strict=True)
    require(path.is_file() and digest(path) == specification["sha256"],
            "Local producer manifest bytes differ from the reviewed input")
    manifest = json.loads(path.read_text())
    require(manifest.get("schema_version") == 1 and manifest.get("execution_origin") == "local-mac"
            and manifest.get("run_id") is None, "Local product must identify its actual Mac origin without a GitHub run")
    require(manifest.get("producer_sha") == config["producer_source_sha"]
            and manifest.get("bundle_id") == bundle_id, "Local producer identity differs")
    require(manifest.get("build_status") == "EXECUTED_PASS", "The actual local producer build did not succeed")
    require(manifest.get("app_relative_path") == "HanlinMiniApps.app"
            and manifest.get("archive_name") == "HanlinMiniApps-simulator.zip", "Unexpected local producer layout")
    receipt_path = contained_file(path.parent, manifest["build_receipt_name"])
    require(valid_digest(manifest.get("build_receipt_sha256"))
            and digest(receipt_path) == manifest["build_receipt_sha256"], "Local producer build receipt changed")
    receipt = json.loads(receipt_path.read_text())
    require(receipt.get("build") == "EXECUTED_PASS"
            and receipt.get("status") == manifest.get("native_acceptance_status"),
            "Local product is not bound to its actual separate build and native acceptance outcomes")
    log_path = contained_file(path.parent, manifest["build_log_name"])
    require(valid_digest(manifest.get("build_log_sha256"))
            and digest(log_path) == manifest["build_log_sha256"], "Local producer build log changed")
    require(b"** BUILD SUCCEEDED **" in log_path.read_bytes()
            or b"** TEST BUILD SUCCEEDED **" in log_path.read_bytes(),
            "Local producer log does not contain an actual successful Apple build")
    validate_source_identity(manifest.get("source_identity"), sdk_root, config["producer_source_sha"])
    archive = contained_file(path.parent, manifest["archive_name"])
    require(valid_digest(manifest.get("archive_sha256")) and digest(archive) == manifest["archive_sha256"],
            "Local producer archive changed")
    require(isinstance(manifest.get("app_files"), dict) and manifest["app_files"],
            "Local product has no complete app-file inventory")
    with zipfile.ZipFile(archive) as package:
        seen = set()
        for member in package.infolist():
            name = PurePosixPath(member.filename)
            require(member.filename not in seen, "Duplicate local producer archive entry")
            seen.add(member.filename)
            require(not name.is_absolute() and ".." not in name.parts and name.parts
                    and name.parts[0] in ("HanlinMiniApps.app", "__MACOSX"), "Local producer archive leaves its product root")
            if stat.S_ISLNK(member.external_attr >> 16):
                target = package.read(member).decode()
                require(not PurePosixPath(target).is_absolute(), "Absolute product symlink in local archive")
                joined = []
                for part in (name.parent / target).parts:
                    if part == "..":
                        require(len(joined) > 1, "Local product symlink escapes its root")
                        joined.pop()
                    elif part != ".":
                        joined.append(part)
                require(joined and joined[0] == "HanlinMiniApps.app", "Local product symlink escapes its app")
    return path, manifest, archive


def restore(config, destination, output, sdk_root, bundle_id):
    path, manifest, archive = validate_export(config, sdk_root, bundle_id)
    destination, output = Path(destination), Path(output)
    destination.mkdir(parents=True, exist_ok=True)
    app = destination / manifest["app_relative_path"]
    require(not app.exists(), "An existing admitted producer product must not be overwritten")
    subprocess.run(["ditto", "-x", "-k", str(archive), str(destination)], check=True, timeout=180)
    require(app_inventory(app) == manifest["app_files"], "Extracted local product files differ from the built app")
    info = plistlib.loads((app / "Info.plist").read_bytes())
    require(info.get("CFBundleIdentifier") == bundle_id
            and info.get("CFBundleExecutable") == manifest["executable_name"], "Local extracted app identity differs")
    require(digest(app / info["CFBundleExecutable"]) == manifest["executable_sha256"],
            "Local extracted executable differs from the actual build")
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True, timeout=60)
    output.mkdir(parents=True, exist_ok=True)
    result = {
        "status": "EXACT_ACTUAL_SIMULATOR_PRODUCT_RESTORED",
        "execution_origin": "local-mac", "artifact_id": None, "github_run_id": None,
        "manifest_path": str(path), "manifest_sha256": digest(path),
        "producer_manifest": manifest, "producer_native_acceptance_status": manifest["native_acceptance_status"],
        "note": "Actual local app build admitted. Separate producer UI acceptance and physical signing are not promoted by this consumer gate.",
    }
    (output / "producer-admission.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    return result
