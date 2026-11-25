#!/usr/bin/env python3
"""Focused regressions for real host/SDK Clang module-map coexistence."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from original_editor_host_clang_context import SHARED_PACKAGES, project_host_context


class HostClangContextTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.export = self.root / "build/sdk/distribution"
        self.context = {"module_maps": [], "header_search_paths": [],
                        "producer_identity": {"source_sha": "a" * 40}}
        for number, (relative, _) in enumerate(SHARED_PACKAGES.items()):
            self.add_module(relative, f"Shared{number}")
            host = self.root / "build/SourcePackages/checkouts" / Path(relative).relative_to("Clang/Packages")
            host.parent.mkdir(parents=True, exist_ok=True)
            for source in (self.export / relative).parent.iterdir():
                shutil.copyfile(source, host.parent / source.name)
        for index in range(15):
            self.add_module(f"Clang/Packages/private{index}/include/module.modulemap", f"Private{index}")

    def tearDown(self):
        self.tmp.cleanup()

    def add_module(self, relative, name):
        module = self.export / relative
        module.parent.mkdir(parents=True, exist_ok=True)
        module.write_text(f'module {name} {{ header "types.h" export * }}\n')
        (module.parent / "types.h").write_text(f"typedef struct {{ int value; }} {name}Value;\n")
        self.context["module_maps"].append(relative)
        self.context["header_search_paths"].append(str(Path(relative).parent))

    def compose(self):
        return project_host_context(self.root, self.export, self.context,
                                    set(SHARED_PACKAGES.values()))

    def test_four_exact_shared_modules_use_host_paths_without_modifying_sdk(self):
        before = {p: p.read_bytes() for p in self.export.rglob("*") if p.is_file()}
        value = self.compose()
        self.assertEqual(value["status"], "HOST_CLANG_CONTEXT_COMPOSED")
        self.assertEqual(len(value["module_maps"]), 19)
        self.assertEqual(len(value["reused_identical_host_modules"]), 4)
        self.assertTrue(all(p.startswith("build/SourcePackages/checkouts/")
                            for p in value["module_maps"][:4]))
        self.assertEqual({p: p.read_bytes() for p in before}, before)
        self.assertFalse(value["native_build_or_runtime_qualified"])

    def test_same_module_name_with_different_header_is_rejected(self):
        host = self.root / "build/SourcePackages/checkouts/swift-cmark/src/include/types.h"
        host.write_text("typedef struct { long changedABI; } Shared0Value;\n")
        with self.assertRaisesRegex(RuntimeError, "declaration bytes differ"):
            self.compose()

    def test_matching_bytes_do_not_override_different_source_revision(self):
        with self.assertRaisesRegex(RuntimeError, "package revisions differ"):
            project_host_context(self.root, self.export, self.context, set())

    def test_separate_cocoapods_module_is_reported_not_silently_dropped(self):
        pod = self.root / "Pods/Headers/Public/Private0/Private0.modulemap"
        pod.parent.mkdir(parents=True)
        pod.write_text('module Private0 { header "different.h" export * }\n')
        result = self.compose()
        self.assertEqual(result["status"], "HOST_RUNTIME_COLLISIONS")
        self.assertEqual([c["module"] for c in result["runtime_collisions"]], ["Private0"])
        self.assertEqual(len(result["module_maps"]), 19)
        self.assertIn("build/sdk/distribution/Clang/Packages/private0/include/module.modulemap",
                      result["module_maps"])

    def test_host_symlink_cannot_escape_checkout(self):
        host = self.root / "build/SourcePackages/checkouts/swift-cmark/src/include/types.h"
        host.unlink()
        host.symlink_to("/etc/hosts")
        with self.assertRaisesRegex(RuntimeError, "escaping"):
            self.compose()

    def test_exact_modulemap_is_required(self):
        host = self.root / "build/SourcePackages/checkouts/swift-cmark/src/include/module.modulemap"
        host.write_text('module Different { header "types.h" export * }\n')
        with self.assertRaisesRegex(RuntimeError, "module-map bytes differ"):
            self.compose()

    def test_real_clang_rejects_duplicate_maps_then_accepts_canonical_map(self):
        clang = shutil.which("clang")
        self.assertIsNotNone(clang, "A real Clang compiler is required for this regression")
        sdk = self.export / self.context["module_maps"][0]
        host = self.root / "build/SourcePackages/checkouts/swift-cmark/src/include/module.modulemap"
        source = self.root / "consumer.m"
        source.write_text("@import Shared0;\nShared0Value value;\n")
        base = [clang, "-fsyntax-only", "-fmodules", "-fimplicit-module-maps",
                "-fmodules-cache-path=" + str(self.root / "cache")]
        bad = subprocess.run(base + ["-fmodule-map-file=" + str(sdk),
                                     "-fmodule-map-file=" + str(host), str(source)],
                             text=True, capture_output=True)
        self.assertNotEqual(bad.returncode, 0)
        self.assertIn("redefinition of module", bad.stderr.lower())
        context = self.compose()
        canonical = self.root / context["module_maps"][0]
        good = subprocess.run(base + ["-fmodule-map-file=" + str(canonical),
                                      "-fmodule-map-file=" + str(host), str(source)],
                              text=True, capture_output=True)
        self.assertEqual(good.returncode, 0, good.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
