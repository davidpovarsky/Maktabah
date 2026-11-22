"""Run only three newly affected schema 2 selector boundaries, once."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parent
def identity(path):
    raw = path.read_bytes()
    return dict(path=path.relative_to(ROOT.parent).as_posix(), bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest())

def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    inputs = [ROOT / 'candidate/Scripts/CI/select-runtime27-toolchain.py',
        ROOT / 'candidate/Scripts/CI/original_editor_continuation_admission.py',
        ROOT / 'original/select-runtime27-toolchain.py', ROOT / 'test_selector_schema2.py',
        ROOT / 'run_controls.py', ROOT.parent / 'FRAMEWORK_PRODUCER.json']
    before = [identity(path) for path in inputs]
    (args.output / 'SOURCE_INPUTS.json').write_text(json.dumps(before, indent=2) + '\n')
    spec = importlib.util.spec_from_file_location('selector_schema2', ROOT / 'test_selector_schema2.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    suite = unittest.defaultTestLoader.loadTestsFromModule(module)
    expected = sorted(test.id() for group in suite for test in group)
    assert len(expected) == len(set(expected)) == 3
    started, passed = [], []
    class Result(unittest.TextTestResult):
        def startTest(self, test):
            started.append(test.id())
            print(json.dumps(dict(event='start', id=test.id())), flush=True)
            super().startTest(test)
        def addSuccess(self, test):
            passed.append(test.id())
            print(json.dumps(dict(event='pass', id=test.id())), flush=True)
            super().addSuccess(test)
    result = unittest.TextTestRunner(verbosity=2, resultclass=Result).run(suite)
    after = [identity(path) for path in inputs]
    complete = result.wasSuccessful() and result.testsRun == 3 and sorted(started) == sorted(passed) == expected and not result.skipped and before == after
    receipt = dict(status='PASS_THREE_NEW_SCHEMA2_SELECTOR_BOUNDARIES' if complete else 'FAIL',
        scope='Actual selector plus unchanged schema2 validator; committed synthetic runtime input and original framework contract. No Apple/SDK/native execution.',
        executable=sys.executable, python=sys.version, expected_ids=expected, started_ids=started, passed_ids=passed,
        tests_run=result.testsRun, failures=[t.id() for t, _ in result.failures], errors=[t.id() for t, _ in result.errors],
        skipped=result.skipped, source_inputs=before, source_unchanged=before == after,
        prior_controls_replayed=0, native_execution=False, actual_runtime_pins_committed=False)
    (args.output / 'RESULT.json').write_text(json.dumps(receipt, indent=2) + '\n')
    return 0 if complete else 1

if __name__ == '__main__':
    raise SystemExit(main())
