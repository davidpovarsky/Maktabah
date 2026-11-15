"""Record diagnostic source audits and syntax parses, never native UI results."""
from pathlib import Path
import hashlib
import json
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BASE = "86a8b8b47595b11074c2030b9c23b00f4a32addc"
SOURCE = "5c6670b6f213f8a0defb1eadc32260e85c976dc6"
FAILED = "5b46c400"
PATH = "Source/ChavrusaText/Dependencies/CommandPalette/Sources/CommandPalette/Views/CommandPaletteView.swift"


def capture(*args):
    return subprocess.check_output(args, cwd=ROOT)


assert capture("git", "diff", "--name-only", BASE, SOURCE).decode().splitlines() == [PATH]
before = capture("git", "show", BASE + ":" + PATH).decode()
after = capture("git", "show", SOURCE + ":" + PATH).decode()
assert before == capture("git", "show", FAILED + ":" + PATH).decode()
assert after == (ROOT / PATH).read_text(encoding="utf-8")
prefix = "    override var keyCommands: [UIKeyCommand]? {"
tail = "    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {"
assert before[:before.index(prefix)] == after[:after.index(prefix)], "UI/state prefix changed"
assert before[before.index(tail):] == after[after.index(tail):], "Existing event/focus/dismiss actions changed"
assert after.count("super.keyCommands") == after.count("super.target(forAction:") == after.count("super.validate(command)") == 1
commands = [
    ["swiftc", "-frontend", "-parse", "-target", "arm64-apple-ios17.0", PATH],
    ["swiftc", "-frontend", "-parse", "-target", "arm64-apple-macosx14.0", PATH],
    ["git", "diff", "--check", BASE, SOURCE],
    ["git", "apply", "--reverse", "--check", "--unidiff-zero", str(HERE / "source.patch")],
]
results = []
for command in commands:
    result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    results.append({"command": command, "exit_code": result.returncode, "output": result.stdout.rstrip()})
report = {"source": SOURCE, "base": BASE, "failed_checkout": capture("git", "rev-parse", FAILED).decode().strip(),
          "path": PATH, "before_lf_sha256": hashlib.sha256(before.encode()).hexdigest(),
          "after_lf_sha256": hashlib.sha256(after.encode()).hexdigest(),
          "source_audits": ["UI/state prefix identical", "existing event/action tail identical", "one superclass read/call at each added boundary"],
          "commands": results, "toolchain": capture("swiftc", "--version").decode().strip(),
          "Apple_SDK_builds_by_U": 0, "native_UI_tests_by_U": 0, "descriptor_route_values": "NOT_RUN"}
(HERE / "verification.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
for result in results:
    print(str(result["exit_code"]) + ": " + " ".join(result["command"]))
if any(result["exit_code"] for result in results):
    raise SystemExit(1)
print("PASS: source audits/syntax only; native descriptor and route observations NOT_RUN")
