"""Verify exact CocoaPods/SDK project and privacy projections of frozen source.

The canonical product remains immutable. Only the two original generated files
may differ, and their actual bytes must belong to the prior retained preparation
or the current successful original-SDK build. Every call rechecks those bytes.
"""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import runpy
import subprocess

PROJECT = 'Maktabah.xcodeproj/project.pbxproj'
PRIVACY = 'Source/PrivacyInfo.xcprivacy'
ROOTS = ['Source', 'Vendor', 'Maktabah.xcodeproj', 'Maktabah-iOSUITests']
SUCCESS = 'SIMULATOR_BUILD_FOR_REAL_UI_PASS'


def require(value, message):
    if not value:
        raise RuntimeError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def record(path):
    raw = path.read_bytes()
    return {'bytes': len(raw), 'sha256': sha(raw)}


def owned(root, relative, *, build=False, source_link=False):
    relative = Path(relative)
    require(not relative.is_absolute() and '..' not in relative.parts
            and relative.as_posix() != '.' and (not build or relative.parts[0] == 'build'),
            'Invalid generated projection evidence path')
    path = root / relative
    require(path.resolve(strict=True).is_relative_to(root) and path.is_file(),
            'Generated projection file escaped or is missing: ' + relative.as_posix())
    if not source_link:
        require(not any(p.is_symlink() for p in [path, *path.parents] if p.is_relative_to(root)),
                'Generated projection evidence contains an alias')
    return path


def git(root, *args):
    return subprocess.check_output(['git', *args], cwd=root, timeout=90)


def receipt(root, row):
    require(set(row) == {'path', 'bytes', 'sha256'}, 'Malformed retained projection receipt')
    path = owned(root, row['path'], build=True)
    require(record(path) == {key: row[key] for key in ('bytes', 'sha256')},
            'Retained projection receipt bytes differ')
    return json.loads(path.read_bytes())


def verify_privacy(root, build):
    before = git(root, 'show', 'HEAD:' + PRIVACY)
    after = owned(root, PRIVACY).read_bytes()
    rows = [row for row in build.get('generated_configuration', []) if row.get('path') == PRIVACY]
    require(len(rows) == 1, 'Successful preparation lacks one exact privacy projection receipt')
    row = rows[0]
    require(row.get('origin') == 'Original React Native CocoaPods privacy aggregation'
            and row.get('original_git_blob') == git(root, 'rev-parse', 'HEAD:' + PRIVACY).decode().strip()
            and row.get('original_sha256') == sha(before) and row.get('compiled_sha256') == sha(after)
            and row.get('all_other_declarations_unchanged') is True
            and row.get('all_original_reasons_retained') is True,
            'Generated privacy does not match its original/current source receipt')
    original = runpy.run_path(str(root / 'Scripts/CI/hq-stage2-focused-apple.py'))
    evidence = {}
    for added in row['added_reasons']:
        pair = (added['category'], added['reason'])
        require(pair not in evidence and added['dependency_inputs'], 'Duplicate or empty privacy dependency proof')
        for item in added['dependency_inputs']:
            dependency = owned(root, item['path'], source_link=True)
            require(record(dependency)['sha256'] == item['sha256'], 'Actual dependency privacy bytes changed')
            categories = original['privacy_categories'](plistlib.loads(dependency.read_bytes()))
            require(pair[1] in categories.get(pair[0], set()),
                    'Actual dependency does not declare the generated privacy reason')
        evidence[pair] = added['dependency_inputs']
    actual = original['validate_privacy_delta'](plistlib.loads(before), plistlib.loads(after), evidence)
    require(actual == row['added_reasons'], 'Original privacy semantic proof differs')
    return {'original_sha256': sha(before), 'compiled_sha256': sha(after),
            'added_reason_count': len(actual), 'original_semantic_validator': 'PASS'}


