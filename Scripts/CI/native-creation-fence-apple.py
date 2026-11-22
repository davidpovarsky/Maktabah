#!/usr/bin/env python3
"""Exact Apple execution gate for the existing 24 native-create SQLite controls."""
from pathlib import Path
import argparse, hashlib, io, json, os, re, runpy, subprocess, sys, tarfile

ROOT = Path(__file__).resolve().parents[2]
SELF = "Scripts/CI/native-creation-fence-apple.py"
BINDING = "Scripts/CI/native-creation-fence-apple.inputs.json"
WORKFLOW = ".github/workflows/otzaria-native-creation-fence-apple.yml"
BRANCH = "codex/otzaria-native-creation-fence-apple-20261122"
DOC = "docs/hq-integration/completion-20261122/native-creation-fence"
RUNNER = DOC + "/run-native-creation-controls.py"
EXACT = "Scripts/CI/completion-focused-native.py"
TOOLCHAIN = ["Scripts/CI/select-runtime27-toolchain.py", "Scripts/CI/runtime27.py"]
PRODUCT = "Source/ChavrusaText/Annotations/Exchange/AnnotationExchangeLedger.swift"

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
    return json.loads(Path(path).read_text(encoding="utf-8"), object_pairs_hook=pairs)

def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")

def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, timeout=90)

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def declared_inputs():
    probe = runpy.run_path(str(ROOT / RUNNER))
    compiler = {path.relative_to(ROOT).as_posix() for path in probe["compiler_inputs"]()}
    required = compiler | {SELF, WORKFLOW, EXACT, *TOOLCHAIN}
    return probe, compiler, required

def source_context():
    binding = load(ROOT / BINDING)
    require(binding.get("schema") == 1 and binding.get("source_sealed") is True, "Unfinalized component source")
    head = git("rev-parse", "HEAD").decode().strip()
    for key in ["application_source", "closure_source"]:
        require(re.fullmatch(r"[0-9a-f]{40}", binding.get(key, "")), "Invalid " + key)
        subprocess.run(["git", "merge-base", "--is-ancestor", binding[key], head],
                       cwd=ROOT, check=True, timeout=90)
    require(not git("status", "--porcelain", "--untracked-files=no").strip(), "Dirty tracked checkout")
    product_paths = ["Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests"]
    trees = {path: git("rev-parse", "HEAD:" + path).decode().strip() for path in product_paths}
    require(set(binding.get("application_trees", {})) == set(product_paths)
            and trees == binding["application_trees"]
            and all(value == git("rev-parse", binding["application_source"] + ":" + path).decode().strip()
                    for path, value in trees.items()), "Canonical application or UI-test tree changed")
    probe, compiler, required = declared_inputs()
    require(set(binding.get("source_pins", {})) == required, "Incomplete or extra execution closure")
    for relative in required:
        path = ROOT / relative
        require(not Path(relative).is_absolute() and ".." not in Path(relative).parts
                and path.is_file() and not path.is_symlink()
                and path.resolve().is_relative_to(ROOT.resolve()), "Unowned or linked input: " + relative)
    # Reuse the original byte-to-Git-blob validator; do not invoke its Native route.
    records = runpy.run_path(str(ROOT / EXACT))["exact_working_inputs"](sorted(required))
    require(set(records) == required, "Missing committed input")
    # The existing helper already verified every working byte against HEAD.
    # Compare the complete selected Git paths in one operation, not per-file processes.
    require(not git("diff", "--name-only", binding["closure_source"], head, "--", *sorted(required)).strip(),
            "Execution input changed from the sealed source")
    original_fixtures = sorted(path for path in compiler if path.startswith("Tests/"))
    require(not git("diff", "--name-only", binding["application_source"], head, "--", *original_fixtures).strip(),
            "Original application fixture changed")
    for relative, entry in records.items():
        require(entry["sha256"] == binding["source_pins"][relative], "Unreviewed input: " + relative)
    controls = probe["CONTROL"].read_text(encoding="utf-8")
    names = re.findall(r'await run\("([a-z0-9_]+)"', controls)
    uuid_names = re.findall(r'await runUUID\("([a-z0-9_]+)"', controls)
    require(len(names) == 18 and len(uuid_names) == 6 and len(set(names + uuid_names)) == 24,
            "The 24 exact declared controls are required")
    return {"checkout_sha": head, "application_source": binding["application_source"],
            "closure_source": binding["closure_source"], "application_trees": trees,
            "binding_sha256": digest(ROOT / BINDING),
            "files": {key: value["sha256"] for key, value in records.items()},
            "compiler_inputs": sorted(compiler), "selected_cases": names + uuid_names}

