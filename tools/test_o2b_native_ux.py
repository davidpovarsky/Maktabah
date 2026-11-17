#!/usr/bin/env python3
"""Narrow O2-B source-contract, syntax-parse, and portable policy checks.

Explicit scope limits (Windows host):
- Validates source contracts, #if DEBUG isolation, standalone SDK-slice
  self-containment, Swift 6 frontend syntax parsing (Release and -D DEBUG),
  and portable Swift ReaderSidebarPolicy execution.
- NOT SwiftUI/UIKit typechecking, app compilation, XCTest UI contrast audit,
  or live iOS Simulator gesture arbitration. Native gates remain NOT_RUN/OPEN.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HISTORY_FILE = ROOT / "Source/ChavrusaText/Search/UI/GlobalSearchHistoryContent.swift"
HEADER_FILE = ROOT / "Source/ChavrusaText/Search/UI/GlobalSearchHeader.swift"
PAGER_FILE = ROOT / "Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift"
POLICY_RUNNER = ROOT / "Scripts/CI/test-native-sidebar-policy.py"


def _parse_version_tuple(text: str) -> tuple[int, ...]:
    match = re.search(r"(\d+(?:\.\d+)*)", text)
    if not match:
        return ()
    return tuple(int(part) for part in match.group(1).split("."))


def _swift_compiler_info(swiftc_path: str | None = None) -> tuple[str | None, str | None, list[Path]]:
    exe = swiftc_path or shutil.which("swiftc")
    if not exe:
        return None, None, []
    platforms_roots: list[Path] = []
    exe_path = Path(exe).resolve()
    for ancestor in exe_path.parents:
        candidate = ancestor / "Platforms"
        if candidate.is_dir() and candidate not in platforms_roots:
            platforms_roots.append(candidate)
    try:
        res = subprocess.run([exe, "-print-target-info"], capture_output=True, text=True, timeout=15)
        if res.returncode == 0:
            info = json.loads(res.stdout)
            ver = _parse_version_tuple(info.get("compilerVersion", ""))
            tag = info.get("swiftCompilerTag")
            return (".".join(map(str, ver)) if ver else None), tag, platforms_roots
    except (OSError, subprocess.SubprocessError, ValueError):
        pass
    try:
        res = subprocess.run([exe, "--version"], capture_output=True, text=True, timeout=15)
        if res.returncode == 0:
            ver = _parse_version_tuple(res.stdout)
            return (".".join(map(str, ver)) if ver else None), None, platforms_roots
    except (OSError, subprocess.SubprocessError):
        pass
    return None, None, platforms_roots


def discover_windows_sdk(
    env: dict[str, str] | None = None,
    swiftc_path: str | None = None,
    extra_platforms_roots: list[Path] | None = None,
    compiler_override: tuple[str | None, str | None] | None = None,
) -> Path | None:
    """Locate an existing compatible Windows SDK without personal paths or installs."""
    lookup_env = os.environ if env is None else env
    if compiler_override is not None:
        compiler_ver, compiler_tag = compiler_override
        roots: list[Path] = []
    else:
        compiler_ver, compiler_tag, roots = _swift_compiler_info(swiftc_path)
    compiler_tuple = _parse_version_tuple(compiler_ver or "")

    candidate_roots: list[Path] = list(extra_platforms_roots or []) + roots
    if extra_platforms_roots is None:
        for env_key, rel in (
            ("LOCALAPPDATA", Path("Programs") / "Swift" / "Platforms"),
            ("ProgramFiles", Path("Swift") / "Platforms"),
        ):
            base = lookup_env.get(env_key)
            if base:
                candidate_roots.append(Path(base) / rel)

    seen_roots: set[Path] = set()
    candidates: list[tuple[tuple[int, tuple[int, ...]], Path]] = []
    for platforms_dir in candidate_roots:
        if not platforms_dir.is_dir():
            continue
        resolved_root = platforms_dir.resolve()
        if resolved_root in seen_roots:
            continue
        seen_roots.add(resolved_root)
        for sdk in platforms_dir.glob("*/Windows.platform/Developer/SDKs/Windows.sdk"):
            if not sdk.is_dir() or not (sdk / "usr").is_dir():
                continue
            settings_path = sdk / "SDKSettings.json"
            settings = {}
            if settings_path.is_file():
                try:
                    settings = json.loads(settings_path.read_text(encoding="utf-8"))
                except (OSError, ValueError):
                    settings = {}
            sdk_ver_str = str(settings.get("Version") or sdk.parents[3].name)
            sdk_tuple = _parse_version_tuple(sdk_ver_str)
            toolchains = settings.get("Toolchains") or []
            if compiler_tag and compiler_tag in toolchains:
                rank = 4
            elif compiler_tuple and sdk_tuple == compiler_tuple:
                rank = 3
            elif compiler_tuple and len(sdk_tuple) >= 2 and sdk_tuple[:2] == compiler_tuple[:2]:
                rank = 2
            elif compiler_tuple and len(sdk_tuple) >= 1 and sdk_tuple[:1] == compiler_tuple[:1]:
                rank = 1
            elif not compiler_tuple:
                rank = 1
            else:
                continue
            candidates.append(((rank, sdk_tuple), sdk))

    if not candidates:
        return None
    candidates.sort(key=lambda item: item[0], reverse=True)
    return candidates[0][1]


def swift_env() -> dict[str, str]:
    env = os.environ.copy()
    if os.name == "nt" and not env.get("SDKROOT"):
        discovered = discover_windows_sdk(env=env)
        if discovered is not None:
            env["SDKROOT"] = str(discovered)
    return env


def extract_brace_block(text: str, marker: str) -> str:
    idx = text.index(marker)
    brace_start = text.index("{", idx)
    depth = 0
    for pos in range(brace_start, len(text)):
        ch = text[pos]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[brace_start + 1 : pos]
    raise AssertionError(f"Unbalanced braces after {marker!r}")


def _strip_swift_comment(line: str) -> str:
    in_string = False
    escaped = False
    for i, ch in enumerate(line):
        if escaped:
            escaped = False
            continue
        if ch == "\\" and in_string:
            escaped = True
            continue
        if ch == '"':
            in_string = not in_string
            continue
        if not in_string and ch == "/" and i + 1 < len(line) and line[i + 1] == "/":
            return line[:i]
    return line


def _parse_swift_cond(expr: str):
    """Parse minimal Swift #if boolean syntax into a conservative AST."""
    tokens: list[str] = []
    i = 0
    n = len(expr)
    while i < n:
        ch = expr[i]
        if ch.isspace():
            i += 1
        elif expr.startswith("&&", i) or expr.startswith("||", i):
            tokens.append(expr[i : i + 2])
            i += 2
        elif ch in "!()":
            tokens.append(ch)
            i += 1
        else:
            start = i
            paren_depth = 0
            while i < n:
                c = expr[i]
                if c == "(":
                    paren_depth += 1
                    i += 1
                elif c == ")" and paren_depth > 0:
                    paren_depth -= 1
                    i += 1
                elif paren_depth == 0 and (
                    c.isspace() or c in "!()" or expr.startswith("&&", i) or expr.startswith("||", i)
                ):
                    break
                else:
                    i += 1
            tokens.append(expr[start:i])

    pos = 0

    def parse_or():
        nonlocal pos
        node = parse_and()
        while pos < len(tokens) and tokens[pos] == "||":
            pos += 1
            node = ("or", node, parse_and())
        return node

    def parse_and():
        nonlocal pos
        node = parse_unary()
        while pos < len(tokens) and tokens[pos] == "&&":
            pos += 1
            node = ("and", node, parse_unary())
        return node

    def parse_unary():
        nonlocal pos
        if pos < len(tokens) and tokens[pos] == "!":
            pos += 1
            return ("not", parse_unary())
        if pos < len(tokens) and tokens[pos] == "(":
            pos += 1
            inner = parse_or()
            if pos >= len(tokens) or tokens[pos] != ")":
                return ("unknown",)
            pos += 1
            return inner
        if pos >= len(tokens):
            return ("unknown",)
        tok = tokens[pos]
        pos += 1
        if tok == "DEBUG":
            return ("debug",)
        if tok == "true":
            return ("lit", True)
        if tok == "false":
            return ("lit", False)
        return ("unknown",)

    if not tokens:
        return ("unknown",)
    ast = parse_or()
    if pos != len(tokens):
        return ("unknown",)
    return ast


