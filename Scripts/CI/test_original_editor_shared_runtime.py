"""Portable admission controls. Fixtures grant no native or Stage B credit."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import original_editor_shared_runtime as shared


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value)


def lock(pins):
    return json.dumps({'pins': [{'identity': k, 'state': {'revision': v}}
                              for k, v in sorted(pins.items())]})


class CompleteHostSourceControls(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.revision, self.core = '1' * 40, '2' * 40
        self.pins = {'swift-ai-sdk': self.core, 'swift-syntax': '3' * 40}
        self.files = {}
        for base in shared.HANLIN_ROOTS:
            for tail, text in [('Package.swift', '// package fixture\n'),
                               ('Sources/Core/Core.swift', '// source fixture\n'),
                               ('Sources/Core/Resources/data.json', '{"fixture":true}\n')]:
                name = base + tail
                save(self.root / 'Vendor/HanlinSDK' / name, text)
                self.files[name] = shared.digest(self.root / 'Vendor/HanlinSDK' / name)
        self.hanlin_lock = shared.HANLIN_ROOTS[0] + 'Package.resolved'
        save(self.root / 'Vendor/HanlinSDK' / self.hanlin_lock, lock(self.pins))
        self.files[self.hanlin_lock] = shared.digest(self.root / 'Vendor/HanlinSDK' / self.hanlin_lock)
        self.project_lock = self.root / 'Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
        self.workspace_lock = self.root / 'Maktabah.xcworkspace/xcshareddata/swiftpm/Package.resolved'
        for path in [self.project_lock, self.workspace_lock]:
            save(path, lock(self.pins))
        raw = 'PODS:\n' + ''.join('  - ' + name + ' (' + version + ')\n'
                                for name, (_, version) in shared.PODS.items()) + '\nDEPENDENCIES:\n'
        save(self.root / 'Podfile.lock', raw)
        save(self.root / 'Pods/Manifest.lock', raw)
        dependencies = {identity: {'revision': '4' * 40, 'files': {'fixture.m': {'sha256': '5' * 64}}}
                        for identity, _ in shared.PODS.values()}
        self.owner = {'hanlin_package_files': copy.deepcopy(self.files),
                      'shared_dependency_sources': dependencies,
                      'root_dependency_revisions': {k: {'revision': v['revision']} for k, v in dependencies.items()}}
        self.admitted = {'shared_runtime': {'ownership': self.owner,
                                          'hanlin_revision': self.revision, 'swift_ai_revision': self.core}}
        self.report = {'package_pins': self.pins, 'hanlin_sdk_source': {
            'sha': self.revision, 'git_blobs': {name: '6' * 40 for name in self.files}}}

    def verify(self):
        return shared.verify_host_sources(self.root, self.admitted, self.report)

    def test_complete_fixture_includes_resources_and_locks_but_has_no_native_credit(self):
        result = self.verify()
        self.assertEqual(result['hanlin_files'], 10)
        self.assertFalse(result['native_stageb_qualified'])
        self.assertEqual(len(result['operative_lock_sha256']), 3)

    def test_same_revision_with_changed_resource_is_rejected(self):
        name = next(n for n in self.files if n.endswith('data.json'))
        save(self.root / 'Vendor/HanlinSDK' / name, '{"fixture":false}\n')
        with self.assertRaisesRegex(RuntimeError, 'different Hanlin package bytes'):
            self.verify()

    def test_extra_host_package_member_is_rejected(self):
        self.report['hanlin_sdk_source']['git_blobs'][shared.HANLIN_ROOTS[0] + 'Sources/New.swift'] = '7' * 40
        with self.assertRaisesRegex(RuntimeError, 'memberships differ'):
            self.verify()

    def test_older_producer_missing_a_resource_is_rejected(self):
        self.owner['hanlin_package_files'].pop(next(n for n in self.files if n.endswith('data.json')))
        with self.assertRaisesRegex(RuntimeError, 'memberships differ'):
            self.verify()

    def test_stale_generated_workspace_core_pin_is_rejected(self):
        save(self.workspace_lock, lock({**self.pins, 'swift-ai-sdk': '8' * 40}))
        with self.assertRaisesRegex(RuntimeError, 'operative Host'):
            self.verify()

    def test_package_lock_core_drift_is_rejected_even_with_matching_file_hash(self):
        path = self.root / 'Vendor/HanlinSDK' / self.hanlin_lock
        save(path, lock({**self.pins, 'swift-ai-sdk': '8' * 40}))
        self.owner['hanlin_package_files'][self.hanlin_lock] = shared.digest(path)
        with self.assertRaisesRegex(RuntimeError, 'operative Hanlin'):
            self.verify()

    def test_installed_pod_lock_drift_is_rejected(self):
        save(self.root / 'Pods/Manifest.lock', (self.root / 'Podfile.lock').read_text() + '# drift\n')
        with self.assertRaisesRegex(RuntimeError, 'Installed CocoaPods resolution differs'):
            self.verify()

    def test_consistent_but_older_pod_version_is_rejected(self):
        raw = (self.root / 'Podfile.lock').read_text().replace('FirebaseCore (12.8.0)', 'FirebaseCore (11.8.1)')
        for path in [self.root / 'Podfile.lock', self.root / 'Pods/Manifest.lock']:
            save(path, raw)
        with self.assertRaisesRegex(RuntimeError, 'provider versions differ'):
            self.verify()

    def test_provider_source_revision_drift_is_rejected(self):
        self.owner['shared_dependency_sources']['promises']['revision'] = '9' * 40
        with self.assertRaisesRegex(RuntimeError, 'dependency provenance differs'):
            self.verify()


class ExactPodLinkControls(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.path = self.root / shared.POD_XCCONFIG
        self.raw = 'OTHER_LDFLAGS = $(inherited) -ObjC -l"FirebaseCoreExtra"' + ''.join(
            ' -l"' + pod + '"' for pod in shared.PODS) + ' -framework "UIKit"\nUNCHANGED = YES\n'
        save(self.path, self.raw)

    def plan(self):
        return shared.plan_pod_link_route(self.root, {'pod_source_contracts': {p: {} for p in shared.PODS}})

    def test_exact_eight_inputs_are_projected_with_other_tokens_and_inverse_preserved(self):
        result = self.plan()
        self.assertEqual(result['shared_pod_libraries'], list(shared.PODS))
        self.assertIn('-l"FirebaseCoreExtra"', result['after_line'])
        self.assertIn('-framework "UIKit"', result['after_line'])
        self.assertEqual(self.path.read_text(), self.raw)
        after = self.raw.replace(result['before_line'], result['after_line'])
        self.assertEqual(after.replace(result['after_line'], result['before_line']), self.raw)
        self.assertEqual(hashlib.sha256(after.encode()).hexdigest(), result['after_sha256'])

    def test_missing_shared_library_input_is_rejected(self):
        save(self.path, self.raw.replace(' -l"PromisesSwift"', ''))
        with self.assertRaisesRegex(RuntimeError, 'Missing or repeated'):
            self.plan()

    def test_repeated_shared_library_input_is_rejected(self):
        save(self.path, self.raw.replace(' -l"nanopb"', ' -l"nanopb" -l"nanopb"'))
        with self.assertRaisesRegex(RuntimeError, 'Missing or repeated'):
            self.plan()


class ExactClangDeclarationControls(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.distribution = self.root / 'build/distribution'
        self.context = {'producer_identity': {'fixture': True}, 'module_maps': [], 'header_search_paths': []}
        self.host_headers = {}
        for name, (pod, suffix) in shared.CLANG_PODS.items():
            header = name + 'API.h'
            declaration = '// exact declaration fixture for ' + name + '\n'
            header_root = 'Clang/Packages/' + suffix
            module_map = 'Clang/Maps/' + name + '.modulemap'
            save(self.distribution / header_root / header, declaration)
            save(self.distribution / module_map, 'module ' + name + ' { header "' + header + '" export * }\n')
            public = self.root / 'Pods/Headers/Public' / pod
            save(public / (name + '.modulemap'), 'module ' + name + ' { header "' + header + '" export * }\n')
            save(public / header, declaration)
            self.host_headers[name] = public / header
            self.context['module_maps'].append(module_map)
            self.context['header_search_paths'].append(header_root)
        save(self.distribution / 'Clang/Maps/Unshared.modulemap', 'module Unshared { header "Unshared.h" }\n')
        save(self.distribution / 'Clang/Packages/unshared/Unshared.h', '// unshared declaration\n')
        self.context['module_maps'].append('Clang/Maps/Unshared.modulemap')
        self.context['header_search_paths'].append('Clang/Packages/unshared')

    def project(self):
        return shared.project_clang_context(self.root, self.distribution, self.context)

    def test_complete_matching_declarations_preserve_full_export_and_no_native_credit(self):
        before = {p.relative_to(self.distribution).as_posix(): shared.digest(p)
                  for p in self.distribution.rglob('*') if p.is_file()}
        result = self.project()
        self.assertEqual(len(result['module_maps']), 6)
        self.assertEqual(len(result['header_search_paths']), 6)
        self.assertEqual({r['module'] for r in result['reused_identical_host_modules']}, set(shared.CLANG_PODS))
        self.assertFalse(result['original_export_modified'])
        self.assertFalse(result['native_build_or_runtime_qualified'])
        self.assertEqual(before, {p.relative_to(self.distribution).as_posix(): shared.digest(p)
                                  for p in self.distribution.rglob('*') if p.is_file()})

    def add_original_layouts(self):
        promises = self.distribution / 'Clang/Packages' / shared.CLANG_PODS['FBLPromises'][1]
        self.private = self.root / 'Pods/PromisesObjC/Sources/FBLPromises/include/FBLPromisePrivate.h'
        save(self.private, '// original private declaration\n')
        private_link = self.root / 'Pods/Headers/Private/PromisesObjC/FBLPromisePrivate.h'
        private_link.parent.mkdir(parents=True)
        private_link.symlink_to(self.private)
        save(promises / 'FBLPromisePrivate.h', self.private.read_text())
        self.promises_map = self.distribution / 'Clang/Maps/FBLPromises.modulemap'
        self.promises_map.write_text(self.promises_map.read_text().replace(
            ' export * }', '\n    exclude header "FBLPromisePrivate.h"\n export * }'))
        self.nanopb = self.distribution / 'Clang/Packages' / shared.CLANG_PODS['nanopb'][1]
        for name in ['pb.h', 'pb_common.h', 'pb_decode.h', 'pb_encode.h']:
            declaration = '// original ' + name + '\n'
            save(self.nanopb / name, '#include "nanopb/' + name + '"\n')
            save(self.nanopb / 'nanopb' / name, declaration)
            save(self.root / 'Pods/Headers/Public/nanopb' / name, declaration)

    def test_original_private_and_forwarding_layouts_preserve_all_bytes_and_public_roots(self):
        self.add_original_layouts()
        before = {p.relative_to(self.distribution).as_posix(): shared.digest(p)
                  for p in self.distribution.rglob('*') if p.is_file()}
        result = self.project()
        reused = {r['module']: r for r in result['reused_identical_host_modules']}
        private = reused['FBLPromises']['declarations']['FBLPromisePrivate.h']
        self.assertEqual(private['kind'], 'excluded_private')
        self.assertFalse(private['exported_to_host'])
        forwarded = [v for v in reused['nanopb']['declarations'].values()
                     if v.get('kind') == 'transparent_forwarder']
        self.assertEqual(len(forwarded), 4)
        self.assertTrue(all(v['target_sha256'] != v['sha256'] for v in forwarded))
        self.assertFalse(any('/Private/' in p for p in result['header_search_paths']))
        self.assertEqual(before, {p.relative_to(self.distribution).as_posix(): shared.digest(p)
                                  for p in self.distribution.rglob('*') if p.is_file()})

    def test_unexcluded_private_header_is_rejected(self):
        self.add_original_layouts()
        self.promises_map.write_text(self.promises_map.read_text().replace('exclude header', 'header'))
        with self.assertRaisesRegex(RuntimeError, 'not uniquely excluded'):
            self.project()

    def test_changed_private_header_is_rejected(self):
        self.add_original_layouts()
        self.private.write_text('// different private declaration\n')
        with self.assertRaisesRegex(RuntimeError, 'private declaration differs'):
            self.project()

    def test_private_header_alias_outside_the_original_pod_is_rejected(self):
        self.add_original_layouts()
        outside = self.root / 'Pods/AnotherPod/FBLPromisePrivate.h'
        save(outside, self.private.read_text())
        self.private.unlink()
        self.private.symlink_to(outside)
        with self.assertRaisesRegex(RuntimeError, 'escaping'):
            self.project()

    def test_forwarding_header_with_extra_code_or_another_target_is_rejected(self):
        self.add_original_layouts()
        for value in ['#include "nanopb/pb.h"\n#define EXTRA 1\n',
                      '#include "../nanopb/pb.h"\n', '#include "nanopb/pb_common.h"\n']:
            with self.subTest(value=value):
                (self.nanopb / 'pb.h').write_text(value)
                with self.assertRaisesRegex(RuntimeError, 'Unreviewed nanopb'):
                    self.project()

    def test_changed_forwarding_target_is_rejected(self):
        self.add_original_layouts()
        (self.nanopb / 'nanopb/pb.h').write_text('// changed nested declaration\n')
        with self.assertRaisesRegex(RuntimeError, 'Host lacks an unambiguous byte-identical'):
            self.project()

    def test_forwarding_target_may_not_escape_its_original_root(self):
        self.add_original_layouts()
        target = self.nanopb / 'nanopb/pb.h'
        outside = self.distribution / 'Clang/Packages/another/pb.h'
        save(outside, target.read_text())
        target.unlink()
        target.symlink_to(outside)
        with self.assertRaisesRegex(RuntimeError, 'escaping'):
            self.project()

    def test_changed_host_header_is_rejected(self):
        save(self.host_headers['FirebaseCore'], '// changed declaration\n')
        with self.assertRaisesRegex(RuntimeError, 'byte-identical shared declaration'):
            self.project()

    def test_missing_host_header_is_rejected(self):
        self.host_headers['FBLPromises'].unlink()
        with self.assertRaisesRegex(RuntimeError, 'byte-identical shared declaration'):
            self.project()

    def test_two_host_maps_for_one_module_are_rejected(self):
        save(self.root / 'Pods/Headers/Public/Extra/Other.modulemap', 'module FirebaseCore { header "Other.h" }\n')
        with self.assertRaisesRegex(RuntimeError, 'Multiple CocoaPods maps'):
            self.project()

    def test_unreviewed_additional_collision_is_rejected(self):
        save(self.root / 'Pods/Headers/Public/Extra/Unshared.modulemap', 'module Unshared { header "Unshared.h" }\n')
        with self.assertRaisesRegex(RuntimeError, 'Unreviewed Host/producer Clang collision'):
            self.project()


if __name__ == '__main__':
    unittest.main()
