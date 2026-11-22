#!/usr/bin/env python3
"""Source-bound Apple Cloud48 and original SQLite import/reopen continuation."""
from pathlib import Path
import argparse, hashlib, importlib.util, io, json, os, re, subprocess, sys, tarfile

ROOT = Path(__file__).resolve().parents[2]
SELF = "Scripts/CI/cloud-import-identity-apple.py"
BINDING = "Scripts/CI/cloud-import-identity-apple.inputs.json"
WORKFLOW = ".github/workflows/otzaria-cloud-import-identity-apple.yml"
BRANCH = "codex/otzaria-cloud-import-identity-apple-20261122"
OUTPUT = ROOT / "build/cloud-import-identity-apple"
CLOUD = "tools/hq-local-annotation-cloud-acceptance.py"
DOC = "docs/hq-integration/completion-20261122/cloud-import-identity"
IMPORT_RUNNER = DOC + "/run-import-controls.py"


def require(value, message):
    if not value:
        raise ValueError(message)


def load(path):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, "Duplicate JSON key: " + key)
            result[key] = value
        return result
    return json.loads(Path(path).read_text(), object_pairs_hook=pairs)


def write(path, value):
    Path(path).write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, timeout=45)


def module(relative, name):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def import_inputs(probe):
    return set(probe.SOURCES) | {
        IMPORT_RUNNER, "Source/ChavrusaText/Annotations/AnnotationCloudImportIdentity.swift",
        "Source/LibraryBackend/LibraryBackendModels.swift",
        "Source/ChavrusaText/Annotations/LocalEditor/AnnotationLocalEditorModels.swift",
        DOC + "/Boundary.swift", DOC + "/OriginalLocator.swift",
        DOC + "/OriginalLocalConnection.swift", DOC + "/CloudImportIdentityControls.swift",
        DOC + "/OSLogBoundary.swift",
    }


def source_context():
    binding = load(ROOT / BINDING)
    head = git("rev-parse", "HEAD").decode().strip()
    require(binding.get("source_sealed") is True, "UNFINALIZED application source")
    source = binding.get("application_source", "")
    require(re.fullmatch(r"[0-9a-f]{40}", source), "Invalid reviewed application commit")
    subprocess.run(["git", "merge-base", "--is-ancestor", source, head], cwd=ROOT,
                   check=True, timeout=45)
    require(not git("diff", "--name-only", source, head, "--", "Source", "Tests", "tools", "Maktabah.xcodeproj"),
            "Application differs from the reviewed source")
    require(not git("status", "--porcelain", "--untracked-files=no"), "Dirty tracked checkout")
    cloud = module(CLOUD, "import_cloud_original_driver")
    probe = module(IMPORT_RUNNER, "original_repository_import_driver")
    required = set(cloud.source_provenance(ROOT)) | import_inputs(probe) | {
        SELF, WORKFLOW, "Scripts/CI/select-runtime27-toolchain.py", "Scripts/CI/runtime27.py",
    }
    require(set(binding.get("source_pins", {})) == required, "Incomplete or extra source closure")
    committed = {}
    for entry in git("ls-tree", "-r", "-z", head, "--", *sorted(required)).split(b"\0"):
        if not entry:
            continue
        metadata, name = entry.split(b"\t", 1)
        mode, kind, object_id = metadata.decode().split()
        require(kind == "blob" and mode in ("100644", "100755"), "Linked or non-file input")
        committed[name.decode()] = object_id
    require(set(committed) == required, "Source is not completely committed")
    files = {}
    for relative in sorted(required):
        require(not Path(relative).is_absolute() and ".." not in Path(relative).parts, "Unsafe source path")
        path = ROOT / relative
        require(path.is_file() and not path.is_symlink(), "Missing or linked input: " + relative)
        raw = path.read_bytes()
        blob = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
        require(blob == committed[relative], "Working bytes differ: " + relative)
        digest = hashlib.sha256(raw).hexdigest()
        require(digest == binding["source_pins"][relative], "Unreviewed input: " + relative)
        files[relative] = digest
    return {"checkout_sha": head, "application_source": source, "files": files,
            "binding_sha256": hashlib.sha256((ROOT / BINDING).read_bytes()).hexdigest()}


def prepare():
    require(sys.platform == "darwin", "Actual Apple host required")
    require(os.environ.get("GITHUB_REPOSITORY") == "davidpovarsky/Maktabah"
            and os.environ.get("GITHUB_REPOSITORY_ID") == "1280062128"
            and os.environ.get("GITHUB_EVENT_NAME") == "push"
            and os.environ.get("GITHUB_REF") == "refs/heads/" + BRANCH,
            "Different owned repository, branch or event")
    observed = source_context()
    require(os.environ.get("GITHUB_SHA") == observed["checkout_sha"]
            and os.environ.get("GITHUB_WORKFLOW_SHA") == observed["checkout_sha"],
            "Workflow/checkout mismatch")
    require(not OUTPUT.exists(), "Preserve prior attempt")
    OUTPUT.mkdir(parents=True)
    observed["run_id"] = os.environ.get("GITHUB_RUN_ID")
    observed["run_attempt"] = os.environ.get("GITHUB_RUN_ATTEMPT")
    write(OUTPUT / "SOURCE_BEFORE.json", observed)
    with tarfile.open(OUTPUT / "exact-inputs.tar.gz", "w:gz") as archive:
        for relative in observed["files"]:
            data = (ROOT / relative).read_bytes()
            member = tarfile.TarInfo(relative)
            member.size = len(data)
            archive.addfile(member, io.BytesIO(data))
    print(json.dumps({"status": "PREPARED", "files": len(observed["files"]), "checkout": observed["checkout_sha"]}))


