"""Focused source/binary closure controls. Native commands are explicit doubles."""
import hashlib
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
LOADED = runpy.run_path(str(ROOT / 'Scripts/CI/hq-stage2-focused-apple.py'))
PLAN = LOADED['zayit_build_plan']
NAMESPACE = PLAN.__globals__
RUST = 'Vendor/ZayitSearchPort/Rust'
SCRIPT = 'Vendor/ZayitSearchPort/Scripts/build-ios-xcframework.sh'


class SourceClosureTests(unittest.TestCase):
    def plan(self, changes, rebuild=False, script_changed=False):
        def capture(*args):
            if args[1] == 'diff':
                return '\n'.join(changes) if args[-1] == RUST else ('changed' if script_changed else '')
            return 'immutable-source-identity'
        with patch.dict(NAMESPACE, capture=capture):
            return PLAN({'engine_producer_sha': 'baseline', 'rebuild_zayit_framework': rebuild})

    def test_prebuilt_allows_only_uncompiled_test_changes(self):
        result = self.plan([RUST + '/tests/fixture_index_search.rs'])
        self.assertEqual(result['mode'], 'UNCHANGED_PRODUCTION_PREBUILT')

    def test_changed_runtime_cannot_use_the_old_binary(self):
        with self.assertRaisesRegex(RuntimeError, 'matching rebuilt'):
            self.plan([RUST + '/src/magic_dictionary_index.rs'])

    def test_exact_reviewed_runtime_change_selects_rebuild(self):
        result = self.plan([RUST + '/src/magic_dictionary_index.rs', RUST + '/tests/fixture_index_search.rs'], True)
        self.assertEqual(result['mode'], 'REBUILD_EXACT_REVIEWED_RUST')
        self.assertEqual(result['build_script'], SCRIPT)

    def test_unreviewed_runtime_or_dependency_change_fails(self):
        for name in ['src/engine.rs', 'Cargo.lock', 'include/maktabah_zayit_search.h']:
            with self.subTest(name=name), self.assertRaisesRegex(RuntimeError, 'Unreviewed'):
                self.plan([RUST + '/src/magic_dictionary_index.rs', RUST + '/' + name], True)

    def test_rebuild_is_not_a_truthy_string_or_an_empty_overlay(self):
        with self.assertRaisesRegex(RuntimeError, 'boolean'):
            self.plan([], 'false')
        with self.assertRaisesRegex(RuntimeError, 'Unreviewed'):
            self.plan([], True)

    def test_build_script_change_is_not_implicitly_approved(self):
        with self.assertRaisesRegex(RuntimeError, 'script'):
            self.plan([RUST + '/src/magic_dictionary_index.rs'], True, True)

    def staged(self, folder):
        root = Path(folder)
        output = root/'build/hq-stage2'
        output.mkdir(parents=True)
        build = root/'Vendor/ZayitSearchPort/build'
        build.mkdir(parents=True)
        (build/'baseline.a').write_bytes(b'old verified baseline')
        lock = root/'Vendor/ZayitSearchPort/Rust/Cargo.lock'
        lock.parent.mkdir(parents=True)
        lock.write_bytes(b'locked dependencies')
        report = {'zayit_framework': {'mode':'REBUILD_EXACT_REVIEWED_RUST',
                  'source_tree':'immutable-source-identity', 'build_script':SCRIPT}}
        return root, output, build, report

    def test_failed_build_preserves_baseline_and_has_no_success(self):
        with tempfile.TemporaryDirectory(prefix='zayit-source-closure-') as folder:
            root, output, build, report = self.staged(folder)
            def fail(*_args, **_kwargs):
                raise RuntimeError('explicit native command failure')
            with patch.dict(NAMESPACE, ROOT=root, OUT=output, capture=lambda *_: 'immutable-source-identity', logged=fail):
                with self.assertRaisesRegex(RuntimeError, 'native command failure'):
                    LOADED['rebuild_matching_zayit_framework'](report)
            self.assertEqual((output/'zayit-prebuilt-baseline/baseline.a').read_bytes(), b'old verified baseline')
            self.assertFalse(build.exists())
            self.assertNotIn('status', report['zayit_framework'])

    def test_only_new_output_is_fingerprinted_and_later_tampering_fails(self):
        with tempfile.TemporaryDirectory(prefix='zayit-source-closure-') as folder:
            root, output, build, report = self.staged(folder)
            def simulate(command, *_args, **_kwargs):
                if command[0] == 'bash':
                    framework = build/'MaktabahZayitSearch.xcframework'
                    framework.mkdir(parents=True)
                    (framework/'Info.plist').write_bytes(b'fixture layout, not a native framework')
                    for name in ['device', 'simulator']:
                        path = framework/name/'libmaktabah_zayit_search.a'
                        path.parent.mkdir()
                        path.write_bytes(('new source ' + name).encode())
            with patch.dict(NAMESPACE, ROOT=root, OUT=output, capture=lambda *_: 'immutable-source-identity', logged=simulate):
                LOADED['rebuild_matching_zayit_framework'](report)
                plan = report['zayit_framework']
                self.assertEqual(plan['status'], 'BUILT_FROM_EXACT_REVIEWED_SOURCE_NOT_YET_APP_ACCEPTANCE')
                archive = root/plan['retained_archive']
                self.assertEqual(hashlib.sha256(archive.read_bytes()).hexdigest(), plan['retained_archive_sha256'])
                self.assertNotIn('baseline.a', ' '.join(plan['built_files_sha256']))
                LOADED['verify_selected_zayit_files'](report)
                library = build/'MaktabahZayitSearch.xcframework/device/libmaktabah_zayit_search.a'
                library.write_bytes(b'old binary substituted after build')
                with self.assertRaisesRegex(RuntimeError, 'before/after app link'):
                    LOADED['verify_selected_zayit_files'](report)
            self.assertEqual((output/'zayit-prebuilt-baseline/baseline.a').read_bytes(), b'old verified baseline')


if __name__ == '__main__':
    unittest.main(verbosity=2)
