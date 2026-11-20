"""Exact same-run Release products/evidence handoff; never an acceptance oracle."""
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import posixpath
import re
import stat
import subprocess
import tarfile
import zipfile

import runtime27_final_push as final_push

PROTOCOL = "runtime27-release-handoff-v1"
REPOSITORY = "davidpovarsky/Maktabah"
REPOSITORY_ID = 1280062128
WORKFLOW = ".github/workflows/sefaria-embedded-validation.yml"
PRODUCT_ROOTS = (
    "build/DerivedData/Build/Products",
    "build/SafariPrototypeReference/DerivedData/Build/Products/Debug-iphonesimulator/SafariPrototypeReference.app",
)
ALLOWED_ROOTS = PRODUCT_ROOTS + ("build/hq-stage2", "build/artifacts")
KINDS = {
    "build": ("runtime27-release-build-handoff", "Release build and prototype", "RELEASE_BUILD_ONLY_PASS"),
    "native": ("runtime27-release-native-handoff", "Release native matrix (partial acceptance)",
               "RELEASE_NATIVE_MATRIX_ONLY_PASS"),
}
MAX_TRANSFER_BYTES = 6 * 1024**3
MAX_UNPACKED_BYTES = 12 * 1024**3


def require(value, reason):
    if not value:
        raise ValueError(reason)


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_bytes((json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode())
    temporary.replace(path)


def read_json(path):
    return json.loads(Path(path).read_bytes())


def capture(root, *command):
    return subprocess.check_output(command, cwd=root, text=True, encoding="utf-8", timeout=120).strip()


def positive_integer(value):
    return type(value) is int and value > 0


def safe_relative(name):
    require(isinstance(name, str) and name and "\\" not in name, "Invalid handoff path")
    value = PurePosixPath(name)
    require(not value.is_absolute() and ".." not in value.parts and "." not in name.split("/")
            and not re.match(r"^[A-Za-z]:", name) and value.as_posix() == name, "Unsafe handoff path")
    require(any(name == base or name.startswith(base + "/") for base in ALLOWED_ROOTS),
            "Handoff member is outside the owned build products/evidence")
    return value


def member_record(root, path):
    name = path.relative_to(root).as_posix()
    safe_relative(name)
    info = path.lstat()
    row = {"path": name, "mode": stat.S_IMODE(info.st_mode)}
    require(not row["mode"] & 0o7000, "Privileged product permissions")
    if path.is_symlink():
        link = os.readlink(path)
        require(not PurePosixPath(link).is_absolute() and "\\" not in link, "Absolute product link")
        target = posixpath.normpath(str(PurePosixPath(name).parent / link))
        safe_relative(target)
        require(path.resolve().is_relative_to(root.resolve()), "Product symlink escapes checkout")
        row.update(kind="symlink", target=link)
    elif path.is_dir():
        row.update(kind="directory")
    else:
        require(stat.S_ISREG(info.st_mode), "Special file in handoff")
        row.update(kind="file", bytes=info.st_size, sha256=digest(path))
    return row


def inventory(root, paths):
    root = Path(root)
    found = {}
    for path in paths:
        require(path.exists() or path.is_symlink(), "Missing handoff input: " + str(path))
        entries = [path] + (list(path.rglob("*")) if path.is_dir() and not path.is_symlink() else [])
        for entry in entries:
            row = member_record(root, entry)
            found[row["path"]] = row
    return [found[name] for name in sorted(found)]


def product_inventory(root):
    return inventory(Path(root), [Path(root) / name for name in PRODUCT_ROOTS])


def reviewed_driver_inputs(root):
    """The source auditor handles app/dependencies; also bind actual CI/test bytes.

    Pods' separately audited project/privacy generation is outside these roots.
    A changed helper or test must not inherit the immutable checkout's identity.
    """
    raw = subprocess.check_output([
        "git", "ls-tree", "-r", "-z", "HEAD", "--", WORKFLOW, "Scripts/CI",
        "Maktabah-iOSUITests", "docs/hq-integration/runtime27", "tools/verify_xcresult_zero_skips.py"
    ], cwd=root, timeout=120)
    expected = {}
    for entry in raw.split(b"\0"):
        if entry:
            meta, name = entry.split(b"\t", 1)
            require(meta.split()[1] == b"blob", "Unexpected handoff driver gitlink")
            expected[name.decode("utf-8")] = meta.split()[2].decode()
    require(expected, "Missing reviewed handoff source inventory")
    actual = subprocess.check_output(["git", "hash-object", "--no-filters", "--stdin-paths"],
        cwd=root, input=("\n".join(expected) + "\n").encode(), timeout=120).decode().splitlines()
    require(actual == list(expected.values()), "Actual workflow/helper/test bytes differ from immutable source")
    return {"files": len(expected), "sha256": hashlib.sha256(
        json.dumps(expected, sort_keys=True, separators=(",", ":")).encode()).hexdigest()}


def _manual_context(root):
    root = Path(root)
    expected = os.environ.get("EXPECTED_CHECKOUT_SHA", "")
    require(re.fullmatch("[a-f0-9]{40}", expected), "Missing immutable Release checkout")
    require(capture(root, "git", "rev-parse", "HEAD") == expected, "Release checkout moved")
    require(os.environ.get("GITHUB_REPOSITORY") == REPOSITORY
            and os.environ.get("GITHUB_SHA") == expected, "Release workflow and checkout differ")
    run_id, attempt = int(os.environ["GITHUB_RUN_ID"]), int(os.environ["GITHUB_RUN_ATTEMPT"])
    require(positive_integer(run_id) and positive_integer(attempt), "Invalid workflow identity")
    runtime_id = os.environ.get("FAITHFUL_RUNTIME27_IDENTIFIER")
    require(runtime_id, "Missing explicitly selected runtime")
    runtimes = json.loads(capture(root, "xcrun", "simctl", "list", "runtimes", "-j"))["runtimes"]
    selected = [row for row in runtimes if row.get("identifier") == runtime_id and row.get("isAvailable")]
    require(len(selected) == 1, "Producer runtime is unavailable")
    runtime = selected[0]
    sdk = capture(root, "xcrun", "--sdk", "iphonesimulator", "--show-sdk-version")
    require(sdk.split(".")[0] == "27" and runtime["version"].split(".")[:2] == sdk.split(".")[:2],
            "Release requires the original SDK-matched OS27 runtime")
    require(runtime.get("buildversion") or runtime.get("buildVersion"), "Missing actual runtime build")
    return {
        "repository": REPOSITORY, "workflow": WORKFLOW, "checkout_sha": expected,
        "run_id": run_id, "run_attempt": attempt,
        "trees": {path: capture(root, "git", "rev-parse", "HEAD:" + path)
                  for path in ["Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests"]},
        "release_manifest_sha256": digest(root / "Scripts/CI/runtime27-release-manifest.json"),
        "inputs_sha256": digest(root / "Scripts/CI/hq-stage2-focused-apple.inputs.json"),
        "workflow_sha256": digest(root / WORKFLOW),
        "reviewed_driver_inputs": reviewed_driver_inputs(root),
        "xcode": capture(root, "xcodebuild", "-version"),
        "swift_compiler": capture(root, "xcrun", "swiftc", "--version").splitlines()[0],
        "sdk": sdk,
        "runtime": {"identifier": runtime_id, "version": runtime["version"],
                    "build": runtime.get("buildversion") or runtime.get("buildVersion")},
    }


def context(root):
    if os.environ.get("GITHUB_EVENT_NAME") != "push":
        return _manual_context(root)
    final_push.environment_identity("release")
    return final_push.release_context(root, _manual_context(root))


def resolve_carried_link(name, rows):
    """Resolve framework aliases using only the carried, authenticated inventory."""
    current, seen = name, set()
    for _ in range(40):
        safe_relative(current)
        require(current not in seen, "Cyclic product link")
        seen.add(current)
        parts = PurePosixPath(current).parts
        for count in range(1, len(parts) + 1):
            prefix = PurePosixPath(*parts[:count]).as_posix()
            item = rows.get(prefix)
            if item and item["kind"] == "symlink":
                target = item.get("target", "")
                require(target and not PurePosixPath(target).is_absolute() and "\\" not in target,
                        "Unsafe symlink target")
                current = posixpath.normpath(str(PurePosixPath(prefix).parent / target / PurePosixPath(*parts[count:])))
                break
        else:
            require(current in rows, "Uncarried symlink target")
            return current
    raise ValueError("Excessive product link depth")


def validate_receipt(receipt, expected_context, kind, expected_archive_sha=None):
    require(kind in KINDS and receipt.get("protocol") == PROTOCOL and receipt.get("kind") == kind,
            "Unexpected Release handoff protocol/stage")
    require(receipt.get("context") == expected_context, "Release source/run/attempt/toolchain/input drift")
    require(receipt.get("stage_status") == KINDS[kind][2]
            and receipt.get("full_release_acceptance") is False, "Partial handoff cannot claim full Release")
    archive = receipt.get("archive", {})
    require(re.fullmatch("[a-f0-9]{64}", archive.get("sha256", ""))
            and positive_integer(archive.get("bytes")) and archive["bytes"] <= MAX_TRANSFER_BYTES,
            "Invalid handoff archive fingerprint")
    if expected_archive_sha is not None:
        require(archive["sha256"] == expected_archive_sha, "Different producer archive output")
    rows = receipt.get("members", [])
    require(rows and len(rows) == len({row.get("path") for row in rows}), "Missing/duplicate handoff inventory")
    require(sum(row.get("bytes", 0) for row in rows) <= MAX_UNPACKED_BYTES, "Oversized handoff")
    by_name = {row["path"]: row for row in rows}
    for row in rows:
        safe_relative(row["path"])
        require(type(row.get("mode")) is int and 0 <= row["mode"] <= 0o777, "Unsafe handoff mode")
        require(row.get("kind") in {"file", "directory", "symlink"}, "Unsafe handoff member type")
        if row["kind"] == "file":
            require(type(row.get("bytes")) is int and row["bytes"] >= 0
                    and re.fullmatch("[a-f0-9]{64}", row.get("sha256", "")), "Invalid member fingerprint")
        if row["kind"] == "symlink":
            target = row.get("target", "")
            require(target and not PurePosixPath(target).is_absolute() and "\\" not in target,
                    "Unsafe symlink target")
            resolved = resolve_carried_link(row["path"], by_name)
            for base in PRODUCT_ROOTS:
                if row["path"] == base or row["path"].startswith(base + "/"):
                    require(resolved == base or resolved.startswith(base + "/"),
                            "Product link crosses its immutable product root")
    if kind == "build":
        expected_products = [row for row in rows if any(row["path"] == base or row["path"].startswith(base + "/")
                                                      for base in PRODUCT_ROOTS)]
        require(expected_products and receipt.get("products") == expected_products,
                "Build product inventory differs from the actual carried products")
        require(all(any(row["path"] == base and row["kind"] == "directory" for row in expected_products)
                    for base in PRODUCT_ROOTS), "Missing original product root")


def pack(root, destination, kind, paths, producer_context, stage_status, *, products=None):
    root, destination = Path(root), Path(destination)
    require(kind in KINDS and stage_status == KINDS[kind][2], "Wrong producer stage outcome")
    destination.mkdir(parents=True, exist_ok=True)
    archive = destination / (kind + ".tar.gz")
    require(not archive.exists(), "Handoff archive already exists")
    rows = inventory(root, paths)
    with tarfile.open(archive, "w:gz", compresslevel=3, dereference=False) as output:
        for row in rows:
            path = root / row["path"]
            info = output.gettarinfo(str(path), arcname=row["path"])
            # Hard-linked build files are stored as independent exact regular bytes.
            if row["kind"] == "file":
                info.type, info.linkname, info.size = tarfile.REGTYPE, "", row["bytes"]
            info.uid = info.gid = 0
            info.uname = info.gname = ""
            if row["kind"] == "file":
                with path.open("rb") as source:
                    output.addfile(info, source)
            else:
                output.addfile(info)
    receipt = {"protocol": PROTOCOL, "kind": kind, "context": producer_context,
               "stage_status": stage_status, "full_release_acceptance": False,
               "archive": {"name": archive.name, "bytes": archive.stat().st_size, "sha256": digest(archive)},
               "members": rows, "products": products or []}
    validate_receipt(receipt, producer_context, kind)
    write_json(destination / (kind + ".json"), receipt)
    return receipt


def extract(root, archive, receipt, expected_context, kind, expected_archive_sha):
    root, archive = Path(root), Path(archive)
    validate_receipt(receipt, expected_context, kind, expected_archive_sha)
    require(archive.stat().st_size == receipt["archive"]["bytes"] and digest(archive) == expected_archive_sha,
            "Handoff archive bytes changed")
    expected = {row["path"]: row for row in receipt["members"]}
    with tarfile.open(archive, "r:gz") as packed:
        members = packed.getmembers()
        require(len(members) == len(expected) and {item.name for item in members} == expected.keys(),
                "Archive has missing/extra/duplicate members")
        for member in members:
            row = expected[member.name]
            require((member.isfile() and row["kind"] == "file")
                    or (member.isdir() and row["kind"] == "directory")
                    or (member.issym() and row["kind"] == "symlink"), "Archive member type changed")
            require(member.mode == row["mode"], "Archive member permissions changed")
            require(not member.islnk() and not member.isdev(), "Unsupported archive link/device")
            if member.isfile():
                require(member.size == row["bytes"], "Archive member size changed")
                with packed.extractfile(member) as stream:
                    require(hashlib.file_digest(stream, "sha256").hexdigest() == row["sha256"],
                            "Archive member digest changed")
            if member.issym():
                require(member.linkname == row["target"], "Archive link changed")
        # Verify the complete archive before making any member available for execution.
        for member in sorted(members, key=lambda item: (item.issym(), len(PurePosixPath(item.name).parts), item.name)):
            row = expected[member.name]
            destination = root / member.name
            require(destination.parent.resolve().is_relative_to(root.resolve()), "Extraction parent escaped checkout")
            if destination.exists() or destination.is_symlink():
                require(member_record(root, destination) == row, "Refusing to replace different existing evidence/products")
                continue
            destination.parent.mkdir(parents=True, exist_ok=True)
            if member.isdir():
                destination.mkdir()
            elif member.issym():
                destination.symlink_to(member.linkname)
            else:
                with packed.extractfile(member) as source, destination.open("xb") as output:
                    while chunk := source.read(1024 * 1024):
                        output.write(chunk)
            if not member.issym():
                destination.chmod(row["mode"])
            require(member_record(root, destination) == row, "Restored member differs from producer")


def verify_products(root, receipt):
    expected = receipt.get("products", [])
    require(expected and product_inventory(Path(root)) == expected, "Original Debug/prototype products changed")
    return {"status": "EXACT_ORIGINAL_PRODUCTS", "members": len(expected),
            "inventory_sha256": hashlib.sha256(json.dumps(expected, sort_keys=True).encode()).hexdigest()}


def original_xctestrun(root, receipt):
    products = Path(root) / PRODUCT_ROOTS[0]
    candidates = sorted(products.glob("Maktabah-iOS_iphonesimulator*-arm64.xctestrun"))
    require(len(candidates) == 1, "Missing/ambiguous original xctestrun")
    path = candidates[0]
    row = next((r for r in receipt["products"] if r["path"] == path.relative_to(root).as_posix()), None)
    require(row and row["kind"] == "file" and digest(path) == row["sha256"], "Original xctestrun bytes changed")
    document = plistlib.loads(path.read_bytes())
    require(document.get("__xctestrun_metadata__", {}).get("FormatVersion") == 1,
            "Unreviewed Xcode-generated test-run format; do not rewrite it")
    require(set(document) == {"Maktabah-iOSUITests", "__xctestrun_metadata__"}, "Unexpected original test targets")
    target = document["Maktabah-iOSUITests"]
    require(target.get("IsUITestBundle") is True and target.get("IsXCTRunnerHostedTestBundle") is True,
            "Original product is not the native UI test target")
    for name, value in {
        "TestHostPath": "__TESTROOT__/Debug-iphonesimulator/Maktabah-iOSUITests-Runner.app",
        "TestBundlePath": "__TESTHOST__/PlugIns/Maktabah-iOSUITests.xctest",
        "UITargetAppPath": "__TESTROOT__/Debug-iphonesimulator/Maktabah.app",
    }.items():
        require(target.get(name) == value, "Original test products are not relocatable: " + name)
    require(not target.get("SkipTestIdentifiers") and not target.get("OnlyTestIdentifiers"),
            "A filtered test-run file cannot replace explicit Release selections")
    return path


def validate_artifact_metadata(metadata, run, jobs, expected_context, kind, artifact_id):
    require(kind in KINDS and positive_integer(artifact_id), "Invalid handoff artifact request")
    if "push_authority" in expected_context or expected_context.get("workflow") == final_push.ROUTES["release"]["workflow"]:
        final_push.validate_release_run(run, expected_context)
    else:
        require(positive_integer(run.get("id")) and positive_integer(run.get("run_attempt"))
                and run.get("id") == expected_context["run_id"] and run.get("run_attempt") == expected_context["run_attempt"]
                and run.get("head_sha") == expected_context["checkout_sha"]
                and run.get("event") == "workflow_dispatch" and run.get("path", "").split("@")[0] == WORKFLOW,
                "Handoff workflow source/attempt mismatch")
    origin = metadata.get("workflow_run", {})
    require(metadata.get("id") == artifact_id and metadata.get("name") == KINDS[kind][0]
            and metadata.get("expired") is False and origin.get("id") == expected_context["run_id"]
            and origin.get("head_sha") == expected_context["checkout_sha"]
            and origin.get("repository_id") == origin.get("head_repository_id") == REPOSITORY_ID,
            "Handoff artifact provenance mismatch")
    require(positive_integer(metadata.get("size_in_bytes")) and metadata["size_in_bytes"] <= MAX_TRANSFER_BYTES
            and re.fullmatch(r"sha256:[a-f0-9]{64}", metadata.get("digest", "")), "Invalid artifact digest/size")
    producers = [job for job in jobs if job.get("name") == KINDS[kind][1]]
    require(len(producers) == 1 and producers[0].get("status") == "completed"
            and producers[0].get("conclusion") == "success", "Producer job did not finish successfully")
    producer = producers[0]
    require(producer.get("run_id") == expected_context["run_id"]
            and producer.get("run_attempt") == expected_context["run_attempt"]
            and producer.get("head_sha") == expected_context["checkout_sha"], "Producer job source/attempt mismatch")
    created = datetime.fromisoformat(metadata["created_at"].replace("Z", "+00:00"))
    require(datetime.fromisoformat(producer["started_at"].replace("Z", "+00:00")) <= created
            <= datetime.fromisoformat(producer["completed_at"].replace("Z", "+00:00")),
            "Artifact upload is outside this successful producer job")
    return producer


def fetch(root, kind, artifact_id, expected_archive_sha, consumer):
    root = Path(root)
    expected_context = context(root)
    require(re.fullmatch("[a-f0-9]{64}", expected_archive_sha), "Missing exact producer archive output")
    def api(path):
        return json.loads(capture(root, "gh", "api", path))
    base = "repos/" + REPOSITORY + "/actions"
    metadata = api(f"{base}/artifacts/{artifact_id}")
    run = api(f"{base}/runs/{expected_context['run_id']}")
    jobs = api(f"{base}/runs/{expected_context['run_id']}/attempts/{expected_context['run_attempt']}/jobs?per_page=100")
    require(jobs.get("total_count") == len(jobs["jobs"]), "Incomplete producer job inventory")
    producer = validate_artifact_metadata(metadata, run, jobs["jobs"], expected_context, kind, artifact_id)
    folder = root / "build/runtime27-handoff/downloads" / str(artifact_id)
    folder.mkdir(parents=True, exist_ok=False)
    archive = folder / "artifact.zip"
    with archive.open("wb") as stream:
        subprocess.run(["gh", "api", f"{base}/artifacts/{artifact_id}/zip"], cwd=root,
                       stdout=stream, check=True, timeout=900)
    require(archive.stat().st_size == metadata["size_in_bytes"]
            and "sha256:" + digest(archive) == metadata["digest"], "GitHub artifact bytes mismatch")
    with zipfile.ZipFile(archive) as packed:
        expected_names = {kind + ".json", kind + ".tar.gz"}
        require(len(packed.infolist()) == 2 and set(packed.namelist()) == expected_names,
                "Unexpected artifact envelope")
        require(sum(row.file_size for row in packed.infolist()) <= MAX_TRANSFER_BYTES,
                "Oversized artifact envelope")
        for row in packed.infolist():
            require(not stat.S_ISLNK(row.external_attr >> 16), "Linked artifact envelope")
            with packed.open(row) as source, (folder / row.filename).open("xb") as output:
                while chunk := source.read(1024 * 1024):
                    output.write(chunk)
    receipt = read_json(folder / (kind + ".json"))
    extract(root, folder / (kind + ".tar.gz"), receipt, expected_context, kind, expected_archive_sha)
    write_json(root / ("build/runtime27-handoff/imported-" + kind + ".json"), receipt)
    proof = {"status": "AUTHENTICATED_SAME_RUN_HANDOFF", "consumer": consumer,
             "artifact_metadata": metadata, "producer_job": producer,
             "workflow": {key: run[key] for key in ["id", "head_sha", "run_attempt", "event", "path"]},
             "archive_sha256": expected_archive_sha, "receipt_sha256": digest(folder / (kind + ".json")),
             "github_job_binding": "Digest/run/head/attempt and unique successful producer/upload interval; GitHub exposes no artifact job ID",
             "full_release_acceptance": False}
    if "push_authority" in expected_context:
        proof["push_workflow"] = {"head_branch": run["head_branch"], **{
            name: {key: run[name][key] for key in ["id", "full_name"]}
            for name in ["repository", "head_repository"]}}
    write_json(root / f"build/artifacts/runtime27/handoff-{kind}-import-{consumer}.json", proof)
    return receipt