def verify(root, product, admission, *, require_current_build=False):
    root = Path(root).resolve(strict=True)
    head = git(root, 'rev-parse', 'HEAD').decode().strip()
    canonical_raw = git(root, 'show', 'HEAD:' + PROJECT)
    canonical = {'git_blob': git(root, 'rev-parse', 'HEAD:' + PROJECT).decode().strip(),
                 'bytes': len(canonical_raw), 'sha256': sha(canonical_raw)}
    changed = git(root, 'diff', '--name-only', product['application_source_sha'], '--', *ROOTS).decode().splitlines()
    require(set(changed) <= {PROJECT, PRIVACY},
            'Working product changed outside original generated project/privacy projections')
    manifest_name = os.environ.get('ORIGINAL_EDITOR_PREPARED_MANIFEST')
    manifest_sha = os.environ.get('ORIGINAL_EDITOR_PREPARED_SHA256')
    require(bool(manifest_name) == bool(manifest_sha), 'Prepared projection needs both manifest and digest')
    binding = {'canonical_project': canonical, 'prepared_manifest': manifest_name,
               'prepared_manifest_sha256': manifest_sha}
    prior, capture = None, None
    if manifest_name:
        path = owned(root, manifest_name, build=True)
        require(re.fullmatch(r'[a-f0-9]{64}', manifest_sha or '') and record(path)['sha256'] == manifest_sha,
                'Prepared projection capture differs from its reviewed bytes')
        capture = json.loads(path.read_bytes())
        require(capture.get('schema') == 'otzaria.mac-prepared-inputs/1'
                and capture.get('status') == 'SUCCESSFUL_BUILD_PREPARATION_CAPTURED'
                and capture.get('root') == str(root) and capture.get('canonical_project') == canonical,
                'Prepared projection capture does not bind this canonical source/root')
        prior = receipt(root, capture['prior_build'])
        receipt(root, capture['prior_source_inputs'])
        require(prior.get('checkout_sha') == capture.get('captured_checkout_sha')
                and prior.get('status') == SUCCESS
                and prior.get('actual_source_inputs_verified', 0) > 0
                and prior.get('actual_package_checkouts')
                and capture.get('generated_project_sha256') == prior['native_context']['generated_project_sha256']
                and capture.get('generated_configuration') == prior.get('generated_configuration', []),
                'Prepared projection lost its actual successful build provenance')
        subprocess.run(['git', 'merge-base', '--is-ancestor', prior['checkout_sha'], head],
                       cwd=root, check=True, timeout=90)
    current_path = root / 'build/hq-stage2/result.json'
    current = json.loads(current_path.read_bytes()) if current_path.is_file() else None
    if current and current.get('checkout_sha') == head:
        selected, route = current, 'CURRENT_ORIGINAL_SDK_BUILD'
        require(selected.get('canonical_project_sha256') == canonical['sha256']
                and selected.get('original_editor_distribution', {}).get('admission_sha256') == sha(admission.read_bytes()),
                'Current build does not bind canonical project and exact SDK admission')
        if capture:
            reuse = selected.get('prepared_input_reuse', {})
            require(reuse.get('manifest') == manifest_name and reuse.get('manifest_sha256') == manifest_sha
                    and reuse.get('prior_build_receipt') == capture['prior_build']
                    and reuse.get('prior_source_inputs') == capture['prior_source_inputs']
                    and reuse.get('prior_checkout_sha') == capture['captured_checkout_sha']
                    and reuse.get('current_checkout_sha') == head and reuse.get('native_build_skipped') is False,
                    'Current SDK build is not the exact continuation of retained preparation')
        configuration = root / 'build/hq-stage2/original-editor/app-target-configuration.json'
        target = json.loads(configuration.read_bytes())
        require(target.get('before_project_sha256') == selected['native_context']['pre_original_editor_project_sha256']
                and target.get('after_project_sha256') == selected['native_context']['generated_project_sha256']
                and target.get('all_other_objects_unchanged') is True
                and record(owned(root, 'build/hq-stage2/original-editor/generated-Maktabah-project.pbxproj', build=True))
                    == record(owned(root, PROJECT)),
                'Current SDK project projection lost its exact app-target proof')
        selected_record = {'path': 'build/hq-stage2/result.json', **record(current_path)}
    elif prior and not require_current_build:
        selected, route, selected_record = prior, 'RETAINED_PRIOR_PREPARATION', capture['prior_build']
    else:
        require(not require_current_build and not changed,
                'Generated product bytes have no current or exact retained successful build')
        return {'binding': binding, 'status': 'CANONICAL_PRODUCT_UNMODIFIED',
                'working_product_delta': changed, 'native_stageb_qualified': False}
    require(selected.get('status') == SUCCESS and selected.get('scope') == 'SIMULATOR_BUILD_FOR_REAL_UI'
            and selected.get('application_source_sha') == product['application_source_sha']
            and selected.get('application_trees') == {
                key: product['application_trees'][key] for key in ROOTS if key != 'Maktabah-iOSUITests'}
            and selected.get('hanlin_gitlink') == product['hanlin_source']
            and record(owned(root, PROJECT))['sha256'] == selected['native_context']['generated_project_sha256'],
            'Generated project bytes do not belong to the exact successful product build')
    privacy = verify_privacy(root, selected)
    return {'binding': binding, 'status': 'EXACT_GENERATED_PRODUCT_PROJECTION_VERIFIED', 'route': route,
            'build_receipt': selected_record, 'working_product_delta': changed,
            'generated_project_sha256': selected['native_context']['generated_project_sha256'],
            'privacy': privacy, 'native_stageb_qualified': False}
