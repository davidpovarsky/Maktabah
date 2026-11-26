"""Bind every final app build to the same qualified original SDK source.

The three variants have separate authentic producer receipts. This file only
selects and stages those inputs; native build, API, ownership, UI and signing
acceptance remain with their original producers and consumer validators.
"""
import hashlib
import json
from pathlib import Path
import re
import runpy
import shutil
import subprocess

MANIFEST = 'Scripts/CI/runtime27-original-editor-routes.inputs.json'
VARIANTS = {
    'debug-simulator': ('Debug', 'iphonesimulator'),
    'release-simulator': ('Release', 'iphonesimulator'),
    'release-device': ('Release', 'iphoneos'),
}


def require(value, message):
    if not value:
        raise RuntimeError(message)


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def record(path):
    path = Path(path)
    return {'bytes': path.stat().st_size, 'sha256': digest(path)}


def owned(root, relative, prefix):
    root = Path(root).resolve(strict=True)
    relative = Path(relative)
    require(not relative.is_absolute() and '..' not in relative.parts
            and relative.as_posix().startswith(prefix) and '\\' not in relative.as_posix(),
            'Invalid original SDK input path')
    path = root / relative
    require(path.resolve().is_relative_to(root)
            and not any(p.is_symlink() for p in [path, *path.parents] if p.is_relative_to(root)),
            'Original SDK input path contains an alias or escapes its owner')
    return path


def committed_json(root, relative):
    path = owned(root, relative, 'Scripts/CI/')
    raw = path.read_bytes()
    require(raw == subprocess.check_output(['git', 'show', 'HEAD:' + relative], cwd=root, timeout=90),
            'Original SDK routing input differs from its committed source')
    return json.loads(raw), hashlib.sha256(raw).hexdigest()


def load(root, manifest=MANIFEST):
    root = Path(root).resolve(strict=True)
    value, manifest_sha = committed_json(root, manifest)
    require(value.get('schema') == 'otzaria.original-editor.build-routes/1'
            and value.get('status') == 'QUALIFIED',
            'Final original editor SDK routes are not qualified')
    require(re.fullmatch(r'[a-f0-9]{40}', value.get('sdk_source_sha', ''))
            and re.fullmatch(r'[a-f0-9]{40}', value.get('native_source_tree', ''))
            and set(value.get('routes', {})) == set(VARIANTS),
            'The complete original SDK configuration/platform mapping is required')
    admitted = {}
    for key, (configuration, platform) in VARIANTS.items():
        row = value['routes'][key]
        require(row.get('configuration') == configuration and row.get('platform') == platform
                and re.fullmatch(r'[a-f0-9]{64}', row.get('admission_sha256', '')),
                'Wrong original SDK build variant: ' + key)
        config, actual_sha = committed_json(root, row['admission_path'])
        require(actual_sha == row['admission_sha256']
                and config.get('source_sha') == value['sdk_source_sha']
                and config.get('native_source_tree') == value['native_source_tree']
                and config.get('configuration') == configuration and config.get('platform') == platform
                and config.get('producer_kind') == 'local-mac'
                and re.fullmatch(r'[a-f0-9]{64}', config.get('archive_sha256', '')),
                'Original SDK variants do not bind the same product/native source')
        require(config.get('repository') == 'davidpovarsky/anytype-swift', 'Wrong SDK repository')
        require(config.get('abi_provenance') != 'otzaria.original-import-sdk-debug-continuation/1',
                'Final build routes require independently qualified distributions, not the focused Debug continuation')
        if key == 'debug-simulator':
            require(config.get('schema') == 3, 'Debug must retain the complete original Simulator admission')
        else:
            require(config.get('schema') == 'otzaria.original-editor.production-input/1',
                    'Release requires its separately qualified production SDK')
        if key == 'release-device':
            require(config.get('signing_team_id') == value.get('signing_team_id')
                    and re.fullmatch(r'[A-Z0-9]{10}', value.get('signing_team_id', '')),
                    'Device SDK route lacks its reviewed signing team')
        admitted[key] = {'configuration': configuration, 'platform': platform,
                         'admission_path': row['admission_path'], 'admission_sha256': actual_sha,
                         'configuration_input': config}
    require(len({r['admission_path'] for r in admitted.values()}) == 3,
            'Different SDK variants cannot alias one admission')
    return {'manifest_path': manifest, 'manifest_sha256': manifest_sha,
            'sdk_source_sha': value['sdk_source_sha'], 'native_source_tree': value['native_source_tree'],
            'signing_team_id': value['signing_team_id'], 'routes': admitted}


