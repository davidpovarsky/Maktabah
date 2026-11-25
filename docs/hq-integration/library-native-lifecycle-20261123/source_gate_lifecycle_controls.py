#!/usr/bin/env python3
"""New lifecycle source mutations only; never native or historical-suite credit."""
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[1]).resolve()
base = "00b5c67120a9e76c98f87a49601fb26e84c0cc4c"
path = root / "Scripts/CI/verify-9401-exact-source.py"
spec = importlib.util.spec_from_file_location("lifecycle_source_gate", path)
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
files = {p: subprocess.run(["git", "-C", str(root), "show", base + ":" + p],
                          check=True, capture_output=True).stdout
         for p in gate.MORPH_PRODUCT_PATHS}
candidate = (root / gate.PALETTE).read_text()
files[gate.PALETTE] = candidate.encode()
rows = []
def check(name, source, expected):
    changed = dict(files)
    changed[gate.PALETTE] = source.encode()
    issues = gate.library_morph_issues(changed)
    passed = issues == [] if expected == "accept" else "SINGLE_STABLE_MORPH_SURFACE_REQUIRED" in issues
    rows.append({"case": name, "expected": expected, "issues": issues,
                 "adapter_sha256": hashlib.sha256(source.encode()).hexdigest(),
                 "result": "PASS" if passed else "FAIL"})
    assert passed, rows[-1]

def once(source, old, new):
    assert source.count(old) == 1, old
    return source.replace(old, new, 1)

check("actual_conditional_native_child_unconditional_outer_shell", candidate, "accept")
unconditional = once(candidate, "            if isExpanded {\n", "            Group {\n")
check("unconditionally_mounted_native_child_rejected", unconditional, "reject")

outer = once(unconditional, "        return ZStack(alignment: .topLeading) {\n",
             "        return Group {\n            if isExpanded {\n                ZStack(alignment: .topLeading) {\n")
outer = once(outer, "        .accessibilityHidden(!isExpanded)\n    }\n\n    private func compactContents",
             "        .accessibilityHidden(!isExpanded)\n            }\n        }\n    }\n\n    private func compactContents")
check("conditional_whole_outer_shell_rejected", outer, "reject")

compact = once(candidate, "\n            }\n\n            compactContents(width: compact.width)",
               "\n\n            compactContents(width: compact.width)")
compact = once(compact, "                .accessibilityHidden(true)\n        }\n",
               "                .accessibilityHidden(true)\n            }\n        }\n")
check("compact_child_inside_expanded_branch_rejected", compact, "reject")

surface = once(candidate, "        .modifier(SafariGlass(radius: radius))\n", "")
surface = once(surface, "                .transition(.opacity)\n",
               "                .transition(.opacity)\n                .modifier(SafariGlass(radius: radius))\n")
check("surface_inside_expanded_branch_rejected", surface, "reject")

print(json.dumps({"scope": "Five new lifecycle composition controls; no native acceptance and no old suite replay",
                  "base": base, "checker_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                  "control_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  "cases": rows}, indent=2))
