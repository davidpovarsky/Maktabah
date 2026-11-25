"""Exact Mac application leaf above the retained original StageB history.

This proves source composition only. The separately produced SDK and the real
save/export/import/process-reopen UI journey still have to qualify.
"""
import hashlib
import json
from pathlib import Path
import subprocess

HISTORICAL_CONTROL = '602659607a3a6a2586a7c4a8d7ce6114eec8cd86'
PREVIOUS = '7d5510dd29af2b66d740de136352916868c341ed'
SOURCE = '3c5a57bea389f6223b4636c45705bb62f502add2'
CURRENT_SOURCE = 'd3da55417a30e9a06b0255e2d0b561955034b260'
CURRENT_CONTROL = '28c86f9bfcfc251816f71efac94b2ced4010f27c'
CURRENT_PATH = 'Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinChatView.swift'
ACCEPTED = '73cbc16722ea33f3600ba19f1ca35dbd1a4d9812'
HANLIN = 'f8cf6ca543c5ceed05a60141644664c93e4565b4'
CORE = '3f38f1302764635c9991d0d00fd7b12471a5373c'
PREVIOUS_CORE = '07431abccbfb151ca2dab67bca6cf86fcb2bd3b8'
ROOTS = ['Source', 'Vendor', 'Maktabah.xcodeproj', 'Maktabah-iOSUITests']
LOCK = 'Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
DELTA = ['Maktabah-iOSUITests/HanlinConsumerAcceptanceTests.swift', LOCK, 'Vendor/HanlinSDK']
INPUT_FIELDS = {'application_source_sha', 'application_trees', 'hanlin_gitlink',
                'mac_shared_composition', 'otzaria_test_additions_sha256'}


def require(value, message):
    if not value:
        raise RuntimeError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def git(root, *args):
    return subprocess.check_output(['git', *args], cwd=root, timeout=90)


def text(root, *args):
    return git(root, *args).decode().strip()


def source_object(root, revision, path):
    listing = text(root, 'ls-tree', revision, '--', path)
    require(listing, 'Missing exact Mac source object: ' + path)
    metadata, actual_path = listing.split('\t')
    require(actual_path == path, 'Mac source object path differs')
    mode, kind, identity = metadata.split()
    result = {'mode': mode, 'kind': kind, 'object': identity}
    if kind == 'blob':
        raw = git(root, 'show', revision + ':' + path)
        result.update(bytes=len(raw), sha256=sha(raw))
    return result


def verify_build_input_delta(before, after, config):
    actual = {key: {'before': before.get(key), 'after': after.get(key)}
              for key in sorted(before.keys() | after.keys()) if before.get(key) != after.get(key)}
    require(set(actual) == INPUT_FIELDS and actual == config['changed_values'],
            'Mac source binding changed undeclared build inputs')
    require('mac_shared_composition' not in before,
            'Historical build input unexpectedly contains the new Mac leaf')
    for value in (before, after):
        common = {key: item for key, item in value.items() if key not in INPUT_FIELDS}
        require(sha(json.dumps(common, sort_keys=True, separators=(',', ':')).encode())
                == config['all_remaining_fields_canonical_sha256'],
                'Mac source leaf changed retained engine/resource/artifact inputs')


def verify_current_build_input_delta(before, after, binding):
    fields = {'application_source_sha', 'application_trees'}
    actual = {key: {'before': before.get(key), 'after': after.get(key)}
              for key in sorted(before.keys() | after.keys()) if before.get(key) != after.get(key)}
    require(set(actual) == fields and actual == binding['changed_values'],
            'Composer leaf changed undeclared build inputs')
    for value in (before, after):
        common = {key: item for key, item in value.items() if key not in fields}
        require(sha(json.dumps(common, sort_keys=True, separators=(',', ':')).encode())
                == binding['all_remaining_fields_canonical_sha256'],
                'Composer leaf changed retained dependency or artifact inputs')


