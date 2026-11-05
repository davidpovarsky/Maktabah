#!/usr/bin/env python3
"""Fail closed unless every selected Swift XCTest method actually passed."""
import argparse
import json
from pathlib import Path
import re


def verify(log, suites, source_directory=Path("Maktabah-iOSUITests")):
    sources = "\n".join(path.read_text(encoding="utf-8") for path in sorted(source_directory.glob("*.swift")))
    declarations = list(re.finditer(r"(?m)^(?:final\s+)?class\s+(\w+)\s*:[^\n]+\{", sources))
    methods = {}
    for index, declaration in enumerate(declarations):
        end = declarations[index + 1].start() if index + 1 < len(declarations) else len(sources)
        methods[declaration[1]] = re.findall(r"(?m)^\s+func\s+(test\w+)\s*\(", sources[declaration.end():end])
    results = []
    for selection in suites:
        suite, separator, selected_method = selection.partition("/")
        declared = methods.get(suite, [])
        expected = [selected_method] if separator and selected_method in declared else ([] if separator else declared)
        passed, failed = [], []
        for method in expected:
            # Xcode's Objective-C XCTest display name and its dotted equivalent.
            pattern = r"Test Case '[^'\n]*\b" + re.escape(suite) + r"(?:\s+|\.)" + re.escape(method) + r"(?:\(\))?\]?' (passed|failed)"
            statuses = re.findall(pattern, log)
            if "passed" in statuses:
                passed.append(method)
            if "failed" in statuses:
                failed.append(method)
        missing = [method for method in expected if method not in passed]
        results.append({"suite": suite, "selection": selection, "expected": expected, "passed": passed, "failed": failed, "missing": missing,
                        "status": "EXECUTED_PASS" if expected and not missing and not failed else "FAIL"})
    return {"suites": results, "status": "EXECUTED_PASS" if results and all(value["status"] == "EXECUTED_PASS" for value in results) else "FAIL"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("suites", nargs="+")
    args = parser.parse_args()
    report = verify(args.log.read_text(encoding="utf-8"), args.suites)
    args.out.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    raise SystemExit(0 if report["status"] == "EXECUTED_PASS" else 1)