def select(routes, configuration, platform):
    matches = [row for row in routes['routes'].values()
               if (row['configuration'], row['platform']) == (configuration, platform)]
    require(len(matches) == 1, 'This app configuration/platform has no qualified SDK route')
    return matches[0]


def packet_members(config):
    required = {
        config['archive_path']: {'bytes': config['archive_bytes'], 'sha256': config['archive_sha256']},
        config['distribution_manifest_path']: {'sha256': config['distribution_manifest_sha256']},
        config['hanlin_source_path']: {'sha256': config['hanlin_source_sha256']},
    }
    for row in config['local_receipts'].values():
        require(set(row) == {'path', 'bytes', 'sha256'} and row['path'] not in required,
                'Duplicate or malformed original SDK transport member')
        required[row['path']] = {key: row[key] for key in ('bytes', 'sha256')}
    return required


def stage(root, routes, *, cache_root=None):
    """Copy exact qualified local bytes into a fresh Actions/Host checkout.

    The cache is only transport. Nothing here creates or rewrites a producer
    qualification, archive, source receipt, run identifier or signing approval.
    """
    root = Path(root).resolve(strict=True)
    cache_root = Path(cache_root or Path.home() / 'caches/otzaria-sdk-distributions').resolve(strict=True)
    result = {}
    for key, route in routes['routes'].items():
        config = route['configuration_input']
        packet = owned(cache_root, config['archive_sha256'] + '/PACKET.json', '')
        payload = json.loads(packet.read_bytes())
        expected = packet_members(config)
        require(payload.get('schema') == 'otzaria.local-sdk-transport-packet/1'
                and payload.get('admission_sha256') == route['admission_sha256']
                and set(payload.get('files', {})) == set(expected),
                'Local SDK packet does not match the committed admission')
        copied = []
        for relative, required in expected.items():
            source = owned(packet.parent, relative, 'build/')
            actual = record(source)
            require(actual == payload['files'][relative]
                    and all(actual[name] == number for name, number in required.items()),
                    'Qualified SDK transport member differs: ' + relative)
            destination = owned(root, relative, 'build/')
            if destination.exists():
                require(record(destination) == actual, 'Refusing a different existing SDK input: ' + relative)
            else:
                destination.parent.mkdir(parents=True, exist_ok=True)
                with source.open('rb') as input_stream, destination.open('xb') as output_stream:
                    shutil.copyfileobj(input_stream, output_stream)
                require(record(destination) == actual, 'Staged original SDK bytes differ')
                copied.append(relative)
        result[key] = {'admission_sha256': route['admission_sha256'],
                       'archive_sha256': config['archive_sha256'], 'files': payload['files'],
                       'copied_members': copied, 'producer_identity_rewritten': False}
    return {'status': 'EXACT_ORIGINAL_SDK_VARIANTS_STAGED',
            'routes_manifest_sha256': routes['manifest_sha256'], 'routes': result,
            'native_build_or_runtime_qualified': False}


def sdk_api(root):
    return runpy.run_path(str(Path(root) / 'Scripts/CI/hq-original-editor-distribution.py'))


def restore(root, routes, evidence):
    restorer = runpy.run_path(str(Path(root) / 'Scripts/CI/restore-original-editor-distribution.py'))
    for name, route in routes['routes'].items():
        directory = Path(evidence) / ('transport-' + name)
        directory.mkdir(parents=True, exist_ok=True)
        restorer['stage'](route['configuration_input'], directory)


def prepare(root, report, out, logged):
    """Admit all variants, then configure only the original app target once."""
    root, out = Path(root), Path(out)
    routes = load(root)
    transport = stage(root, routes)
    restore(root, routes, out)
    api = sdk_api(root)
    admitted, plans, receipts = {}, {}, {}
    for name, route in routes['routes'].items():
        admitted[name] = api['prepare'](root, route['admission_path'], report, out, logged,
                                      variant=name, apply_project=False)
        directory = out / ('original-editor' if name == 'debug-simulator' else 'original-editor-' + name)
        path = directory / 'distribution-admission.json'
        plans[name] = json.loads((directory / 'app-target-plan.json').read_bytes())
        receipts[name] = {'configuration': route['configuration'], 'platform': route['platform'],
                          'path': path.relative_to(root).as_posix(), 'sha256': digest(path),
                          'evidence': directory.relative_to(root).as_posix(),
                          'admission_path': route['admission_path'], 'admission_sha256': route['admission_sha256']}
    require(len({p['before_project_sha256'] for p in plans.values()}) == 1,
            'Generated app project changed between variant admissions')
    receipt = {'schema': 'otzaria.original-editor.admitted-build-routes/1',
               'manifest_path': routes['manifest_path'], 'manifest_sha256': routes['manifest_sha256'],
               'sdk_source_sha': routes['sdk_source_sha'], 'native_source_tree': routes['native_source_tree'],
               'signing_team_id': routes['signing_team_id'], 'routes': receipts}
    route_path = out / 'original-editor-routes.json'
    api['write'](route_path, receipt)
    plan = plans['debug-simulator']
    plan['release_variants'] = {name: plans[name] for name in ('release-simulator', 'release-device')}
    plan['build_routes'] = {'path': route_path.relative_to(root).as_posix(), 'sha256': digest(route_path)}
    api['configure'](root, plan, report, out / 'original-editor', logged)
    report['original_editor_distribution'] = admitted['debug-simulator']
    report['original_editor_routes'] = {**plan['build_routes'], 'manifest_sha256': routes['manifest_sha256'],
                                       'sdk_source_sha': routes['sdk_source_sha'],
                                       'native_source_tree': routes['native_source_tree'], 'transport': transport}
    return admitted['debug-simulator']