def run_identity():
    require(sys.platform == "darwin", "Actual Apple host required")
    require(os.environ.get("GITHUB_REPOSITORY") == "davidpovarsky/Maktabah"
            and os.environ.get("GITHUB_REPOSITORY_ID") == "1280062128"
            and os.environ.get("GITHUB_EVENT_NAME") == "push"
            and os.environ.get("GITHUB_REF") == "refs/heads/" + BRANCH,
            "Different owned repository, branch or event")
    run_id, attempt = os.environ.get("GITHUB_RUN_ID", ""), os.environ.get("GITHUB_RUN_ATTEMPT", "")
    require(re.fullmatch(r"[1-9][0-9]*", run_id) and re.fullmatch(r"[1-9][0-9]*", attempt), "Missing actual run identity")
    return run_id, attempt

def output_paths():
    run_id, attempt = run_identity()
    output = ROOT / "build/native-creation-fence-apple" / (run_id + "-" + attempt)
    return output, output / ("controls-" + run_id + "-" + attempt)

def prepare():
    output, _ = output_paths()
    context = source_context()
    require(os.environ.get("GITHUB_SHA") == context["checkout_sha"]
            and os.environ.get("GITHUB_WORKFLOW_SHA") == context["checkout_sha"], "Workflow/checkout mismatch")
    require(not output.exists(), "Preserve the existing attempt")
    output.mkdir(parents=True)
    run_id, attempt = run_identity()
    write(output / "SOURCE_BEFORE.json", {"source": context, "run_id": run_id, "run_attempt": attempt,
                                         "platform": sys.platform})
    with tarfile.open(output / "exact-inputs.tar.gz", "w:gz") as archive:
        for relative in sorted(context["files"]):
            raw = (ROOT / relative).read_bytes()
            entry = tarfile.TarInfo(relative); entry.size = len(raw)
            archive.addfile(entry, io.BytesIO(raw))
    print(json.dumps({"status": "PREPARED_APPLE_COMPONENT", "checkout": context["checkout_sha"],
                      "inputs": len(context["files"]), "controls": 24}))

