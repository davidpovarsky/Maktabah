"""Synthetic routing/refusal controls; no compiler, native UI or signing credit."""
import copy
import json
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch

import original_editor_sdk_routes as routes
from original_editor_local_admission import validate_abi_adapter

CI = Path(__file__).resolve().parent
api = runpy.run_path(str(CI / 'hq-original-editor-distribution.py'))
public_fixture = runpy.run_path(str(CI / 'test_original_editor_stageb_admission.py'))['qualification']
shared_api = runpy.run_path(str(CI / 'original_editor_shared_runtime.py'))


class RouteSourceControls(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.manifest = {'schema': 'otzaria.original-editor.build-routes/1', 'status': 'QUALIFIED',
                         'sdk_source_sha': '1' * 40, 'native_source_tree': '2' * 40,
                         'signing_team_id': 'NA6HPWARQ2', 'routes': {}}
        self.configs = {}
        for index, (name, (configuration, platform)) in enumerate(routes.VARIANTS.items(), 3):
            path = 'Scripts/CI/' + name + '.json'
            digest = str(index) * 64
            self.manifest['routes'][name] = {'configuration': configuration, 'platform': platform,
                'admission_path': path, 'admission_sha256': digest}
            self.configs[path] = ({'schema': 3 if name == 'debug-simulator' else
                'otzaria.original-editor.production-input/1', 'producer_kind': 'local-mac',
                'repository': 'davidpovarsky/anytype-swift', 'configuration': configuration,
                'platform': platform, 'source_sha': '1' * 40, 'native_source_tree': '2' * 40,
                'archive_sha256': str(index + 3) * 64, 'signing_team_id': 'NA6HPWARQ2'}, digest)

    def load(self):
        def read(root, relative):
            return (self.manifest, 'a' * 64) if relative == routes.MANIFEST else self.configs[relative]
        with patch.object(routes, 'committed_json', side_effect=read):
            return routes.load(self.root)

    def test_three_distinct_platform_routes_select_without_runtime_credit(self):
        result = self.load()
        self.assertEqual(routes.select(result, 'Release', 'iphoneos')['platform'], 'iphoneos')
        self.assertEqual(routes.select(result, 'Debug', 'iphonesimulator')['configuration'], 'Debug')
        with self.assertRaisesRegex(RuntimeError, 'no qualified SDK route'):
            routes.select(result, 'Debug', 'iphoneos')

    def test_unqualified_source_and_cross_source_variants_are_rejected(self):
        self.manifest['status'] = 'UNFINALIZED'
        with self.assertRaisesRegex(RuntimeError, 'not qualified'):
            self.load()
        self.manifest['status'] = 'QUALIFIED'
        self.configs['Scripts/CI/release-device.json'][0]['source_sha'] = '9' * 40
        with self.assertRaisesRegex(RuntimeError, 'same product/native source'):
            self.load()

    def test_device_route_cannot_borrow_a_simulator_or_another_team(self):
        config = self.configs['Scripts/CI/release-device.json'][0]
        config['platform'] = 'iphonesimulator'
        with self.assertRaisesRegex(RuntimeError, 'same product/native source'):
            self.load()
        config['platform'] = 'iphoneos'
        config['signing_team_id'] = 'DIFFERENT1'
        with self.assertRaisesRegex(RuntimeError, 'signing team'):
            self.load()

    def test_changed_working_admission_bytes_are_rejected(self):
        path = self.root / 'Scripts/CI/input.json'
        path.parent.mkdir(parents=True)
        path.write_text('{"changed":true}')
        with patch.object(routes.subprocess, 'check_output', return_value=b'{"changed":false}'):
            with self.assertRaisesRegex(RuntimeError, 'committed source'):
                routes.committed_json(self.root, 'Scripts/CI/input.json')

    def test_route_mutation_after_preparation_is_rejected_before_product_verification(self):
        path = self.root / 'build/prepared/original-editor-routes.json'
        path.parent.mkdir(parents=True)
        path.write_text('{"fixture":"original preparation"}')
        captured_sha = routes.digest(path)
        path.write_text('{"fixture":"mutated after preparation"}')
        with patch.object(routes, 'sdk_api') as delegated:
            with self.assertRaisesRegex(RuntimeError, 'route receipt changed'):
                routes.verify(self.root, path.relative_to(self.root).as_posix(),
                              'Debug', 'iphonesimulator', self.root / 'build/Maktabah.app',
                              route_sha256=captured_sha, after_ui=True)
            delegated.assert_not_called()


class ExactTransportControls(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        base = Path(self.tmp.name)
        self.root, self.cache = base / 'host', base / 'cache'
        self.root.mkdir(); self.cache.mkdir()
        self.packet = self.cache / ('a' * 64)
        self.packet.mkdir()
        values = {'build/sdk/SDK.zip': b'fixture archive', 'build/sdk/manifest.json': b'{}',
                  'build/sdk/hanlin.json': b'{"source":"fixture"}', 'build/sdk/owner.json': b'fixture owner'}
        files = {}
        for name, value in values.items():
            path = self.packet / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(value)
            files[name] = routes.record(path)
        self.config = {'archive_path': 'build/sdk/SDK.zip', 'archive_bytes': files['build/sdk/SDK.zip']['bytes'],
            'archive_sha256': files['build/sdk/SDK.zip']['sha256'],
            'distribution_manifest_path': 'build/sdk/manifest.json',
            'distribution_manifest_sha256': files['build/sdk/manifest.json']['sha256'],
            'hanlin_source_path': 'build/sdk/hanlin.json',
            'hanlin_source_sha256': files['build/sdk/hanlin.json']['sha256'],
            'local_receipts': {'execution': {'path': 'build/sdk/owner.json', **files['build/sdk/owner.json']}}}
        actual_packet = self.cache / self.config['archive_sha256']
        self.packet.rename(actual_packet); self.packet = actual_packet
        self.payload = {'schema': 'otzaria.local-sdk-transport-packet/1', 'admission_sha256': 'b' * 64,
                        'files': files}
        (self.packet / 'PACKET.json').write_text(json.dumps(self.payload))
        self.route = {'manifest_sha256': 'c' * 64, 'routes': {'fixture': {
            'configuration_input': self.config, 'admission_sha256': 'b' * 64}}}

    def stage(self):
        return routes.stage(self.root, self.route, cache_root=self.cache)

    def test_fresh_transport_and_exact_reuse_preserve_owner_bytes(self):
        self.assertFalse(self.stage()['native_build_or_runtime_qualified'])
        self.assertEqual((self.root / 'build/sdk/owner.json').read_bytes(), b'fixture owner')
        self.assertEqual(self.stage()['routes']['fixture']['copied_members'], [])

    def test_changed_cache_bytes_and_changed_existing_input_are_rejected(self):
        self.stage()
        (self.root / 'build/sdk/owner.json').write_bytes(b'other producer')
        with self.assertRaisesRegex(RuntimeError, 'different existing SDK input'):
            self.stage()
        (self.packet / 'build/sdk/SDK.zip').write_bytes(b'changed archive')
        with self.assertRaisesRegex(RuntimeError, 'transport member differs'):
            self.stage()

    def test_symlinked_destination_and_extra_packet_member_are_rejected(self):
        (self.root / 'build').symlink_to(self.packet / 'build', target_is_directory=True)
        with self.assertRaisesRegex(RuntimeError, 'alias or escapes'):
            self.stage()
        (self.root / 'build').unlink()
        self.payload['files']['build/extra'] = {'bytes': 1, 'sha256': 'f' * 64}
        (self.packet / 'PACKET.json').write_text(json.dumps(self.payload))
        with self.assertRaisesRegex(RuntimeError, 'committed admission'):
            self.stage()


class ReleaseAPIControls(unittest.TestCase):
    def fixture(self):
        value = public_fixture(64)
        value.update(configuration='Release-Anytype', platform='iphoneos')
        value['actual_public_surface'].update(debug_qualification_requirements_absent=22,
                                               debug_qualification_symbols_observed=[])
        return value

    def test_public_release_contract_passes_without_editor_ui_credit(self):
        result = api['require_production_host_api'](self.fixture())
        self.assertEqual(result['native_editor_ui_tests'], 0)

    def test_debug_probe_and_spi_leak_cannot_qualify_release(self):
        with self.assertRaises(RuntimeError):
            api['require_production_host_api'](public_fixture(86))
        value = self.fixture()
        value['actual_public_surface']['own_public_symbols'][0]['spi'] = True
        with self.assertRaisesRegex(RuntimeError, 'Debug qualification SPI'):
            api['require_production_host_api'](value)


class AdapterProvenanceControls(unittest.TestCase):
    def fixture(self):
        abi = {'schema': 'otzaria.original-import-local-sdk-input/2', 'pinned_wrapper': {
            'path': 'pinned-wrapper/RESULT.json', 'bytes': 123, 'sha256': 'a' * 64}}
        proof = {'schema': 'otzaria.gomobile-pinned-wrapper-observation/1',
            'status': 'THREE_ACTUAL_PINNED_WRAPPERS_PASS', 'control_sha': 'b' * 40,
            'receipt_sha256': 'a' * 64, 'targets': ['ios-arm64', 'iossimulator-arm64', 'iossimulator-amd64'],
            'original_go_sum_preserved': True, 'all_targets_admitted_before_compile': True,
            'original_gomobile_modified': False, 'rejected_archives_reused': False}
        return abi, {'schema': abi['schema'], 'pinned_wrapper': proof}

    def test_exact_adapter_summary_is_bound_to_the_original_abi(self):
        abi, heart = self.fixture()
        validate_abi_adapter(abi, heart, 'b' * 40)

    def test_wrong_owner_missing_target_or_reused_rejection_cannot_qualify(self):
        for key, value in [('control_sha', 'c' * 40), ('targets', ['ios-arm64']),
                           ('receipt_sha256', 'f' * 64), ('rejected_archives_reused', True)]:
            abi, heart = self.fixture()
            heart['pinned_wrapper'][key] = value
            with self.subTest(key=key), self.assertRaisesRegex(RuntimeError, 'complete pinned-wrapper'):
                validate_abi_adapter(abi, heart, 'b' * 40)
        abi, heart = self.fixture()
        abi['schema'] = 'otzaria.original-import-local-sdk-input/1'
        with self.assertRaisesRegex(RuntimeError, 'Historical ABI'):
            validate_abi_adapter(abi, heart, 'b' * 40)


class RecordedArchiveLibraryControls(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        folder = self.root / 'build/actual-xcode-products'
        folder.mkdir(parents=True)
        self.rows = {}
        for pod in shared_api['PODS']:
            path = folder / ('lib' + pod + '.a')
            path.write_bytes(b'SYNTHETIC_LIB_METADATA_ONLY:' + pod.encode())
            self.rows[pod] = {'canonical_path': str(path), **routes.record(path)}

    def test_exact_observed_libraries_are_used_without_an_archive_layout_guess(self):
        paths = shared_api['recorded_host_library_paths'](self.root, self.rows)
        self.assertEqual(set(paths), set(shared_api['PODS']))
        self.assertEqual(paths['FirebaseCore'], Path(self.rows['FirebaseCore']['canonical_path']))

    def test_missing_changed_or_aliased_library_is_refused(self):
        missing = copy.deepcopy(self.rows)
        missing.pop('FirebaseCore')
        with self.assertRaisesRegex(RuntimeError, 'Incomplete original Host library'):
            shared_api['recorded_host_library_paths'](self.root, missing)
        changed = copy.deepcopy(self.rows)
        changed['FirebaseCore']['sha256'] = 'f' * 64
        with self.assertRaisesRegex(RuntimeError, 'changed or escaped'):
            shared_api['recorded_host_library_paths'](self.root, changed)
        alias = self.root / 'build/alias.a'
        alias.symlink_to(self.rows['FirebaseCore']['canonical_path'])
        changed['FirebaseCore'] = {**self.rows['FirebaseCore'], 'canonical_path': str(alias)}
        with self.assertRaisesRegex(RuntimeError, 'changed or escaped'):
            shared_api['recorded_host_library_paths'](self.root, changed)


if __name__ == '__main__':
    unittest.main()
