"""Read-only verification of retained, actually executed GitHub Native evidence.

This does not run or grant new Native tests. A recorded failed case stays failed.
"""
from pathlib import Path
import hashlib
import gzip
import json
import plistlib
import re
import sys
import zipfile

def sha(data):
    return hashlib.sha256(data).hexdigest()

def blob(data):
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()

def payload(path):
    path = Path(path)
    raw = path.read_bytes()
    data = json.loads(gzip.decompress(raw) if path.suffix == '.gz' else raw)
    if 'structuredContent' in data:
        data = data['structuredContent']['content']
        if isinstance(data, str):
            data = json.loads(data)
    return data

def verify(config):
    archive = Path(config['archive'])
    raw = archive.read_bytes()
    assert len(raw) == config['archive_bytes'] and sha(raw) == config['archive_sha256']
    tree = payload(config['tree_receipt'])
    assert tree['sha'] == config['tree'] and tree.get('truncated') is False
    canonical = {row['path']: row for row in tree['tree']}
    with zipfile.ZipFile(archive) as evidence:
        assert evidence.testzip() is None
        members = evidence.namelist()
        assert len(members) == len(set(members)) == config['zip_members']
        def read(path): return evidence.read(path)
        def load(path): return json.loads(read(path))
        prefix = 'artifacts/' + config['route'] + '/'
        before, after = [load(prefix + 'SOURCE_' + phase + '.json') for phase in ('BEFORE', 'AFTER')]
        assert before['status'] == after['status'] == 'SOURCE_BOUND_ONLY'
        assert before['head'] == after['head'] == config['F']
        assert before['application_and_tests'] == after['application_and_tests'] == config['M']
        assert before['phase'] == 'before' and after['phase'] == 'after'
        assert before['trees'] == after['trees']
        assert before['execution_inputs'] == after['execution_inputs']
        for path, oid in before['trees'].items():
            assert canonical[path]['type'] == 'tree' and canonical[path]['sha'] == oid, path
        overlap = set(before['execution_inputs']) & set(before['product_inputs'])
        assert all(before['execution_inputs'][p] == before['product_inputs'][p] for p in overlap)
        inputs = {**before['execution_inputs'], **before['product_inputs']}
        for path, row in inputs.items():
            assert canonical[path]['type'] == 'blob' and canonical[path]['sha'] == row['blob'], path
            assert canonical[path]['size'] == row['bytes'], path
        app = load('hq-stage2/result.json')
        post = load(prefix + 'original-post-ui-input-audit.json')
        assert app['status'] == post['status'] == 'SIMULATOR_BUILD_FOR_REAL_UI_PASS'
        assert app['checkout_sha'] == post['checkout_sha'] == config['F']
        assert app['application_source_sha'] == post['application_source_sha'] == config['M']
        assert app['application_trees'] == {p: before['trees'][p] for p in app['application_trees']}
        actual = load('hq-stage2/actual-source-inputs.json')
        assert len(actual) == app['actual_source_inputs_verified'] == post['actual_source_inputs_verified']
        assert after['product_inputs']['original_helper_actual_source_count'] == len(actual)
        differences = [p for p, oid in actual.items() if canonical[p]['sha'] != oid]
        assert differences == ['Source/PrivacyInfo.xcprivacy']
        original_privacy, compiled_privacy = read('hq-stage2/privacy-original.xcprivacy'), read('hq-stage2/privacy-generated.xcprivacy')
        assert blob(original_privacy) == canonical[differences[0]]['sha']
        assert blob(compiled_privacy) == actual[differences[0]]
        generated = app['generated_configuration']
        assert len(generated) == 1
        # The original post-UI helper appends a second identical audit entry.
        # Verify both entries exactly rather than dropping a distinct change.
        assert post['generated_configuration'] == generated + generated
        assert after['product_inputs']['generated_configuration'] == generated + generated
        item = generated[0]
        assert item['origin'] == 'Original React Native CocoaPods privacy aggregation'
        assert item['original_sha256'] == sha(original_privacy) and item['compiled_sha256'] == sha(compiled_privacy)
        assert item['all_other_declarations_unchanged'] is True and item['all_original_reasons_retained'] is True
        old, new = plistlib.loads(original_privacy), plistlib.loads(compiled_privacy)
        access = 'NSPrivacyAccessedAPITypes'
        assert {k: v for k, v in old.items() if k != access} == {k: v for k, v in new.items() if k != access}
        def reasons(value):
            return {(row['NSPrivacyAccessedAPIType'], r) for row in value[access] for r in row['NSPrivacyAccessedAPITypeReasons']}
        old_reasons, new_reasons = reasons(old), reasons(new)
        assert old_reasons <= new_reasons
        assert new_reasons - old_reasons == {(r['category'], r['reason']) for r in item['added_reasons']}
        for row in item['added_reasons']:
            assert row['dependency_inputs']
            for dep in row['dependency_inputs']:
                data = read('hq-stage2/' + dep['artifact_path'])
                assert sha(data) == dep['sha256']
                assert (row['category'], row['reason']) in reasons(plistlib.loads(data))
        packages = after['product_inputs']['package_checkouts']
        assert packages == post['actual_package_checkouts']
        assert all(row['status'] == 'CLEAN' for row in packages.values())
        runtime = load('artifacts/runtime27/result.json')
        summary = load('artifacts/runtime27/verified-' + config['configuration'] + '.summary.json')
        nodes = load('artifacts/runtime27/verified-' + config['configuration'] + '.tests.json')
        leaves = []
        def visit(node):
            if node.get('nodeType') == 'Test Case':
                leaves.append({'case_id': node['nodeIdentifier'].removesuffix('()'), 'actual': node['result'],
                               'duration_seconds': node['durationInSeconds']})
            for child in node.get('children', []): visit(child)
        for node in nodes['testNodes']: visit(node)
        assert len(leaves) == len({row['case_id'] for row in leaves}) == len(config['expected'])
        actual_leaves = {row['case_id']: row['actual'] for row in leaves}
        assert actual_leaves == config['expected']
        assert {r['case_id']: r['actual'] for r in runtime['case_outcomes']} == actual_leaves
        passed = sum(row['actual'] == 'Passed' for row in leaves)
        failed = sum(row['actual'] == 'Failed' for row in leaves)
        assert passed + failed == len(leaves)
        assert summary['passedTests'] == runtime['executed_ui_pass'] == passed
        assert summary['failedTests'] == runtime['executed_ui_fail'] == failed
        assert summary['skippedTests'] == runtime['executed_ui_skip'] == runtime['ui_not_run'] == 0
        assert summary['totalTestCount'] == len(leaves)
        testlog = read('artifacts/test-simulator-' + config['configuration'] + '.log').decode()
        terminals = re.findall(r"Test Case '-\[[^ ]+\.([^ ]+) ([^\]]+)\]' (passed|failed) \(([0-9.]+) seconds\)\.", testlog)
        assert {cls + '/' + name: result.title() for cls, name, result, _ in terminals} == actual_leaves
        assert len(terminals) == len(leaves)
        assert '-default-test-execution-time-allowance 600 -maximum-test-execution-time-allowance 600' in testlog
        return {'status': 'READ_ONLY_RECEIPTS_VERIFIED', 'F': config['F'], 'M': config['M'], 'tree': tree['sha'],
                'archive_sha256': sha(raw), 'crc_verified_members': len(members),
                'execution_inputs_before_after': len(before['execution_inputs']), 'canonical_union_inputs': len(inputs),
                'actual_product_input_count': len(actual), 'official_generated_privacy_verified': True,
                'actual_full_app_build': 'PASS', 'actual_leaves': leaves, 'passed': passed, 'failed': failed,
                'skipped': 0, 'not_run': 0, 'new_Native_tests_executed_by_this_verifier': 0,
                'full_Native116_or_Release114': False}

if __name__ == '__main__':
    config_path = Path(sys.argv[1]).resolve()
    config = json.loads(config_path.read_text())
    for key in ('archive', 'tree_receipt'):
        if not Path(config[key]).is_absolute():
            config[key] = str(config_path.parent / config[key])
    print(json.dumps(verify(config), indent=2, ensure_ascii=False))
