#!/usr/bin/env python3
"""Verify the bounded normal iOS workflow delta against the actual failed checkout."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
BASELINE = "e80cd5f2c27993351533f1be9d0890dfaa82cb42"
WORKFLOW = ".github/workflows/ios-build.yml"

def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)

def sha(value):
    return hashlib.sha256(value).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", required=True, type=Path)
    args = parser.parse_args()
    original = git("show", BASELINE + ":" + WORKFLOW)
    actual = (ROOT / WORKFLOW).read_bytes()
    text = actual.decode("utf-8")
    inverse = []
    def replace(before, after, count, label):
        nonlocal text
        assert text.count(before) == count, (label, text.count(before), count)
        text = text.replace(before, after)
        inverse.append({"delta": label, "occurrences": count})
    replace("      - uses: actions/setup-node@v4\n        with:\n          node-version: 22\n"
            "      - uses: ruby/setup-ruby@v1\n        with:\n          ruby-version: '3.3'\n", "", 2, "original Node/Ruby setup")
    replace("      - name: Prepare the original pinned React, Pods workspace, and Embedded bundle\n"
            "        env:\n          GH_TOKEN: $" "{{ secrets.GITHUB_TOKEN }}\n"
            '        run: python3 Scripts/CI/prepare-normal-ios-workspace.py --github-env "$GITHUB_ENV"\n', "", 2, "original preparation adapter")
    replace("            -workspace Maktabah.xcworkspace \\\n", '            -project "$PROJECT_PATH" \\\n', 2, "workspace build selection")
    for configuration, sdk in [("Debug", "iphonesimulator"), ("Release", "iphoneos")]:
        line = "            -configuration " + configuration + " \\\n"
        replace(line, line + "            -sdk " + sdk + " \\\n", 1, "destination-derived SDK " + configuration)
    replace("            ENABLE_USER_SCRIPT_SANDBOXING=NO \\\n"
            "            RCT_NO_LAUNCH_PACKAGER=1 SKIP_BUNDLING=1 FAIL_ON_MISSING_BUNDLE=1 \\\n", "", 2, "original React build settings")
    replace('          python3 Scripts/CI/prepare-normal-ios-workspace.py --verify-app "$APP"\n', "", 2, "built bundle and original source verification")
    replace("          path: |\n            build/logs\n"
            "            build/normal-ios-embedded/*.json\n            build/normal-ios-embedded/*.log\n"
            "            build/normal-ios-embedded/*.diff\n            build/normal-ios-embedded/*Package.resolved\n"
            "            build/normal-ios-embedded/resolved-Podfile.lock\n            build/normal-ios-embedded/*.xcprivacy\n"
            "            build/normal-ios-embedded/privacy-dependency-inputs/*.xcprivacy\n"
            "            build/normal-ios-embedded/ExpoModulesProvider.swift\n",
            "          path: build/logs\n", 2, "bounded preparation log collection")
    assert text.encode("utf-8") == original, "Unlisted workflow edit"
    protected = ["Source", "Vendor", "Maktabah.xcodeproj", "Podfile",
                 "Scripts/CI/hq-stage2-focused-apple.py", "Scripts/CI/hq-stage2-focused-apple.inputs.json",
                 "Scripts/CI/prepare-ios-macro-authorization.py", "Scripts/CI/prepare-hanlin-sdk.py",
                 "Scripts/CI/select-runtime27-toolchain.py", "Scripts/CI/cache-key-inputs.py",
                 "Scripts/run-ipad-simulator-acceptance.sh", "Scripts/CI/test-normal-ios-toolchain.py"]
    assert not git("diff", "--name-only", BASELINE, "--", *protected).strip(), "Protected input change"
    identities = {}
    for path in protected + ["Vendor/HanlinSDK", "Vendor/SefariaMobile/Upstream",
                             "Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"]:
        baseline = git("rev-parse", BASELINE + ":" + path).decode().strip()
        current = git("rev-parse", "HEAD:" + path).decode().strip()
        assert baseline == current, path
        identities[path] = {"baseline": baseline, "current": current}
    report = {"status": "PASS_EXACT_SOURCE_PRESERVATION_ONLY", "baseline": BASELINE,
              "candidate_head": git("rev-parse", "HEAD").decode().strip(),
              "workflow_sha256": sha(actual), "inverse_sha256": sha(text.encode("utf-8")),
              "baseline_workflow_sha256": sha(original), "inverse": inverse, "protected_identities": identities,
              "root_podfile_lock_tracked": bool(git("ls-tree", "HEAD", "--", "Podfile.lock").strip()),
              "all_other_workflow_bytes_preserved": True,
              "actual_apple_or_native_execution": False}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