def _eval_cond_3val(node, debug_val: bool):
    """Evaluate AST in 3-valued logic: True, False, or None (unknown)."""
    kind = node[0]
    if kind == "lit":
        return node[1]
    if kind == "debug":
        return debug_val
    if kind == "unknown":
        return None
    if kind == "not":
        val = _eval_cond_3val(node[1], debug_val)
        return None if val is None else (not val)
    if kind == "and":
        left = _eval_cond_3val(node[1], debug_val)
        if left is False:
            return False
        right = _eval_cond_3val(node[2], debug_val)
        if right is False:
            return False
        if left is True and right is True:
            return True
        return None
    if kind == "or":
        left = _eval_cond_3val(node[1], debug_val)
        if left is True:
            return True
        right = _eval_cond_3val(node[2], debug_val)
        if right is True:
            return True
        if left is False and right is False:
            return False
        return None
    return None


def _branch_proven_debug_only(node) -> tuple[bool, bool]:
    """Return (is_debug_only, is_possibly_active)."""
    in_release = _eval_cond_3val(node, False)
    in_debug = _eval_cond_3val(node, True)
    possibly_active = (in_release is not False) or (in_debug is not False)
    debug_only = (in_release is False) and (in_debug is not False)
    return debug_only, possibly_active


def line_in_debug_guard(lines: list[str], target_line_idx: int) -> bool:
    # Each stack frame holds: (current_branch_ast, prior_branches_false_ast, saw_else)
    stack: list[tuple[tuple, tuple, bool]] = []
    for idx, raw in enumerate(lines):
        if idx == target_line_idx:
            states = [_branch_proven_debug_only(branch_ast) for branch_ast, _, _ in stack]
            return all(active for _, active in states) and any(debug_only for debug_only, _ in states)
        stripped = _strip_swift_comment(raw).strip()
        if stripped.startswith("#if ") or stripped.startswith("#if("):
            cond = _parse_swift_cond(stripped[3:].strip())
            stack.append((cond, ("not", cond), False))
        elif stripped.startswith("#elseif ") or stripped.startswith("#elseif("):
            if stack:
                _, prior_false, saw_else = stack[-1]
                if saw_else:
                    stack[-1] = (("lit", False), ("lit", False), True)
                else:
                    cond = _parse_swift_cond(stripped[7:].strip())
                    branch_ast = ("and", prior_false, cond)
                    next_prior_false = ("and", prior_false, ("not", cond))
                    stack[-1] = (branch_ast, next_prior_false, False)
        elif stripped == "#else":
            if stack:
                _, prior_false, saw_else = stack[-1]
                if saw_else:
                    stack[-1] = (("lit", False), ("lit", False), True)
                else:
                    stack[-1] = (prior_false, ("lit", False), True)
        elif stripped.startswith("#endif"):
            if stack:
                stack.pop()
    return False