def collect():
    before = load(OUTPUT / "SOURCE_BEFORE.json")
    report = {"status": "FAILED", "native_ui_executed": 0, "cloudkit_transport_executed": 0,
              "anytype_runtime_executed": 0, "core194_tests_executed": 0, "live_exchange_enabled": False}
    try:
        after = source_context()
        require(after == {key: before[key] for key in after}, "Source changed during execution")
        write(OUTPUT / "SOURCE_AFTER.json", after)
        cloud = module(CLOUD, "verified_original_cloud_driver")
        result = load(OUTPUT / "cloud48/RESULT.json")
        require(result.get("status") == "PASS_APPLE_FOUNDATION_CLOUD48"
                and result.get("execution_selection") == "cloud48"
                and result.get("source_unchanged") is True, "Actual Cloud48 incomplete")
        require(result.get("source_sha") == before["checkout_sha"], "Cloud checkout differs")
        names = cloud.cloud_declaration_names((ROOT / cloud.CLOUD_DECLARATIONS).read_text())
        cloud.verify_cloud_cases(result.get("cloud_cases"), names)
        expected_sources = {path: before["files"][path] for path in cloud.source_provenance(ROOT)}
        require(result.get("source_before") == expected_sources == result.get("source_after"),
                "Cloud source closure differs")
        owned = Path(result["owned_directory"]).resolve()
        require(owned.is_relative_to((OUTPUT / "cloud48").resolve()), "Unowned cloud evidence")
        copied = cloud.verify_copies(ROOT, owned, True)
        require(copied == result.get("compiled_copies_before") == result.get("compiled_copies_after"),
                "Cloud compiled copies differ")
        commands = result.get("commands", [])
        require([row.get("label") for row in commands] == ["compile", "binary-path", "cloud-cases"]
                and all(row.get("exit_code") == 0 and not row.get("timed_out") for row in commands),
                "Missing or failed Cloud48 process")
        require(result.get("cases") == [] and result.get("cold_processes") == [],
                "Unexpected repeated local43/cold2 execution")
        require(all(result.get(key) == 0 for key in (
            "native_ui_executed", "anytype_executed", "cloudkit_transport_executed", "app_relaunch_executed"))
            and result.get("live_exchange_enabled") is False, "Cloud scope widened")
        imported = load(OUTPUT / "import9/RESULT.json")
        source = load(OUTPUT / "import9/SOURCE_MANIFEST.json")
        require(imported.get("status") == "PASS_REAL_REPOSITORY_SQLITE"
                and imported.get("source_unchanged") is True
                and imported.get("logging") == "original Apple OSLog"
                and source.get("head") == before["checkout_sha"], "Actual Apple original Repository incomplete")
        probe = module(IMPORT_RUNNER, "verified_original_import_driver")
        require(set(source["sources"]) == import_inputs(probe)
                and source["sources"] == {path: before["files"][path] for path in source["sources"]},
                "Import source closure differs")
        names = re.findall(r'\.init\(name: "([^"]+)"', (ROOT / (DOC + "/CloudImportIdentityControls.swift")).read_text())
        require(len(names) == 9 and len(set(names)) == 9, "Nine exact original import assertions required")
        processes = [imported["write"], imported["fresh_process_reopen"]]
        for process in processes:
            rows = process.get("cases", [])
            require(len(rows) == 9 and {row.get("name") for row in rows} == set(names)
                    and all(row.get("status") == "PASS" and row.get("failures") == [] for row in rows)
                    and process.get("passed") == 9 and process.get("failed") == 0, "Import/reopen assertion failure")
        pids = [process.get("process_id") for process in processes]
        require(all(type(pid) is int and pid > 0 for pid in pids) and len(set(pids)) == 2,
                "Actual distinct write/reopen processes required")
        require([row.get("label") for row in imported["commands"]] == ["compile-original-repository", "write", "reopen"]
                and all(row.get("exit") == 0 for row in imported["commands"]), "Missing Apple original Repository process")
        report.update(status="PASS_APPLE_CLOUD48_AND_ORIGINAL_IMPORT9_REOPEN9",
                      checkout_sha=before["checkout_sha"], application_source=before["application_source"],
                      cloud48_passed=48, import_passed=9, reopen_passed=9, process_ids=pids)
    except Exception as error:
        report["error"] = repr(error)
    write(OUTPUT / "RESULT.json", report)
    print(json.dumps(report))
    return 0 if report["status"].startswith("PASS_") else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["prepare", "collect"])
    args = parser.parse_args()
    if args.mode == "prepare":
        prepare()
    else:
        raise SystemExit(collect())
