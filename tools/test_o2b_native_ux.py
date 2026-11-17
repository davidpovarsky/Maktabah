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

import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HISTORY_FILE = ROOT / "Source/ChavrusaText/Search/UI/GlobalSearchHistoryContent.swift"
HEADER_FILE = ROOT / "Source/ChavrusaText/Search/UI/GlobalSearchHeader.swift"
PAGER_FILE = ROOT / "Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift"
POLICY_RUNNER = ROOT / "Scripts/CI/test-native-sidebar-policy.py"

WINDOWS_SDK_CANDIDATE = Path(
    r"C:\Users\DAVID\AppData\Local\Programs\Swift\Platforms\6.3.3\Windows.platform\Developer\SDKs\Windows.sdk"
)


def swift_env() -> dict[str, str]:
    env = os.environ.copy()
    if os.name == "nt" and not env.get("SDKROOT") and WINDOWS_SDK_CANDIDATE.is_dir():
        env["SDKROOT"] = str(WINDOWS_SDK_CANDIDATE)
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


def line_in_debug_guard(lines: list[str], target_line_idx: int) -> bool:
    stack: list[tuple[str, bool]] = []
    for idx, raw in enumerate(lines):
        stripped = raw.strip()
        if idx == target_line_idx:
            return any(is_debug for _, is_debug in stack)
        if stripped.startswith("#if "):
            cond = stripped[4:].strip()
            stack.append((cond, "DEBUG" in cond and "!" not in cond))
        elif stripped.startswith("#elseif "):
            if stack:
                cond = stripped[8:].strip()
                stack[-1] = (cond, "DEBUG" in cond and "!" not in cond)
        elif stripped == "#else":
            if stack:
                cond, was_debug = stack[-1]
                stack[-1] = (f"!({cond})", not was_debug)
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


if __name__ == "__main__":
    unittest.main()