class O2BNativeUXContractsTests(unittest.TestCase):
    def test_history_heading_uses_dynamic_primary_foreground(self) -> None:
        header_src = HEADER_FILE.read_text(encoding="utf-8")
        self.assertIn(".foregroundStyle(.primary)", header_src)

        history_src = HISTORY_FILE.read_text(encoding="utf-8")
        header_block = extract_brace_block(history_src, "} header:")

        heading_match = re.search(
            r'Text\("חיפושים אחרונים"\)\s*\.foregroundStyle\(\.primary\)',
            header_block,
        )
        self.assertIsNotNone(
            heading_match,
            'History section heading Text("חיפושים אחרונים") must explicitly use .foregroundStyle(.primary)',
        )
        self.assertNotIn(".foregroundStyle(.secondary)", header_block)
        self.assertNotIn(".foregroundColor(", header_block)

        for required in (
            "List {",
            "Section {",
            ".listStyle(.plain)",
            ".listRowBackground(Color.appBackground)",
            ".background(Color.appBackground)",
            'Label(query, systemImage: "clock")',
            '.accessibilityIdentifier("global-search-history")',
            '.accessibilityIdentifier("global-search-history-clear")',
            '.accessibilityIdentifier("global-search-history-\\(query)")',
        ):
            self.assertIn(required, history_src)

    def test_sidebar_diagnostics_are_debug_gated_bounded_and_content_free(self) -> None:
        pager_src = PAGER_FILE.read_text(encoding="utf-8")
        lines = pager_src.splitlines()

        for marker in (
            '"attach ',
            '"shouldReceive ',
            '"shouldBegin ',
            '"requireFail ',
            '"panState ',
            '"swipeDecision ',
            '"pageChanged ',
            '"restore ',
        ):
            matched_lines = [i for i, line in enumerate(lines) if marker in line]
            self.assertTrue(matched_lines, f"Missing expected sidebar diagnostic marker: {marker!r}")
            for line_idx in matched_lines:
                self.assertTrue(
                    line_in_debug_guard(lines, line_idx),
                    f"Diagnostic marker {marker!r} at line {line_idx + 1} must be inside #if DEBUG",
                )

        # Unbounded .changed logging is forbidden.
        pan_handler = extract_brace_block(pager_src, "@objc private func bodyPanEnded(")
        self.assertIn("sender.state != .changed", pan_handler)

        # Ensure OtzariaFileLogger hook is present in ReaderSidebarPager and strictly #if DEBUG gated.
        logger_lines = [i for i, line in enumerate(lines) if "OtzariaFileLogger.shared.log(" in line]
        self.assertTrue(logger_lines, "ReaderSidebarPager must route debug breadcrumbs via OtzariaFileLogger")
        for line_idx in logger_lines:
            self.assertTrue(
                line_in_debug_guard(lines, line_idx),
                f"OtzariaFileLogger call at line {line_idx + 1} must be inside #if DEBUG",
            )
            self.assertIn("[ReaderSidebarPager]", lines[line_idx])

        # Content-free guard: diagnostic lines must not interpolate user query, book title, or URLs.
        forbidden_payload_tokens = (
            "searchQuery",
            "contentsQuery",
            "activeContentsBookTitle",
            ".book",
            "URL",
            "url",
            "accessibilityLabel",
        )
        diagnostic_lines = [
            (i, line) for i, line in enumerate(lines)
            if ("onDiagnostic?(" in line or "ReaderSidebarDebugLog.log(" in line)
        ]
        self.assertTrue(diagnostic_lines)
        for line_idx, line in diagnostic_lines:
            self.assertTrue(
                line_in_debug_guard(lines, line_idx),
                f"Diagnostic emit at line {line_idx + 1} must be inside #if DEBUG: {line}",
            )
            for token in forbidden_payload_tokens:
                self.assertNotIn(token, line, f"Diagnostic line must stay content-free (found {token!r}): {line}")

        # Preserve existing direction policy, arbitration direction, and native-only constraints.
        for invariant in (
            "abs(horizontal) >= 44, abs(horizontal) > abs(vertical) * 1.25",
            "isRTL ? horizontal > 0 : horizontal < 0",
            "abs(velocity.x) > abs(velocity.y) * 1.25",
            "shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer",
            "otherView === host || otherView.isDescendant(of: host)",
        ):
            self.assertIn(invariant, pager_src)
        self.assertNotIn("UIScreen.main", pager_src)

    def test_sidebar_sdk_slices_stay_self_contained_and_parse(self) -> None:
        pager_src = PAGER_FILE.read_text(encoding="utf-8")
        guard = "#if canImport(SwiftUI) && canImport(UIKit)"
        self.assertEqual(pager_src.count(guard), 1)

        policy = pager_src.split("#if canImport(SwiftUI)", 1)[0]
        adapter = pager_src[
            pager_src.index("private struct ReaderSidebarSplitConfiguration:") : pager_src.rindex("#endif")
        ]
        split_slice = policy + "\nimport SwiftUI\nimport UIKit\n" + adapter

        search_marker_begin = "// BEGIN SELF-CONTAINED SIDEBAR SEARCH ADAPTERS"
        search_marker_end = "// END SELF-CONTAINED SIDEBAR SEARCH ADAPTERS"
        search_slice = (
            "import SwiftUI\n"
            + pager_src.split(search_marker_begin, 1)[1].split(search_marker_end, 1)[0]
        )

        for slice_name, slice_text in (("ReaderSidebarSplit", split_slice), ("ReaderSidebarNativeSearch", search_slice)):
            for forbidden in ("OtzariaFileLogger", "iOSNavigationManager", "ReaderSidebarPageCoordinator"):
                self.assertNotIn(forbidden, slice_text, f"{slice_name} slice must not depend on {forbidden}")

        env = swift_env()
        with tempfile.TemporaryDirectory(prefix="o2b-parse-") as tmp_dir:
            tmp = Path(tmp_dir)
            pager_active = tmp / "ReaderSidebarPagerApple.swift"
            pager_active.write_text(pager_src.replace(guard, "#if true"), encoding="utf-8")
            split_path = tmp / "ReaderSidebarSplit.swift"
            split_path.write_text(split_slice, encoding="utf-8")
            search_path = tmp / "ReaderSidebarNativeSearchSDK.swift"
            search_path.write_text(search_slice, encoding="utf-8")

            targets = [HISTORY_FILE, PAGER_FILE, pager_active, split_path, search_path]
            for extra_flags in ([], ["-D", "DEBUG"]):
                cmd = ["swiftc", "-frontend", "-parse", "-swift-version", "6", *extra_flags, *map(str, targets)]
                res = subprocess.run(cmd, cwd=ROOT, env=env, capture_output=True, text=True, timeout=45)
                self.assertEqual(
                    res.returncode,
                    0,
                    f"swiftc -frontend -parse {' '.join(extra_flags)} failed:\n{res.stdout}\n{res.stderr}",
                )

    def test_existing_portable_sidebar_policy_passes(self) -> None:
        res = subprocess.run(
            [sys.executable, str(POLICY_RUNNER)],
            cwd=ROOT,
            env=swift_env(),
            capture_output=True,
            text=True,
            timeout=45,
        )
        self.assertEqual(
            res.returncode,
            0,
            f"Portable sidebar policy failed:\n{res.stdout}\n{res.stderr}",
        )
        self.assertIn("PASS:", res.stdout)

    def test_diagnostic_number_formatting_never_traps_and_preserves_rounding(self) -> None:
        pager_src = PAGER_FILE.read_text(encoding="utf-8")
        policy_src = pager_src.split("#if canImport(SwiftUI)", 1)[0]

        select_body = extract_brace_block(
            pager_src, "private func selectPage(horizontal: Double, vertical: Double)"
        )
        debug_match = re.search(r"#if\s+DEBUG\b(.*?)#endif", select_body, re.DOTALL)
        self.assertIsNotNone(debug_match, "selectPage must contain #if DEBUG diagnostic block")
        select_debug = debug_match.group(1)

        dx_match = re.search(r"^\s*let dx = .+$", select_debug, re.MULTILINE)
        dy_match = re.search(r"^\s*let dy = .+$", select_debug, re.MULTILINE)
        self.assertIsNotNone(dx_match, "selectPage #if DEBUG block must define dx")
        self.assertIsNotNone(dy_match, "selectPage #if DEBUG block must define dy")
        dx_stmt = dx_match.group(0).strip()
        dy_stmt = dy_match.group(0).strip()

        controller_body = extract_brace_block(
            pager_src, "private final class ReaderSidebarSplitConfigurationController:"
        )
        sig = "private static func debugRounded(_ value: CGFloat) -> String"
        debug_rounded_body = extract_brace_block(controller_body, sig)
        debug_rounded_fn = (
            "static func debugRounded(_ value: CGFloat) -> String {\n"
            + debug_rounded_body
            + "\n}"
        )

        swift_harness = f"""import Foundation

{policy_src}

typealias CGFloat = Double

enum ControllerDebugHarness {{
{debug_rounded_fn}
}}

func formatSelectPagePair(_ horizontal: Double, _ vertical: Double) -> (String, String) {{
    {dx_stmt}
    {dy_stmt}
    return (dx, dy)
}}

@main
struct O2BNumericDiagnosticRegressionHarness {{
    static func main() {{
        let mode = CommandLine.arguments.dropFirst().first ?? ""
        func verify(_ path: String, _ actual: String, _ expected: String, _ label: String) {{
            precondition(actual == expected, "\\(path) [\\(label)]: expected \\(expected), got \\(actual)")
        }}

        let cases: [(String, Double, String)] = [
            ("zero", 0.0, "0"),
            ("neg-zero", -0.0, "0"),
            ("pos-down", 0.4, "0"),
            ("neg-down", -0.4, "0"),
            ("pos-half", 0.5, "1"),
            ("neg-half", -0.5, "-1"),
            ("pos-1.5", 1.5, "2"),
            ("neg-1.5", -1.5, "-2"),
            ("pos-43.6", 43.6, "44"),
            ("neg-120.2", -120.2, "-120"),
            ("int-max-nextDown", Double(Int.max).nextDown, Int(exactly: Double(Int.max).nextDown.rounded()).map(String.init)!),
            ("double-int-max", Double(Int.max), String(describing: Double(Int.max))),
            ("double-int-min", Double(Int.min), String(Int.min)),
            ("double-int-min-nextDown", Double(Int.min).nextDown, String(describing: Double(Int.min).nextDown)),
            ("neg-out-of-range", -1e20, String(describing: -1e20)),
            ("pos-greatestFinite", Double.greatestFiniteMagnitude, String(describing: Double.greatestFiniteMagnitude)),
            ("neg-greatestFinite", -Double.greatestFiniteMagnitude, String(describing: -Double.greatestFiniteMagnitude)),
            ("nan", .nan, String(describing: Double.nan)),
            ("pos-inf", .infinity, String(describing: Double.infinity)),
            ("neg-inf", -.infinity, String(describing: -Double.infinity)),
        ]

        switch mode {{
        case "selectPage":
            for (label, value, expected) in cases {{
                let (dx, dy) = formatSelectPagePair(value, value)
                verify("selectPage.dx", dx, expected, label)
                verify("selectPage.dy", dy, expected, label)
            }}
            let (mixedX, mixedY) = formatSelectPagePair(43.6, Double.greatestFiniteMagnitude)
            verify("selectPage.dx", mixedX, "44", "mixed-x")
            verify("selectPage.dy", mixedY, String(describing: Double.greatestFiniteMagnitude), "mixed-y")
            let (mixedX2, mixedY2) = formatSelectPagePair(-Double.greatestFiniteMagnitude, -120.2)
            verify("selectPage.dx", mixedX2, String(describing: -Double.greatestFiniteMagnitude), "mixed-x2")
            verify("selectPage.dy", mixedY2, "-120", "mixed-y2")
            print("PASS: selectPage formatted \\(cases.count * 2 + 4) cases without trap")
        case "debugRounded":
            for (label, value, expected) in cases {{
                let actual = ControllerDebugHarness.debugRounded(CGFloat(value))
                verify("debugRounded", actual, expected, label)
            }}
            print("PASS: debugRounded formatted \\(cases.count) cases without trap")
        default:
            preconditionFailure("Unknown mode: \\(mode)")
        }}
    }}
}}
"""
        env = swift_env()
        with tempfile.TemporaryDirectory(prefix="o2b-numeric-") as tmp_dir:
            tmp = Path(tmp_dir)
            src = tmp / "O2BNumericDiagnosticRegressionHarness.swift"
            exe = tmp / ("o2b_numeric.exe" if os.name == "nt" else "o2b_numeric")
            src.write_text(swift_harness, encoding="utf-8")

            compile_res = subprocess.run(
                ["swiftc", "-parse-as-library", "-D", "DEBUG", str(src), "-o", str(exe)],
                cwd=ROOT,
                env=env,
                capture_output=True,
                text=True,
                timeout=45,
            )
            self.assertEqual(
                compile_res.returncode,
                0,
                f"Numeric regression harness failed to compile:\n{compile_res.stdout}\n{compile_res.stderr}",
            )

            for mode in ("selectPage", "debugRounded"):
                with self.subTest(path=mode):
                    run_res = subprocess.run(
                        [str(exe), mode],
                        cwd=ROOT,
                        env=env,
                        capture_output=True,
                        text=True,
                        timeout=30,
                    )
                    self.assertEqual(
                        run_res.returncode,
                        0,
                        f"{mode} formatting trapped or failed (rc={run_res.returncode}):\n"
                        f"STDOUT: {run_res.stdout}\nSTDERR: {run_res.stderr}",
                    )
                    self.assertIn("PASS:", run_res.stdout)

    def test_debug_guard_parser_is_conservative(self) -> None:
        positive = [
            ("plain_debug", ["#if DEBUG", "emit()", "#endif"], 1),
            ("ios_and_debug", ["#if os(iOS) && DEBUG", "emit()", "#endif"], 1),
            ("debug_and_ios", ["#if DEBUG && os(iOS)", "emit()", "#endif"], 1),
            ("negated_debug_else", ["#if !DEBUG", "prod()", "#else", "emit()", "#endif"], 3),
            ("elseif_debug", ["#if FEATURE_X", "feat()", "#elseif DEBUG", "emit()", "#endif"], 3),
            ("nested_uikit_then_debug", ["#if canImport(UIKit)", "#if DEBUG", "emit()", "#endif", "#endif"], 2),
            (
                "nested_debug_then_uikit_else",
                ["#if DEBUG", "#if canImport(UIKit)", "a()", "#else", "emit()", "#endif", "#endif"],
                4,
            ),
        ]
        for label, lines, idx in positive:
            with self.subTest(case=label):
                self.assertTrue(line_in_debug_guard(lines, idx), f"{label} must be treated as DEBUG-only")

        negative = [
            ("non_debug_else", ["#if canImport(UIKit)", "a()", "#else", "b()", "#endif"], 3),
            ("negated_debug_branch", ["#if !DEBUG", "prod()", "#endif"], 1),
            ("debug_else_branch", ["#if DEBUG", "dbg()", "#else", "prod()", "#endif"], 3),
            ("debug_or_feature", ["#if DEBUG || FEATURE_X", "both()", "#endif"], 1),
            ("feature_or_debug", ["#if FEATURE_X || DEBUG", "both()", "#endif"], 1),
            ("false_and_debug", ["#if false && DEBUG", "dead()", "#endif"], 1),
            ("debug_and_false", ["#if DEBUG && false", "dead()", "#endif"], 1),
            ("debug_and_not_debug", ["#if DEBUG && !DEBUG", "dead()", "#endif"], 1),
            ("ios_and_not_debug_else", ["#if os(iOS) && !DEBUG", "a()", "#else", "b()", "#endif"], 3),
            ("nested_debug_then_false", ["#if DEBUG", "#if false", "dead()", "#endif", "#endif"], 2),
            ("nested_uikit_ios_else", ["#if canImport(UIKit)", "#if os(iOS)", "a()", "#else", "b()", "#endif", "#endif"], 4),
        ]
        for label, lines, idx in negative:
            with self.subTest(case=label):
                self.assertFalse(line_in_debug_guard(lines, idx), f"{label} must NOT be treated as DEBUG-only")

    def test_swift_env_honors_sdkroot_and_has_no_personal_paths(self) -> None:
        self_src = Path(__file__).read_text(encoding="utf-8")
        self.assertIsNone(
            re.search(r"Users[/\\][A-Za-z0-9._-]+[/\\]AppData", self_src, re.IGNORECASE),
            "Test helper must not embed a personal Windows user path",
        )

        saved_sdkroot = os.environ.get("SDKROOT")
        try:
            os.environ["SDKROOT"] = r"C:\custom\Explicit.sdk"
            env = swift_env()
            self.assertEqual(env["SDKROOT"], r"C:\custom\Explicit.sdk")

            if os.name == "nt":
                os.environ.pop("SDKROOT", None)
                env = swift_env()
                self.assertTrue(env.get("SDKROOT"), "Portable Windows SDK discovery must resolve existing SDK")
                self.assertTrue(Path(env["SDKROOT"]).is_dir())
        finally:
            if saved_sdkroot is None:
                os.environ.pop("SDKROOT", None)
            else:
                os.environ["SDKROOT"] = saved_sdkroot

        with tempfile.TemporaryDirectory(prefix="o2b-sdk-discovery-") as tmp_dir:
            platforms = Path(tmp_dir) / "Platforms"
            for ver, tag in (("5.10.1", "swift-5.10.1-RELEASE"), ("6.3.3", "swift-6.3.3-RELEASE")):
                sdk = platforms / ver / "Windows.platform" / "Developer" / "SDKs" / "Windows.sdk"
                (sdk / "usr").mkdir(parents=True)
                (sdk / "SDKSettings.json").write_text(
                    json.dumps({"Version": ver, "Toolchains": [tag]}), encoding="utf-8"
                )
            matched = discover_windows_sdk(
                extra_platforms_roots=[platforms],
                compiler_override=("6.3.3", "swift-6.3.3-RELEASE"),
            )
            self.assertEqual(
                matched,
                platforms / "6.3.3" / "Windows.platform" / "Developer" / "SDKs" / "Windows.sdk",
            )
            incompatible = discover_windows_sdk(
                extra_platforms_roots=[platforms],
                compiler_override=("7.0.0", "swift-7.0.0-RELEASE"),
            )
            self.assertIsNone(incompatible, "Incompatible major SDK version must not be selected")


if __name__ == "__main__":
    unittest.main()
