"""Focused source admission controls; no SDK build or native UI credit."""
import copy
import hashlib
import json
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
CI = ROOT / 'Scripts/CI'
NATIVE = runpy.run_path(str(CI / 'runtime27-original-editor-native.py'))
MAC = runpy.run_path(str(CI / 'original_editor_mac_source.py'))
MANIFEST = CI / 'runtime27-original-editor-mac-source.inputs.json'
CONFIG = json.loads(MANIFEST.read_bytes())


class MacSourceAdmission(unittest.TestCase):
    def test_actual_retained_history_and_three_object_leaf_are_both_verified(self):
        historic = NATIVE['composed_product_source'](
            historical_control_source=NATIVE['HISTORICAL_CONTROL_SOURCE'])
        current = MAC['verify'](ROOT, MANIFEST, NATIVE['MAC_SOURCE_SHA256'])
        self.assertEqual(historic['accepted_source_objects_verified'], 18)
        self.assertEqual(current['additional_product_objects_verified'], 3)
        self.assertFalse(historic['native_stageb_qualified'])
        self.assertFalse(current['native_stageb_qualified'])
        self.assertTrue(current['new_runtime_acceptance_required'])

    def test_declared_leaf_cannot_replace_an_accepted_source_object(self):
        config = copy.deepcopy(CONFIG)
        config['product_delta'][0]['after']['object'] = '0' * 40
        raw = (json.dumps(config) + '\n').encode()
        with tempfile.TemporaryDirectory(prefix='otzaria-mac-source-control-') as directory:
            path = Path(directory) / 'changed.json'
            path.write_bytes(raw)
            with self.assertRaisesRegex(RuntimeError, 'exact accepted object'):
                MAC['verify'](ROOT, path, hashlib.sha256(raw).hexdigest())

    def test_new_leaf_rejects_undeclared_engine_or_artifact_change(self):
        binding = CONFIG['build_inputs']
        before = json.loads(subprocess.check_output([
            'git', 'show', CONFIG['historical_control_source'] + ':' + binding['path']], cwd=ROOT))
        current = json.loads((ROOT / binding['path']).read_bytes())
        changed = copy.deepcopy(current)
        changed['artifacts'][0]['id'] += 1
        with self.assertRaisesRegex(RuntimeError, 'undeclared build inputs'):
            MAC['verify_build_input_delta'](before, changed, binding)

    def test_changed_remaining_value_is_rejected_even_with_a_rewritten_delta(self):
        binding = copy.deepcopy(CONFIG['build_inputs'])
        before = json.loads(subprocess.check_output([
            'git', 'show', CONFIG['historical_control_source'] + ':' + binding['path']], cwd=ROOT))
        current = json.loads((ROOT / binding['path']).read_bytes())
        before['artifacts'][0]['id'] += 1
        current['artifacts'][0]['id'] += 1
        with self.assertRaisesRegex(RuntimeError, 'retained engine/resource/artifact'):
            MAC['verify_build_input_delta'](before, current, binding)


if __name__ == '__main__':
    unittest.main()
