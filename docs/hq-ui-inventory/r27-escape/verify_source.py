"""Record syntax/source checks only. This is not Apple SDK or UI verification."""
from pathlib import Path
import hashlib
import json
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BASE = "29f8b4d39c7ea7b49d359a8c57236094e623a9ad"
CANDIDATE = "75ea765de3d768402bf89798b6006b2aea7f9477"
PATHS = [
    "Source/ChavrusaText/Dependencies/CommandPalette/Sources/CommandPalette/Views/CommandPaletteView.swift",
    "Source/ChavrusaText/ToolbarSearch/LibraryCommandPaletteAdapter.swift",
]


def capture(*command):
    return subprocess.check_output(command, cwd=ROOT)


def digest(value):
    return hashlib.sha256(value).hexdigest()


changed = capture("git", "diff", "--name-only", BASE, CANDIDATE).decode().splitlines()
assert sorted(changed) == sorted(PATHS), changed
source = {}
for path in PATHS:
    current = (ROOT / path).read_text(encoding="utf-8").encode("utf-8")
    committed = capture("git", "show", CANDIDATE + ":" + path)
    assert current == committed, "Worktree differs from tested candidate: " + path
    source[path] = {"base_lf_sha256": digest(capture("git", "show", BASE + ":" + path)),
                    "candidate_lf_sha256": digest(committed)}

commands = [
    ["swiftc", "-frontend", "-parse", "-target", "arm64-apple-ios17.0", *PATHS],
    ["swiftc", "-frontend", "-parse", "-target", "arm64-apple-macosx14.0", *PATHS],
    ["git", "diff", "--check", BASE, CANDIDATE],
    ["git", "apply", "--reverse", "--check", "--unidiff-zero", str(HERE / "source.patch")],
]
results = []
for command in commands:
    result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    results.append({"command": command, "exit_code": result.returncode, "output": result.stdout.rstrip()})
report = {"base": BASE, "candidate_source_commit": CANDIDATE,
          "toolchain": capture("swiftc", "--version").decode().strip(), "source": source,
          "commands": results, "Apple_SDK_typechecks": 0, "native_UI_tests_executed_by_U": 0,
          "prior_actual_R27": {"run": 43688380348, "passed": 8, "failed": 1, "skipped": 0},
          "candidate_native_result": "PENDING_T_Q"}
(HERE / "verification.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
for result in results:
    print(str(result["exit_code"]) + ": " + " ".join(result["command"]))
if any(result["exit_code"] for result in results):
    raise SystemExit(1)
print("PASS: syntax/source/patch checks only; Apple SDK typechecks 0; native UI tests 0")
