"""Admit the actual Release SDK and preserve its separate ABI producer identity."""
import json
from pathlib import Path
import re
import uuid

from original_editor_local_admission import restore_archive, validate_abi_adapter, validate_public_contract

INPUT_SCHEMA = 'otzaria.original-editor.production-input/1'
ADMISSION_SCHEMA = 'otzaria.original-editor.production-admission/1'
REPOSITORY = 'davidpovarsky/anytype-swift'
SIMULATOR_PASS = 'ACTUAL_ORIGINAL_FRAMEWORK_EXTERNAL_IMPORT_LINK_RESOURCES_PASS'
DEVICE_PASS = 'ACTUAL_ORIGINAL_RELEASE_DEVICE_BUILD_LINK_API_PLATFORM_PASS'
ROLES = {'execution', 'source_before', 'source_after', 'abi', 'abi_source_before', 'abi_execution'}


def require(value, message):
    if not value:
        raise RuntimeError(message)


def validate_configuration(config):
    require(config.get('schema') == INPUT_SCHEMA and config.get('producer_kind') == 'local-mac'
            and config.get('repository') == REPOSITORY and config.get('configuration') == 'Release'
            and config.get('platform') in {'iphoneos', 'iphonesimulator'}
            and config.get('architectures') == ['arm64'], 'Wrong original Release SDK contract')
    identity = config.get('run_id', '')
    require(isinstance(identity, str) and identity.startswith('local-')
            and str(uuid.UUID(identity[6:])) == identity[6:]
            and type(config.get('run_attempt')) is int and config['run_attempt'] == 1,
            'Release SDK must retain its genuine local execution UUID')
    require(not ({'artifact_id', 'job_id', 'repository_id', 'workflow_path', 'framework_artifact',
                  'evidence_artifact', 'runtime_qualification_producer'} & set(config)),
            'A local Release producer cannot borrow GitHub identities')
    for name in ('source_sha', 'control_sha', 'native_source_tree'):
        require(re.fullmatch(r'[a-f0-9]{40}', config.get(name, '')), 'Unfinalized Release source: ' + name)
    for name in ('archive_sha256', 'distribution_manifest_sha256', 'qualification_sha256',
                 'original_source_sha256', 'hanlin_source_sha256', 'local_execution_sha256'):
        require(re.fullmatch(r'[a-f0-9]{64}', config.get(name, '')), 'Unfinalized Release digest: ' + name)
    require(type(config.get('archive_bytes')) is int and config['archive_bytes'] > 0,
            'Release archive size is absent')
    rows = config.get('local_receipts', {})
    require(set(rows) == ROLES, 'Release execution and original ABI provenance are incomplete')
    for name, row in rows.items():
        require(set(row) == {'path', 'bytes', 'sha256'} and type(row['bytes']) is int and row['bytes'] > 0
                and re.fullmatch(r'[a-f0-9]{64}', row['sha256'])
                and isinstance(row['path'], str) and row['path'].startswith('build/'),
                'Invalid Release receipt: ' + name)
    require(rows['execution']['sha256'] == config['local_execution_sha256'],
            'Release descriptor digest aliases differ')
    if config['platform'] == 'iphoneos':
        require(re.fullmatch(r'[A-Z0-9]{10}', config.get('signing_team_id', '')),
                'Device distribution lacks its reviewed app signing team')


def read_receipts(root, config, api):
    validate_configuration(config)
    result = {}
    for name, row in config['local_receipts'].items():
        path = api['owned_path'](root, row['path'], build=True)
        require(path.is_file() and path.stat().st_size == row['bytes']
                and api['digest'](path) == row['sha256'], 'Release receipt bytes differ: ' + name)
        result[name] = api['read_json'](path)
    return result


