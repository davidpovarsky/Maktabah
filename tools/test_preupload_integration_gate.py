#!/usr/bin/env python3
"""Exercise the upload gate against real, isolated local Git histories."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
output = (root / "build/integration-verification").resolve()
assert output.is_relative_to(root.resolve())
output.mkdir(parents=True, exist_ok=True)
script = root / "Scripts/CI/verify-preupload-integration-source.py"
cases = []
with tempfile.TemporaryDirectory(prefix="preupload-gate-", dir=output) as directory:
    temporary = Path(directory).resolve()
    assert temporary.parent == output  # Recursive fixture cleanup stays in our build directory.
    hooks = temporary / "empty-hooks"
    hooks.mkdir()

    def git(cwd, *arguments):
        command = ["git", "-c", f"core.hooksPath={hooks}", "-c", "user.name=CI Gate Fixture",
                   "-c", "user.email=ci-gate@example.invalid", "-c", "commit.gpgsign=false", *arguments]
        result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, encoding="utf-8")
        assert result.returncode == 0, (arguments, result.stderr)
        return result.stdout.strip()

    origin = temporary / "origin.git"
    git(temporary, "init", "--bare", "--object-format=sha1", str(origin))
    seed = temporary / "seed"
    git(temporary, "clone", str(origin), str(seed))
    git(seed, "checkout", "-b", "main")
    (seed / "fixture.txt").write_text("base", encoding="utf-8")
    git(seed, "add", "fixture.txt")
    git(seed, "commit", "-m", "Fixture base")
    first = git(seed, "rev-parse", "HEAD")
    git(seed, "push", "origin", "main")
    git(seed, "branch", "other-agent")
    git(seed, "push", "origin", "other-agent")
    release = temporary / "release"
    git(temporary, "clone", "--branch", "main", str(origin), str(release))
    environment = os.environ.copy()
    environment.update(GIT_CONFIG_COUNT="1", GIT_CONFIG_KEY_0="core.hooksPath", GIT_CONFIG_VALUE_0=str(hooks))

    def check(name, branch, sha, expected):
        report = temporary / "report.json"
        result = subprocess.run([sys.executable, str(script), "--source-branch", branch,
                                 "--expected-sha", sha, "--report", str(report)], cwd=release,
                                env=environment, capture_output=True, text=True, encoding="utf-8")
        value = json.loads(report.read_text(encoding="utf-8"))
        assert value["status"] == expected and (result.returncode == 0) == (expected == "EXECUTED_PASS"), value
        cases.append({"case": name, "status": "EXECUTED_PASS", "expectedGateStatus": expected})
        return value

    check("included source", "other-agent", first, "EXECUTED_PASS")
    git(seed, "checkout", "other-agent")
    (seed / "fixture.txt").write_text("advanced", encoding="utf-8")
    git(seed, "commit", "-am", "Fixture other source advances")
    git(seed, "push", "origin", "other-agent")
    advanced = git(seed, "rev-parse", "HEAD")
    assert check("advanced source blocked", "other-agent", first, "BLOCKED_SOURCE_ADVANCED")["sourceSHA"] == advanced
    git(release, "merge", "--ff-only", advanced)
    check("synchronized source", "other-agent", advanced, "EXECUTED_PASS")
    check("changed release SHA", "other-agent", first, "FAIL")
    check("missing source branch", "missing-branch", advanced, "FAIL")
    check("invalid source ref", "invalid branch", advanced, "FAIL")

(output / "preupload-gate-results.json").write_text(json.dumps(cases, indent=2) + "\n", encoding="utf-8")
print(f"PASS: {len(cases)} real Git pre-upload gate cases; fixture histories are separate from the working repository")
