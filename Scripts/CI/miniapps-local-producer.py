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
import tempfile
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



def git_object(root, *arguments, env=None):
    result = subprocess.run(["git", "-C", str(root), "-c", "core.sparseCheckout=false",
                             "-c", "core.splitIndex=false", "-c", "gc.auto=0",
                             "-c", "maintenance.auto=false", *arguments],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env, timeout=120)
    require(result.returncode == 0, "Cannot verify producer preparation with Git: "
            + result.stderr.decode(errors="replace")[-2000:])
    return result.stdout


def prepared_source_tree(identity, sdk_root, source_sha, source_tree, review_spec,
                         export_directory, consumer_root, object_env):
    """Admit only a separately committed review of the exact generated delta."""
    status = identity.get("git_status_porcelain", "")
    require(isinstance(status, str), "Invalid producer preparation status")
    fields = ("preparation_diff_name", "preparation_diff_sha256", "prepared_tree")
    if review_spec is None:
        require(status == "", "Dirty producer preparation requires a committed review")
        if any(key in identity for key in fields):
            require(all(key in identity for key in fields) and export_directory is not None,
                    "Incomplete producer preparation identity")
            patch = contained_file(export_directory, identity["preparation_diff_name"])
            require(patch.read_bytes() == b"" and digest(patch) == identity["preparation_diff_sha256"]
                    and identity["prepared_tree"] == source_tree,
                    "Prepared producer source requires a committed review")
        return source_tree
    require(isinstance(review_spec, dict) and set(review_spec) == {"path", "sha256"},
            "Producer preparation requires its exact committed review")
    name, expected = review_spec["path"], review_spec["sha256"]
    require(isinstance(name, str) and name.startswith("Scripts/CI/") and name.endswith(".json")
            and not PurePosixPath(name).is_absolute() and ".." not in PurePosixPath(name).parts
            and "\n" not in name and "\r" not in name and valid_digest(expected),
            "Invalid producer preparation review path or digest")
    consumer_root = Path(consumer_root).resolve(strict=True)
    review_path = consumer_root / name
    require(review_path.is_file() and not review_path.is_symlink()
            and review_path.resolve(strict=True).is_relative_to(consumer_root)
            and digest(review_path) == expected, "Producer preparation review bytes differ")
    committed = git_object(consumer_root, "show", "HEAD:" + name)
    require(committed == review_path.read_bytes(),
            "Producer preparation review is not the exact committed file")
    review = json.loads(committed)
    require(review.get("schema") == "miniapps.producer-preparation-review/1"
            and review.get("producer_sha") == source_sha
            and review.get("source_tree") == source_tree
            and review.get("prepared_tree") == identity.get("prepared_tree"),
            "Producer preparation review is bound to different source trees")
    require(review.get("git_status_porcelain") == status and status,
            "Producer preparation status differs from its review")
    require(export_directory is not None, "Producer preparation export is absent")
    specification = review.get("patch")
    require(isinstance(specification, dict) and set(specification) == {"name", "bytes", "sha256"}
            and specification.get("name") == identity.get("preparation_diff_name")
            and valid_digest(specification.get("sha256"))
            and specification["sha256"] == identity.get("preparation_diff_sha256"),
            "Producer preparation patch identity differs")
    patch = contained_file(export_directory, specification["name"])
    require(type(specification["bytes"]) is int and specification["bytes"] > 0
            and patch.stat().st_size == specification["bytes"]
            and digest(patch) == specification["sha256"], "Producer preparation patch bytes differ")
    changes = review.get("changes")
    require(isinstance(changes, list) and changes, "Producer preparation has no reviewed changes")
    names = []
    for change in changes:
        require(isinstance(change, dict), "Invalid producer preparation change")
        path = change.get("path")
        require(isinstance(path, str) and path and not PurePosixPath(path).is_absolute()
                and ".." not in PurePosixPath(path).parts and "\n" not in path and "\r" not in path
                and "\t" not in path and change.get("status") == "M"
                and isinstance(change.get("reason"), str) and change["reason"].strip(),
                "Producer preparation only admits reviewed regular-file modifications")
        names.append(path)
    require(len(names) == len(set(names)), "Duplicate producer preparation change")
    require(status == "".join(" M " + path + "\n" for path in sorted(names)),
            "Producer preparation contains an unreviewed index or working-tree change")
    git_object(sdk_root, "read-tree", source_sha, env=object_env)
    git_object(sdk_root, "apply", "--cached", "--binary", "--whitespace=nowarn",
               str(patch), env=object_env)
    prepared = git_object(sdk_root, "write-tree", env=object_env).decode().strip()
    require(prepared == review["prepared_tree"],
            "Reconstructed producer preparation tree differs from the reviewed tree")
    raw = git_object(sdk_root, "diff-tree", "--no-commit-id", "--name-status", "-r", "-z",
                     "--no-renames", source_tree, prepared, env=object_env).decode().split("\0")
    require(raw[-1] == "" and len(raw) % 2 == 1, "Invalid prepared source tree delta")
    actual = list(zip(raw[0:-1:2], raw[1:-1:2]))
    require(actual == [("M", name) for name in sorted(names)],
            "Prepared source tree contains unreviewed changes")
    for change in changes:
        for phase, tree in (("before", source_tree), ("after", prepared)):
            entry = git_object(sdk_root, "ls-tree", "-z", tree, "--", change["path"], env=object_env)
            require(entry.endswith(b"\0") and entry.count(b"\0") == 1,
                    "Prepared source file is absent")
            attributes, path = entry[:-1].split(b"\t", 1)
            mode, kind, blob = attributes.decode().split()
            require(path.decode() == change["path"] and kind == "blob" and mode in ("100644", "100755"),
                    "Producer preparation cannot replace a regular file with another kind")
            content = git_object(sdk_root, "cat-file", "blob", blob, env=object_env)
            proof = {"mode": mode, "blob": blob, "bytes": len(content),
                     "sha256": hashlib.sha256(content).hexdigest()}
            require(change.get(phase) == proof, "Producer preparation " + phase + " object differs: " + change["path"])
        require(change["before"]["mode"] == change["after"]["mode"],
                "Producer preparation may not change file permissions")
    return prepared