def verify_current_product(root, envelope, dependency_trees, prior_inputs):
    leaf = envelope['current_product_leaf']
    require(leaf['previous_application_source'] == SOURCE
            and leaf['source_parent'] == CURRENT_CONTROL
            and leaf['application_source_sha'] == CURRENT_SOURCE
            and leaf['acceptance'] == 'REVIEWED_SOURCE_REQUIRES_NEW_NATIVE_BUILD_AND_UI'
            and leaf['native_ui_qualified'] is False,
            'Current product leaf changed its reviewed identity or acceptance scope')
    require(text(root, 'rev-parse', CURRENT_SOURCE + '^') == CURRENT_CONTROL,
            'Composer source has an unexpected parent')
    for before, after in [(SOURCE, CURRENT_SOURCE), (CURRENT_SOURCE, 'HEAD')]:
        subprocess.run(['git', 'merge-base', '--is-ancestor', before, after], cwd=root, check=True, timeout=90)
    require(text(root, 'diff', '--name-only', CURRENT_CONTROL, CURRENT_SOURCE).splitlines() == [CURRENT_PATH]
            and text(root, 'diff', '--name-only', SOURCE, CURRENT_SOURCE, '--', *ROOTS).splitlines() == [CURRENT_PATH],
            'Composer leaf includes an undeclared product or test change')
    trees = {path: text(root, 'rev-parse', CURRENT_SOURCE + ':' + path) for path in ROOTS}
    require(leaf['application_trees'] == trees
            and trees == {path: text(root, 'rev-parse', 'HEAD:' + path) for path in ROOTS}
            and all(trees[path] == dependency_trees[path] for path in ROOTS if path != 'Source'),
            'Current product changes an unrelated dependency, project or XCTest tree')
    rows = leaf['product_delta']
    require(len(rows) == 1 and rows[0]['path'] == CURRENT_PATH
            and rows[0]['before'] == source_object(root, SOURCE, CURRENT_PATH)
            == source_object(root, CURRENT_CONTROL, CURRENT_PATH)
            and rows[0]['after'] == source_object(root, CURRENT_SOURCE, CURRENT_PATH)
            == source_object(root, 'HEAD', CURRENT_PATH),
            'Composer leaf differs from the exact reviewed source object')
    binding = leaf['build_inputs']
    require(binding['path'] == 'Scripts/CI/hq-stage2-focused-apple.inputs.json', 'Current build input path differs')
    after_raw = (root / binding['path']).read_bytes()
    require(sha(prior_inputs) == binding['previous_sha256'] and sha(after_raw) == binding['current_sha256'],
            'Current source binding input bytes differ')
    before, after = json.loads(prior_inputs), json.loads(after_raw)
    verify_current_build_input_delta(before, after, binding)
    require(after['application_source_sha'] == CURRENT_SOURCE and after['hanlin_gitlink'] == HANLIN
            and after['application_trees'] == {p: trees[p] for p in ROOTS if p != 'Maktabah-iOSUITests'},
            'Current build inputs do not bind the composer source')
    return {'previous_application_source': SOURCE, 'application_source_sha': CURRENT_SOURCE,
            'application_trees': trees, 'current_product_objects_verified': 1,
            'current_product_paths': [CURRENT_PATH], 'build_input_sha256': binding['current_sha256'],
            'new_native_build_required': True, 'native_stageb_qualified': False}