def collect():
    output, controls = output_paths()
    report = {"status": "FAILED", "core194_executed": 0, "original_exchange28_executed": 0,
              "cloud48_executed": 0, "native_ui_executed": 0, "native_sdk": 0, "rpc": 0,
              "identity_production_write": 0, "ack_from_new_component": 0}
    # A repeated collector may not rewrite a prior result.
    require(not (output / "RESULT.json").exists(), "Preserve the existing collected result")
    try:
        before = load(output / "SOURCE_BEFORE.json")
        run_id, attempt = run_identity()
        require(before["run_id"] == run_id and before["run_attempt"] == attempt
                and before["platform"] == "darwin", "Different execution attempt")
        context = source_context()
        require(context == before["source"]
                and os.environ.get("GITHUB_SHA") == context["checkout_sha"]
                and os.environ.get("GITHUB_WORKFLOW_SHA") == context["checkout_sha"], "Source/checkout changed")
        write(output / "SOURCE_AFTER.json", context)
        result = load(controls / "RESULT.json")
        manifest = load(controls / "SOURCE_MANIFEST.json")
        require(result.get("status") == "PASS_NEW_NATIVE_CREATION_FENCE_SQLITE"
                and result.get("suite") == "all-controls"
                and result.get("sources_unchanged") is True
                and result.get("copied_sources_unchanged") is True
                and "-apple-" in result.get("swift", "")
                and result.get("platform", "").startswith(("macOS-", "Darwin-")),
                "Actual Apple component incomplete")
        require(manifest.get("head") == context["checkout_sha"]
                and set(manifest["sources"]) == set(context["compiler_inputs"])
                and manifest["sources"] == {p: context["files"][p] for p in context["compiler_inputs"]},
                "Compiler closure differs from source admission")
        require(result.get("reused_owned_build") is False and result.get("copied_input_deltas") == [],
                "This Apple execution requires a fresh owned package")
        require(result.get("original_suites_reexecuted") is False
                and all(result.get(k) == 0 for k in ["native_sdk", "rpc", "transport", "cloudkit_network",
                                                    "identity_production_write", "ack_from_new_component"]),
                "Execution scope widened")
        cases = load(controls / "fixtures/CASES.json") + load(controls / "fixtures/UUID_CASES.json")
        require(cases == result.get("cases") and len(cases) == 24
                and [x.get("name") for x in cases] == context["selected_cases"]
                and all(x.get("status") == "PASS" and x.get("error") is None for x in cases), "Incomplete 24 assertions")
        phases = ["prepared", "marked", "nested"]
        labels = ["compile", "binary-path", "controls"] + [item for p in phases for item in ["crash-" + p, "reopen-" + p]]
        exits = [0, 0, 0] + [value for _ in phases for value in [73, 0]]
        commands = result.get("commands", [])
        require([x.get("label") for x in commands] == labels
                and [x.get("exit") for x in commands] == exits, "Actual compile/abrupt/reopen processes incomplete")
        probe, _, _ = declared_inputs()
        build = probe["HERE"] / "build" / controls.name
        package = build / "package"
        target = package / "Sources/NativeCreationFenceAcceptance"
        require(not (package / "Sources/SQLite3").exists(), "Apple must use the original SDK SQLite3 module")
        copied_paths = list(probe["SOURCES"]) + [probe["CONTROL"].relative_to(ROOT).as_posix()]
        expected_copies = {Path(p).name: context["files"][p] for p in copied_paths}
        require(len(expected_copies) == len(copied_paths)
                and manifest["compiled_copies"] == expected_copies, "Incomplete compiled original sources")
        for name, expected in expected_copies.items():
            path = target / name
            require(path.is_file() and digest(path) == expected, "Compiled copy changed: " + name)
        executable = Path(commands[2]["command"][0]).resolve()
        require(commands[2]["command"] == [str(executable), "all-controls", str(controls / "fixtures")],
                "Different control invocation")
        compile_command = ["swift", "build", "--package-path", str(package),
                           "--scratch-path", str(build / "swift-build"), "-j", "2"]
        require(commands[0]["command"] == compile_command
                and commands[1]["command"] == compile_command + ["--show-bin-path"],
                "Different original compilation")
        for index, phase in enumerate(phases):
            for offset, mode in enumerate(["crash-" + phase, "reopen-" + phase]):
                require(commands[3 + 2 * index + offset]["command"] ==
                        [str(executable), mode, str(controls / "fixtures")], "Different crash/reopen invocation")
        require(executable.is_relative_to(build.resolve()) and executable.is_file()
                and digest(executable) == result.get("executable_sha256"), "Executed binary provenance differs")
        require(len(result.get("crash_processes", [])) == 3, "Missing real crash/reopen pair")
        sqlite_versions, process_pairs = set(), []
        for row, phase in zip(result["crash_processes"], phases):
            writer = load(controls / ("fixtures/writer-" + phase + ".json"))
            reopen = load(controls / ("fixtures/reopen-" + phase + ".json"))
            require(row.get("phase") == phase and row.get("abrupt_exit") == 73
                    and row.get("writer") == writer and row.get("reopen") == reopen, "Raw process receipt differs")
            require(writer.get("phase") == phase and reopen.get("phase") == phase
                    and reopen.get("status") == "PASS" and int(writer["pid"]) > 0 and int(reopen["pid"]) > 0
                    and writer["pid"] != reopen["pid"]
                    and all(reopen.get(k) == "0" for k in ["nativeRPC", "identityWrite", "ACK"]),
                    "Fresh-process reopen or scope failed")
            sqlite_versions.update([writer.get("sqlite"), reopen.get("sqlite")])
            process_pairs.append({"phase": phase, "writer": writer["pid"], "reopen": reopen["pid"]})
        require(len(sqlite_versions) == 1 and all(isinstance(v, str) and v for v in sqlite_versions), "SQLite runtime differs")
        report.update(status="PASS_APPLE_NATIVE_CREATION_FENCE24_CRASH3", checkout_sha=context["checkout_sha"],
                      application_source=context["application_source"], controls_passed=24, crash_reopen_pairs=3,
                      process_pairs=process_pairs, sqlite=next(iter(sqlite_versions)), swift=result["swift"],
                      digest="Original AnnotationExchangePlatformDigest / CryptoKit",
                      executed_binary_sha256=result["executable_sha256"])
    except Exception as error:
        report["error"] = repr(error)
    write(output / "RESULT.json", report)
    print(json.dumps(report))
    return 0 if report["status"].startswith("PASS_") else 1

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["source-check", "prepare", "collect"])
    args = parser.parse_args()
    if args.mode == "source-check":
        print(json.dumps(source_context(), indent=2))
    elif args.mode == "prepare":
        prepare()
    else:
        raise SystemExit(collect())