def admitted_route(root, route_path, route_sha256, configuration, platform):
    root = Path(root)
    path = owned(root, route_path, 'build/')
    require(re.fullmatch(r'[a-f0-9]{64}', route_sha256) and digest(path) == route_sha256,
            'Generated original SDK route receipt changed')
    receipt = json.loads(path.read_bytes())
    routes = load(root)
    require(receipt.get('schema') == 'otzaria.original-editor.admitted-build-routes/1'
            and receipt.get('manifest_path') == routes['manifest_path']
            and receipt.get('manifest_sha256') == routes['manifest_sha256']
            and receipt.get('sdk_source_sha') == routes['sdk_source_sha']
            and receipt.get('native_source_tree') == routes['native_source_tree']
            and receipt.get('signing_team_id') == routes['signing_team_id']
            and set(receipt.get('routes', {})) == set(VARIANTS), 'SDK admission routes differ from committed source')
    selected = select(routes, configuration, platform)
    name = next(key for key, pair in VARIANTS.items() if pair == (configuration, platform))
    row = receipt['routes'][name]
    require(row['admission_path'] == selected['admission_path']
            and row['admission_sha256'] == selected['admission_sha256']
            and (row['configuration'], row['platform']) == (configuration, platform),
            'Selected app route points to another SDK variant')
    admission_path = owned(root, row['path'], 'build/')
    require(digest(admission_path) == row['sha256'], 'Actual SDK admission bytes changed')
    admitted = json.loads(admission_path.read_bytes())
    require(admitted.get('admission_path') == row['admission_path']
            and admitted.get('admission_sha256') == row['admission_sha256']
            and admitted.get('source_sha') == routes['sdk_source_sha'],
            'SDK consumer receipt does not bind the selected committed input')
    return row, admitted


def embed(root, route_path, route_sha256, target):
    import os
    configuration, platform = os.environ.get('CONFIGURATION'), os.environ.get('PLATFORM_NAME')
    row, admitted = admitted_route(root, route_path, route_sha256, configuration, platform)
    if platform == 'iphoneos':
        module = runpy.run_path(str(Path(root) / 'Scripts/CI/original_editor_device_signature.py'))
        return module['embed'](root, Path(root) / row['path'], row['sha256'], target, Path(root) / row['evidence'])
    return sdk_api(root)['embed'](root, Path(root) / row['path'], row['sha256'], target, Path(root) / row['evidence'])


def verify(root, route_path, configuration, platform, app, *, route_sha256, after_ui=False, after_archive=False):
    row, admitted = admitted_route(root, route_path, route_sha256, configuration, platform)
    if platform == 'iphoneos':
        require(not after_ui, 'Device compiler/archive verification cannot claim a Simulator UI phase')
        module = runpy.run_path(str(Path(root) / 'Scripts/CI/original_editor_device_signature.py'))
        verified = module['verify'](root, Path(root) / row['path'], row['sha256'], app, Path(root) / row['evidence'],
                                    expected_team=admitted['signing_team_id'], after_archive=after_archive)
        directory = Path(root) / row['evidence'] / ('device-archive' if after_archive else 'device-build')
        directory.mkdir(parents=True, exist_ok=True)
        api = sdk_api(root)
        shared = runpy.run_path(str(Path(root) / 'Scripts/CI/original_editor_shared_runtime.py'))
        shared['verify_app_ownership'](Path(root), admitted, Path(app), directory, api['command'],
            host_library_files=verified['host_build_products']['host_libraries'])
        policy = admitted['shared_package_policy']
        if policy['swift_syntax_requires_actual_runtime_absence']:
            api['verify_absence_receipt'](Path(root), Path(root) / admitted['distribution_root'],
                                         policy['producer_runtime_absence'])
            proof = api['runtime_absence_proof'](Path(root), Path(app), directory / 'swift-syntax-app')
            api['write'](directory / 'swift-syntax-runtime-absence.json', {
                'status': 'EXACT_REVIEWED_BUILD_TOOL_PAIR_WITH_ACTUAL_RUNTIME_ABSENCE',
                'sdk': policy['producer_runtime_absence'], 'app': proof, 'device_runtime': 'NOT_RUN'})
    else:
        require(not after_archive, 'Simulator route cannot grant device archive verification')
        sdk_api(root)['verify_built_app'](root, admitted, app, Path(root) / row['evidence'], after_ui=after_ui)
    return {'status': 'ACTUAL_BUILT_APP_SDK_ROUTE_VERIFIED', 'configuration': configuration, 'platform': platform,
            'sdk_source_sha': admitted['source_sha'], 'admission_sha256': admitted['admission_sha256'],
            'after_ui': after_ui, 'after_archive': after_archive, 'native_editor_ui_credit': False}


