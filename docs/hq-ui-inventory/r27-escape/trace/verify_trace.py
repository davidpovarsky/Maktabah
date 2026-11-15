"""Syntax/source checks only for the diagnostic patch; no native UI proof."""
from pathlib import Path
import hashlib
import json
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BASE = "f886e629f8d718f5c55215d644ac939923bfc192"
SOURCE = "914fa87f5b93e2667571001cd0c762ef58589d88"
FAILED = "6a54a44f"
PATHS = [
    "Source/ChavrusaText/Dependencies/CommandPalette/Sources/CommandPalette/Views/CommandPaletteView.swift",
    "Source/ChavrusaText/ToolbarSearch/LibraryCommandPaletteAdapter.swift",
]


def capture(*args):
    return subprocess.check_output(args, cwd=ROOT)


assert sorted(capture("git", "diff", "--name-only", BASE, SOURCE).decode().splitlines()) == sorted(PATHS)
hashes = {}
for path in PATHS:
    base = capture("git", "show", BASE + ":" + path)
    failed = capture("git", "show", FAILED + ":" + path)
    actual = capture("git", "show", SOURCE + ":" + path)
    assert base == failed, "Diagnostic base differs from failed native input: " + path
    assert actual == (ROOT / path).read_text(encoding="utf-8").encode("utf-8")
    hashes[path] = {"failed_base_lf_sha256": hashlib.sha256(base).hexdigest(),
                    "diagnostic_lf_sha256": hashlib.sha256(actual).hexdigest()}

commands = [
    ["swiftc", "-frontend", "-parse", "-target", "arm64-apple-ios17.0", *PATHS],
    ["swiftc", "-frontend", "-parse", "-target", "arm64-apple-macosx14.0", *PATHS],
    ["git", "diff", "--check", BASE, SOURCE],
    ["git", "apply", "--reverse", "--check", "--unidiff-zero", str(HERE / "source.patch")],
]
results = []
for command in commands:
    result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    results.append({"command": command, "exit_code": result.returncode, "output": result.stdout.rstrip()})
report = {"diagnostic_source_commit": SOURCE, "base": BASE,
          "failed_native_checkout": capture("git", "rev-parse", FAILED).decode().strip(),
          "source_hashes": hashes, "commands": results,
          "toolchain": capture("swiftc", "--version").decode().strip(),
          "diagnostic_Apple_SDK_builds_by_U": 0, "native_UI_tests_by_U": 0,
          "native_diagnostic_result": "PENDING_T_Q", "native_previous_affected_case": "FAIL"}
(HERE / "verification.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
for result in results:
    print(str(result["exit_code"]) + ": " + " ".join(result["command"]))
if any(result["exit_code"] for result in results):
    raise SystemExit(1)
print("PASS: diagnostic source/syntax checks only; Apple SDK builds 0; native UI tests 0")
