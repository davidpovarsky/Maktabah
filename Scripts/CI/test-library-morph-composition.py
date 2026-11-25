#!/usr/bin/env python3
"""Focused morph source mutations. These are not native runtime acceptance."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("gate", Path(__file__).with_name("verify-9401-exact-source.py"))
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class LibraryMorphCompositionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files = {path: gate.content("HEAD", path) for path in gate.MORPH_PRODUCT_PATHS}

    def changed(self, path, old, new):
        files = dict(self.files)
        self.assertIn(old, files[path])
        files[path] = files[path].replace(old, new, 1)
        return gate.library_morph_issues(files)

    def test_actual_source_preserves_original_semantics(self):
        self.assertEqual(gate.library_morph_issues(self.files), [])

    def test_missing_native_launcher_rejected(self):
        self.assertIn("ONE_PALETTE_LAUNCHER_REQUIRED", self.changed(gate.SIDEBAR,
            b'reader-command-palette-launcher', b'missing-launcher'))

    def test_duplicate_split_shell_rejected(self):
        self.assertIn("ONE_SPLIT_LEVEL_MORPH_REQUIRED", self.changed(gate.IPAD,
            gate.MORPH_SPLIT_HOOK.encode(), (gate.MORPH_SPLIT_HOOK * 2).encode()))

    def test_shell_moved_inside_detail_rejected(self):
        files = dict(self.files)
        files[gate.IPAD] = files[gate.IPAD].replace(gate.MORPH_SPLIT_HOOK.encode(), b"")
        marker = b"                .modifier(Exact9401ViewerToolbar(manager: bManager))"
        self.assertIn(marker, files[gate.IPAD])
        files[gate.IPAD] = files[gate.IPAD].replace(marker, marker + b"\n" + gate.MORPH_SPLIT_HOOK.encode(), 1)
        self.assertIn("ONE_SPLIT_LEVEL_MORPH_REQUIRED", gate.library_morph_issues(files))

    def test_replacement_palette_rejected(self):
        self.assertIn("CURRENT_PALETTE_MUST_BE_REUSED", self.changed(gate.PALETTE,
            b"LibraryCommandPaletteAdapter(manager: manager, isActive:", b"ReplacementPalette(manager: manager, isActive:"))

    def test_parallel_query_binding_rejected(self):
        self.assertIn("CURRENT_PALETTE_MUST_BE_REUSED", self.changed(gate.PALETTE,
            b"queryBinding: Bindable(manager.libraryViewModel).searchQuery", b"queryBinding: .constant(\"\")"))

    def test_replaced_book_action_rejected(self):
        self.assertIn("CURRENT_PALETTE_MUST_BE_REUSED", self.changed(gate.PALETTE,
            b"manager.openBook(book)", b"print(book)"))

    def test_changed_original_selection_rejected(self):
        self.assertIn("ORIGINAL_PALETTE_SELECTION_CHANGED:runSelection", self.changed(gate.PALETTE_COMPONENT,
            b"guard let item = selection.selectedItem else { return }", b"guard let item = selection.rows.last?.item else { return }"))

    def test_changed_original_escape_rejected(self):
        self.assertIn("ORIGINAL_PALETTE_KEYBOARD_CHANGED", self.changed(gate.PALETTE_COMPONENT,
            b"onEscape?()", b"onUp?()"))

    def test_conditional_shell_children_rejected(self):
        self.assertIn("SINGLE_STABLE_MORPH_SURFACE_REQUIRED", self.changed(gate.PALETTE,
            b"return ZStack(alignment: .topLeading) {", b"return ZStack(alignment: .topLeading) {\n            if isExpanded {}"))

    def test_added_shadow_rejected(self):
        self.assertIn("SINGLE_STABLE_MORPH_SURFACE_REQUIRED", self.changed(gate.PALETTE,
            b".modifier(SafariGlass(radius: radius))", b".modifier(SafariGlass(radius: radius)).shadow(radius: 20)"))

    def test_drag_across_field_results_rejected(self):
        self.assertIn("SINGLE_STABLE_MORPH_SURFACE_REQUIRED", self.changed(gate.PALETTE,
            b".modifier(SafariGlass(radius: radius))", b".modifier(SafariGlass(radius: radius)).gelatinMotionOnly()"))

    def test_hidden_field_focus_rejected(self):
        self.assertIn("RETAINED_PALETTE_FOCUS_LIFECYCLE_REQUIRED", self.changed(gate.PALETTE_COMPONENT,
            b"wantsFocus: isActive && isSearchFieldFocused", b"wantsFocus: isSearchFieldFocused"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
