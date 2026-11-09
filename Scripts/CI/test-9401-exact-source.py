#!/usr/bin/env python3
"""Adversarial source tests; no simulator and no mutation of application files."""
import importlib.util
import copy
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("source_gate", Path(__file__).with_name("verify-9401-exact-source.py"))
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class NegativeControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = gate.swift_snapshot(gate.BASE)
        cls.files = gate.swift_snapshot("HEAD")
        cls.manifest = gate.make_manifest("HEAD")

    def changed(self, path, before, after):
        files = dict(self.files)
        self.assertIn(before, files[path])
        files[path] = files[path].replace(before, after, 1)
        return gate.source_issues(files, self.original)

    def test_removed_original_toolbar_button(self):
        self.assertIn("ORIGINAL_TOOLBAR_CHANGED", self.changed(gate.READER,
                      b'Label(.Library.bookInfo, systemImage: "info.circle")', b'Text("removed")'))

    def test_enabled_duckduckgo_tabs(self):
        issues = self.changed(gate.IPAD, b"iOSReaderTabView(", b"DocumentTabsHost(\n iOSReaderTabView(")
        self.assertIn("FORBIDDEN_ACTIVE_UI:DocumentTabsHost(", issues)

    def test_changed_original_toc_blob(self):
        files = dict(self.files)
        files[gate.TOC] += b"\n// deliberate negative control\n"
        self.assertIn("EXACT_BLOB_REQUIRED:" + gate.TOC, gate.source_issues(files, self.original))

    def test_added_duplicate_title_bar(self):
        issues = self.changed(gate.IPAD, b"private var viewerTabContent: some View {",
                              b"private var viewerTabContent: some View {\n ToolbarItem(placement: .principal) {}")
        self.assertIn("DUPLICATE_TITLE_BAR", issues)

    def test_missing_feature_coordinator(self):
        issues = self.changed(gate.COMPACT, b".modifier(Exact9401WorkspaceLifecycle(manager: manager))", b"")
        self.assertIn("FEATURE_COORDINATOR_MISSING", issues)

    def test_changed_global_tab(self):
        self.assertIn("ORIGINAL_GLOBAL_TABS_CHANGED", self.changed(gate.IPAD, b"historyTabContent\n", b"Text(\"missing\")\n"))

    def test_second_reader_instance(self):
        self.assertIn("SINGLE_READER_TWO_COLUMN_REQUIRED", self.changed(gate.IPAD,
                      b"iOSReaderTabView(", b"iOSReaderTabView()\n iOSReaderTabView("))

    def test_replacement_palette(self):
        self.assertIn("CURRENT_PALETTE_MUST_BE_REUSED", self.changed(gate.SIDEBAR,
                      b"LibraryCommandPaletteAdapter(manager: manager)", b"ReplacementPalette(manager: manager)"))

    def test_changed_original_inspector_toggle(self):
        self.assertIn("UNAPPROVED_WORKSPACE_BLOCK:readerSurface", self.changed(gate.WORKSPACE,
                      b"Button(action: toggleStudyPanel)", b"Button(action: {})"))

    def test_removed_profile_toolbar(self):
        self.assertIn("NATIVE_PROFILE_TOOLBAR_REQUIRED", self.changed(gate.SIDEBAR,
                      b"usesNativeToolbar: true", b"usesNativeToolbar: false"))

    def test_changed_profile_switch_action(self):
        self.assertIn("PROFILE_ACTIONS_CHANGED", self.changed(gate.PROFILE_MENU,
                      b"workspace.switchGroup(to: group.id", b"workspace.switchGroup(to: UUID()"))

    def test_no_false_positive_for_originals_and_required_connections(self):
        issues = gate.source_issues(self.files, self.original)
        self.assertEqual(issues, [], "Owner-approved actual source must satisfy all static route invariants.")

    def test_missing_exact_hunk_approval(self):
        record = json.loads(gate.content("HEAD", gate.APPROVAL))
        record["authorization_reference"] = None
        self.assertIn("EXACT_READER_APPROVAL_INVALID", gate.approval_issues(record, gate.content("HEAD", gate.APPROVED_PATCH)))

    def test_changed_approved_hunk_artifact(self):
        record = json.loads(gate.content("HEAD", gate.APPROVAL))
        self.assertIn("EXACT_READER_APPROVAL_INVALID", gate.approval_issues(record, gate.content("HEAD", gate.APPROVED_PATCH) + b"modified"))

    def mutated_manifest(self, path, **updates):
        manifest = copy.deepcopy(self.manifest)
        entry = next(e for e in manifest["files"] if e["path"] == path)
        entry.update(updates)
        return gate.verify(manifest, "HEAD")

    def test_false_exact_claim(self):
        path = "Source/Features/Search/iOS/SearchComponents.swift"
        self.assertIn("FALSE_EXACT_CLAIM:" + path, self.mutated_manifest(path, status="EXACT_9401_BLOB"))

    def test_forged_original_blob(self):
        self.assertIn("FORGED_PROVENANCE:" + gate.TOC,
                      self.mutated_manifest(gate.TOC, baseline_blob="0" * 40))

    def test_backend_retention_drift(self):
        path = "Source/LibraryBackend/BackendCoordinator.swift"
        self.assertIn("FEATURE_RETENTION_FAILED:" + path,
                      self.mutated_manifest(path, final_blob="0" * 40))

    def test_original_file_omission(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["files"] = [e for e in manifest["files"] if e["path"] != gate.TOC]
        self.assertIn("MISSING_ORIGINAL_INVENTORY:" + gate.TOC, gate.verify(manifest, "HEAD"))

    def test_missing_exception_authorization(self):
        self.assertIn("OWNER_HUNK_REVIEW_REQUIRED:" + gate.IPAD,
                      self.mutated_manifest(gate.IPAD, approval_state="SELF_APPROVED"))

    def test_visual_classification_bypass(self):
        self.assertIn("VISUAL_CLASSIFICATION_BYPASS:" + gate.TOC,
                      self.mutated_manifest(gate.TOC, status="BACKEND_RETAINED"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
