#!/usr/bin/env python3
"""Fail closed unless every selected Swift XCTest method actually passed."""
import argparse
import json
from pathlib import Path
import re
import subprocess


def declared_methods(source_directory=Path("Maktabah-iOSUITests")):
    """Syntax-only Swift compiler declarations; this grants no runtime PASS.

    The old source regex assigned extensions to the next class and missed
    same-line actor attributes. Let the installed Swift frontend parse Swift,
    then take only direct zero-argument test members of actual top-level class
    and extension nodes. Nested functions, comments and string literals cannot
    provide declarations. Unknown compiler output or ambiguity fails closed.
    """
    sources = sorted(Path(source_directory).glob("*.swift"))
    if not sources:
        raise ValueError("No actual XCTest source files")
    methods, classes, receivers = {}, set(), set()
    # -dump-parse emits the primary source only. Parse every actual file
    # explicitly; secondary filenames must never be mistaken for coverage.
    for source in sources:
        parsed = subprocess.run(
            ["swiftc", "-frontend", "-dump-parse", "-D", "DEBUG", str(source)],
            capture_output=True, text=True, encoding="utf-8", timeout=90, check=False)
        if parsed.returncode:
            raise ValueError("Actual Swift frontend could not parse XCTest source: " + str(source))
        current = None
        for line in parsed.stdout.splitlines():
            if line.startswith("(source_file"):
                current = None
            declaration = re.match(r'^  \((class_decl|extension_decl)\b.*?\s"(\w+)"(?:\s|$)', line)
            if declaration:
                kind, current = declaration.groups()
                if kind == "class_decl":
                    if current in classes:
                        raise ValueError("Duplicate XCTest class declaration: " + current)
                    classes.add(current)
                else:
                    receivers.add(current)
                methods.setdefault(current, [])
            elif re.match(r"^  \(\w+", line):
                current = None
            method = re.match(r'^    \(func_decl\b.*?\s"(test\w+)\(\)"(?:\s|$)', line)
            if current and method:
                methods[current].append(method[1])
    if not classes or not any(methods.values()):
        raise ValueError("Swift declaration output contained no actual test classes/methods")
    for receiver in receivers:
        if receiver not in classes:
            # Other imported types may have harmless helpers in this directory,
            # but cannot supply an unknown XCTest class through an extension.
            methods.pop(receiver, None)
    return {name: methods.get(name, []) for name in classes}


def validate_selections(suites, source_directory=Path("Maktabah-iOSUITests")):
    """Resolve exact declared ownership; no log or UI execution is considered."""
    try:
        methods = declared_methods(source_directory)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        return {"status": "FAIL", "source_error": str(error), "suites": []}
    results = []
    for selection in suites:
        suite, separator, selected_method = selection.partition("/")
        declared = methods.get(suite, [])
        expected = ([method for method in declared if method == selected_method]
                    if separator else declared)
        unique = bool(expected) and len(expected) == len(set(expected))
        if separator:
            unique = unique and len(expected) == 1 and re.fullmatch(r"\w+/test\w+", selection) is not None
        results.append({"suite": suite, "selection": selection, "expected": expected,
                        "status": "DECLARATIONS_MATCH" if unique else "FAIL"})
    return {"suites": results,
            "status": "DECLARATIONS_MATCH" if results and all(row["status"] == "DECLARATIONS_MATCH" for row in results) else "FAIL"}


def verify(log, suites, source_directory=Path("Maktabah-iOSUITests")):
    declaration_report = validate_selections(suites, source_directory)
    if declaration_report["status"] != "DECLARATIONS_MATCH":
        return {"suites": declaration_report["suites"], "status": "FAIL",
                "declaration_status": "FAIL", "source_error": declaration_report.get("source_error")}
    results = []
    for declaration in declaration_report["suites"]:
        selection, suite, expected = declaration["selection"], declaration["suite"], declaration["expected"]
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