def verify(root, manifest, expected_sha256):
    root, manifest = Path(root), Path(manifest)
    require(manifest.is_file() and not manifest.is_symlink()
            and sha(manifest.read_bytes()) == expected_sha256,
            'Reviewed Mac product source manifest differs')
    envelope = json.loads(manifest.read_bytes())
    require(envelope.get('schema') == 'otzaria.original-editor.mac-product-source/2'
            and envelope.get('retained_control_source') == CURRENT_CONTROL,
            'Current Mac source envelope changed')
    original_manifest = git(root, 'show', CURRENT_CONTROL + ':Scripts/CI/runtime27-original-editor-mac-source.inputs.json')
    require(sha(original_manifest) == envelope['retained_dependency_manifest_sha256']
            and json.loads(original_manifest) == envelope['retained_dependency_leaf'],
            'Immutable retained dependency manifest changed')
    config = envelope['retained_dependency_leaf']
    require(config.get('schema') == 'otzaria.original-editor.mac-product-source/1'
            and config.get('historical_control_source') == HISTORICAL_CONTROL
            and config.get('previous_application_source') == PREVIOUS
            and config.get('application_source_sha') == SOURCE
            and config.get('accepted_source') == ACCEPTED
            and config.get('hanlin_source') == HANLIN
            and config.get('swift_ai_sdk_source') == CORE
            and config.get('acceptance') == 'SOURCE_COMPOSITION_ONLY_NOT_RUNTIME'
            and config.get('native_stageb_qualified') is False,
            'Mac product leaf changed its exact reviewed identities or scope')
    subprocess.run(['git', 'merge-base', '--is-ancestor', PREVIOUS, SOURCE],
                   cwd=root, check=True, timeout=90)
    subprocess.run(['git', 'merge-base', '--is-ancestor', SOURCE, 'HEAD'],
                   cwd=root, check=True, timeout=90)
    trees = {path: text(root, 'rev-parse', SOURCE + ':' + path) for path in ROOTS}
    require(config['application_trees'] == trees
            and trees['Source'] == text(root, 'rev-parse', PREVIOUS + ':Source'),
            'Mac product leaf or current committed product trees differ')
    paths = text(root, 'diff', '--name-only', PREVIOUS, SOURCE, '--', *ROOTS).splitlines()
    require(paths == DELTA and [row['path'] for row in config['product_delta']] == DELTA,
            'Mac product leaf has an undeclared application/test delta')
    for row in config['product_delta']:
        path = row['path']
        require(row['accepted_source'] == ACCEPTED
                and source_object(root, PREVIOUS, path) == row['before']
                and source_object(root, SOURCE, path) == row['after']
                and source_object(root, ACCEPTED, path) == row['accepted_source_object'] == row['after'],
                'Mac product does not equal the exact accepted object: ' + path)
    before_lock = git(root, 'show', PREVIOUS + ':' + LOCK)
    after_lock = git(root, 'show', SOURCE + ':' + LOCK)
    require(before_lock.count(PREVIOUS_CORE.encode()) == 1
            and after_lock == before_lock.replace(PREVIOUS_CORE.encode(), CORE.encode())
            and after_lock.replace(CORE.encode(), PREVIOUS_CORE.encode()) == before_lock,
            'Mac Core pin is not the exact reviewed reversible lockfile change')
    binding = config['build_inputs']
    require(binding['path'] == 'Scripts/CI/hq-stage2-focused-apple.inputs.json',
            'Mac source build input path differs')
    before_raw = git(root, 'show', HISTORICAL_CONTROL + ':' + binding['path'])
    after_raw = git(root, 'show', CURRENT_CONTROL + ':' + binding['path'])
    require(sha(before_raw) == binding['previous_sha256']
            and sha(after_raw) == binding['current_sha256'], 'Mac build input bytes differ')
    before, after = json.loads(before_raw), json.loads(after_raw)
    verify_build_input_delta(before, after, binding)
    require(after['application_source_sha'] == SOURCE and after['hanlin_gitlink'] == HANLIN
            and after['application_trees'] == {path: trees[path] for path in ROOTS if path != 'Maktabah-iOSUITests'},
            'Mac build inputs do not bind the reviewed current product')
    shared = config['shared_manifest']
    require(shared['path'] == 'docs/hq-integration/mac-execution-20261124/SHARED_SOURCE.json',
            'Mac shared composition manifest path differs')
    shared_path = root / shared['path']
    shared_raw = shared_path.read_bytes()
    require(not shared_path.is_symlink() and sha(shared_raw) == shared['sha256']
            and git(root, 'show', 'HEAD:' + shared['path']) == shared_raw,
            'Mac shared composition manifest differs from its committed bytes')
    shared_value = json.loads(shared_raw)
    require(shared_value['application_source_sha'] == SOURCE
            and shared_value['application_trees'] == trees
            and shared_value['retained_union_product'] == PREVIOUS
            and shared_value['imported_source'] == ACCEPTED,
            'Mac shared and StageB product manifests disagree')
    current = verify_current_product(root, envelope, trees, after_raw)
    return {'manifest_sha256': expected_sha256, 'historical_control_source': HISTORICAL_CONTROL,
            'previous_application_source': PREVIOUS, 'application_source_sha': SOURCE,
            'application_trees': trees, 'hanlin_source': HANLIN, 'swift_ai_sdk_source': CORE,
            'additional_product_objects_verified': len(DELTA), 'product_paths': DELTA,
            'build_input_sha256': binding['current_sha256'],
            'preserved_build_inputs_sha256': binding['all_remaining_fields_canonical_sha256'],
            'new_runtime_acceptance_required': True, 'native_stageb_qualified': False,
            'retained_dependency_application_source': SOURCE,
            'retained_dependency_application_trees': trees,
            'retained_dependency_previous_source': PREVIOUS, **current}


def working_product_delta(root):
    return text(root, 'diff', '--name-only', CURRENT_SOURCE, '--', *ROOTS).splitlines()