def validate_provenance(root, config, qualification, api):
    values = read_receipts(root, config, api)
    contract = validate_public_contract(config, values['source_before'], api)
    execution = values['execution']
    require(execution.get('schema') == 'otzaria.original-editor.release-execution/1'
            and execution.get('repository') == REPOSITORY
            and execution.get('execution_id') == config['run_id']
            and execution.get('source_sha') == config['source_sha']
            and execution.get('control_sha') == config['control_sha']
            and execution.get('configuration') == 'Release-Anytype'
            and execution.get('platform') == config['platform']
            and re.fullmatch(r'[a-f0-9]{40}', execution.get('source_tree', ''))
            and execution.get('root') and execution.get('control_root')
            and execution.get('host', {}).get('system') == 'Darwin'
            and execution.get('host', {}).get('architecture') == 'arm64'
            and execution['host'].get('hostname')
            and execution.get('acceptance') == 'PROVENANCE_ONLY_NOT_ACCEPTANCE',
            'Actual external Release controller/source identity differs')
    identity = qualification.get('execution_identity', {})
    require(identity.get('producer_kind') == 'local-mac'
            and identity.get('source_sha') == config['source_sha']
            and identity.get('run_id') == config['run_id'] and identity.get('run_attempt') == '1'
            and identity.get('local_execution_sha256') == config['local_execution_sha256']
            and identity.get('local_execution') == execution,
            'Release compiler qualification is not bound to its actual new execution')
    before, after = values['source_before'], values['source_after']
    original, abi = values['abi_execution'], values['abi']
    require(before == after and before.get('head_sha') == config['source_sha']
            and before.get('status') == 'SOURCE_BOUND_FRAMEWORK_RUNTIME_NOT_RUN',
            'Actual SDK product/source inputs changed during Release execution')
    abi_before = values['abi_source_before']
    original_identity = abi_before.get('execution_identity', {})
    require(original.get('schema') == 'otzaria.original-editor.local-execution/1'
            and original.get('source_sha') == config['source_sha']
            and original.get('source_tree') == execution['source_tree']
            and abi_before.get('head_sha') == config['source_sha']
            and original_identity.get('local_execution') == original
            and original_identity.get('local_execution_sha256') == config['local_receipts']['abi_execution']['sha256']
            and original_identity.get('run_id') == original['execution_id']
            and original_identity.get('source_sha') == config['source_sha']
            and before.get('execution_identity') == original_identity,
            'Release changed the original ABI source or execution provenance')
    # All source facts remain identical. The current-build compiler context is
    # separately named by the producer, never substituted into these receipts.
    require(before == abi_before, 'Release compiled a different SDK source closure than the admitted ABI owner')
    validate_abi_adapter(abi, qualification.get('heart', {}), config['source_sha'])
    require(abi.get('status') == 'PASS' and abi.get('producer_kind') == 'local-mac'
            and abi.get('sdk_source_sha') == config['source_sha']
            and abi.get('local_execution_sha256') == original_identity['local_execution_sha256']
            and abi.get('native_qualification', {}).get('native_source_tree') == config['native_source_tree']
            and abi.get('full_sdk_accepted') is False and abi.get('editor_ui_accepted') is False
            and abi.get('owned_command_groups_drained') is True
            and qualification.get('heart', {}).get('receipt_sha256') == config['local_receipts']['abi']['sha256']
            and qualification['heart'].get('native_qualification') == abi.get('native_qualification')
            and abi.get('native_qualification', {}).get('status') == 'PASS',
            'Release does not consume the unchanged qualified original Import ABI')
    expected = SIMULATOR_PASS if config['platform'] == 'iphonesimulator' else DEVICE_PASS
    require(qualification.get('status') == expected and qualification.get('phase') == 'COMPLETE'
            and qualification.get('source_sha') == config['source_sha']
            and qualification.get('configuration') == 'Release-Anytype'
            and qualification.get('platform') == config['platform']
            and qualification.get('original_framework_build') == 'PASS'
            and qualification.get('external_consumer_build') == 'PASS'
            and qualification.get('same_toolchain_only') is True
            and qualification.get('native_editor_ui_tests') == 0,
            'Release framework/compiler qualification is incomplete')
    observations = qualification.get('verified_runtime_observations', [])
    if config['platform'] == 'iphonesimulator':
        require(len(observations) == 2 and {v.get('language') for v in observations} == {'en', 'he'}
                and all(v.get('status') == 'ACTUAL_IMPORT_LINK_RESOURCE_RUNTIME_PASS' for v in observations),
                'Release Simulator resource observations did not both execute')
    else:
        require(observations == [] and qualification.get('device_runtime') == 'NOT_RUN',
                'A device compiler result cannot claim physical-device execution')
    return {'producer_kind': 'local-mac', 'local_execution_sha256': config['local_execution_sha256'],
            'local_receipts': config['local_receipts'], 'control_sha': config['control_sha'],
            'native_source_tree': config['native_source_tree'], 'configuration': 'Release',
            'platform': config['platform'], 'architectures': ['arm64'],
            'qualification_sha256': config['qualification_sha256'],
            'signing_team_id': config.get('signing_team_id'), 'native_stageb_qualified': False,
            **({'public_host_contract_sha256': contract} if contract else {})}


def restore(root, config, evidence, api, zip_members):
    read_receipts(root, config, api)
    destination, expected = restore_archive(root, config, api, zip_members)
    proof = validate_provenance(root, config, api['read_json'](destination / 'QUALIFICATION.json'), api)
    api['write'](Path(evidence) / 'restoration.json', {
        'status': 'EXACT_LOCAL_RELEASE_SDK_ARCHIVE_RESTORED', 'producer': proof,
        'files': len(expected), 'source_sha': config['source_sha'], 'run_id': config['run_id'],
        'native_editor_ui_tests': 0, 'overwritten_inputs': 0})