def verify_rehydrated_context(root, original, restored, restored_evidence):
    """Compare real job preparations while preserving their distinct process IDs."""
    root, restored_evidence = Path(root), Path(restored_evidence)
    a, b = original['native_context'], restored['native_context']
    varying = {'original_editor_pod_ruby_context', 'pre_original_editor_project_sha256', 'generated_project_sha256'}
    require(a.keys() == b.keys() and {k: v for k, v in a.items() if k not in varying}
            == {k: v for k, v in b.items() if k not in varying}, 'Restored original native preparation differs')
    require(a['pre_original_editor_project_sha256'] == b['pre_original_editor_project_sha256'],
            'Original pre-SDK Pod project differs between actual jobs')
    records = []
    for report, directory in ((original, root / 'build/hq-stage2'), (restored, restored_evidence)):
        proof = report['native_context']['original_editor_pod_ruby_context']
        receipt_path = directory / 'original-editor/pod-ruby-context.json'
        request_path = directory / 'original-editor/pod-ruby-request.json'
        require(digest(receipt_path) == proof['receipt_sha256'] and digest(request_path) == proof['request_sha256']
                and proof['command'] == ['pod', 'install'] and proof['returncode'] == 0,
                'Original job-specific Ruby context receipt changed')
        value, request = json.loads(receipt_path.read_bytes()), json.loads(request_path.read_bytes())
        require(value['nonce'] == request['nonce'] and value['parent_pid'] == request['parent_pid']
                and value['original_exit_code'] == 0 and value['argv'] == ['install'],
                'Original Pod process binding differs')
        checkout = str(Path(value['observer']['path']).parents[2])
        def portable(item):
            if isinstance(item, dict):
                return {k: portable(v) for k, v in item.items()}
            if isinstance(item, list):
                return [portable(v) for v in item]
            if isinstance(item, str) and item.startswith(checkout + '/'):
                return '$CHECKOUT/' + item[len(checkout) + 1:]
            return item
        records.append(portable({k: v for k, v in value.items() if k not in {'nonce', 'pid', 'parent_pid'}}))
        project = json.loads((directory / 'original-editor/app-target-configuration.json').read_bytes())
        require(project['before_project_sha256'] == a['pre_original_editor_project_sha256']
                and project['after_project_sha256'] == report['native_context']['generated_project_sha256']
                and project['all_other_objects_unchanged'] is True and project['whole_project_inverse_exact'] is True
                and project['release_platforms'] == ['iphoneos', 'iphonesimulator'],
                'A restored app-target SDK projection was not independently verified')
        manifest = report['original_editor_routes']
        route_path = directory / 'original-editor-routes.json'
        require(digest(route_path) == manifest['sha256'] and manifest['manifest_sha256'] == load(root)['manifest_sha256'],
                'An original job admitted different committed SDK routes')
    require(records[0] == records[1], 'Ruby/compiler-project implementation differs between original jobs')
    require({k: original['original_editor_routes'][k] for k in ('manifest_sha256', 'sdk_source_sha', 'native_source_tree')}
            == {k: restored['original_editor_routes'][k] for k in ('manifest_sha256', 'sdk_source_sha', 'native_source_tree')},
            'Release restoration selected another SDK or Heart source')
    return {'status': 'EXACT_ORIGINAL_SOURCES_AND_SDK_WITH_DISTINCT_POD_EXECUTIONS',
            'old_project_sha256': a['generated_project_sha256'], 'new_project_sha256': b['generated_project_sha256'],
            'old_ruby_receipt_sha256': a['original_editor_pod_ruby_context']['receipt_sha256'],
            'new_ruby_receipt_sha256': b['original_editor_pod_ruby_context']['receipt_sha256']}
