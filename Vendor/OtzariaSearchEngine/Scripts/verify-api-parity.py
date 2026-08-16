#!/usr/bin/env python3
"""Fail when the public C header, Swift declarations and Rust exports drift."""

from __future__ import annotations

import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
PATTERN = re.compile(r"otzaria_search_engine_[a-z0-9_]+")


def symbols(path: pathlib.Path) -> set[str]:
    return set(PATTERN.findall(path.read_text(encoding="utf-8")))


header = symbols(ROOT / "include" / "otzaria_search_engine.h")
swift = symbols(ROOT.parents[1] / "Source" / "Otzaria" / "Search" / "OtzariaSearchEngineBridge.swift")
rust = symbols(ROOT / "ios_bridge" / "src" / "lib.rs")

if header != swift:
    raise SystemExit(f"C/Swift API drift: header-only={sorted(header-swift)} swift-only={sorted(swift-header)}")
missing_rust = header - rust
if missing_rust:
    raise SystemExit(f"Rust is missing public C exports: {sorted(missing_rust)}")
print(f"API parity passed: {len(header)} C symbols match Swift and Rust")