def validate_source_identity(identity, sdk_root, source_sha, *, review_spec=None,
                             export_directory=None, consumer_root=None):
    require(isinstance(identity, dict) and identity.get("commit") == source_sha,
            "Local producer source identity differs from the consumer SDK")
    sdk_root = Path(sdk_root)
    tree = subprocess.check_output(["git", "-C", str(sdk_root), "rev-parse", source_sha + "^{tree}"],
                                   text=True, timeout=30).strip()
    require(identity.get("tree") == tree, "Local producer source tree differs from its immutable commit")
    objects_name = git_object(sdk_root, "rev-parse", "--git-path", "objects").decode().strip()
    objects = (sdk_root / objects_name).resolve()
    require(objects.is_dir(), "Producer Git object store is missing")
    # Applying a reviewed patch creates blobs and trees. Keep them private for
    # the complete verification, including the subsequent source cat-file read.
    # The active producer index, worktree and object store stay read-only.
    with tempfile.TemporaryDirectory(prefix="miniapps-prepared-source-") as folder:
        private = Path(folder)
        (private / "objects").mkdir()
        environment = dict(os.environ, GIT_INDEX_FILE=str(private / "index"),
                           GIT_OBJECT_DIRECTORY=str(private / "objects"),
                           GIT_ALTERNATE_OBJECT_DIRECTORIES=str(objects),
                           GIT_NO_LAZY_FETCH="1", GIT_OPTIONAL_LOCKS="0")
        admitted_tree = prepared_source_tree(identity, sdk_root, source_sha, tree, review_spec,
                                             export_directory, consumer_root or Path(__file__).resolve().parents[2], environment)
        files = identity.get("tracked_file_sha256")
        require(isinstance(files, dict) and files, "Local producer has no original source-file identity")
        require(all(isinstance(path, str) and path and "\n" not in path and "\r" not in path
                    and not PurePosixPath(path).is_absolute() and ".." not in PurePosixPath(path).parts
                    and valid_digest(expected) for path, expected in files.items()),
                "Invalid local producer source-file inventory")
        names = sorted(files)
        requested = "".join(admitted_tree + ":" + name + "\n" for name in names).encode()
        result = subprocess.run(["git", "-C", str(sdk_root), "cat-file", "--batch"],
                                env=environment, input=requested, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120)
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



def validate_export(config, sdk_root, bundle_id, *, consumer_root=None):
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
    validate_source_identity(manifest.get("source_identity"), sdk_root, config["producer_source_sha"],
                             review_spec=config.get("local_producer_preparation"),
                             export_directory=path.parent, consumer_root=consumer_root)
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


def restore(config, destination, output, sdk_root, bundle_id, *, consumer_root=None):
    path, manifest, archive = validate_export(config, sdk_root, bundle_id, consumer_root=consumer_root)
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
        "prepared_source_review": config.get("local_producer_preparation"),
        "producer_manifest": manifest, "producer_native_acceptance_status": manifest["native_acceptance_status"],
        "note": "Actual local app build admitted. Separate producer UI acceptance and physical signing are not promoted by this consumer gate.",
    }
    (output / "producer-admission.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    return result
