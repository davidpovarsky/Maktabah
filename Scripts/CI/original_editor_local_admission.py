"""Transport and provenance for a genuinely qualified dedicated-Mac SDK.

This is the local producer variant of the complete shared-runtime contract.
The original binary, API, English/Hebrew, resource and ownership gates remain in
hq-original-editor-distribution.py. No GitHub run/artifact ID is manufactured.
"""
import json
from pathlib import Path
import re
import shutil
import stat
import uuid
import zipfile

REPOSITORY = 'davidpovarsky/anytype-swift'
QUALIFIED = 'ACTUAL_ORIGINAL_FRAMEWORK_EXTERNAL_IMPORT_LINK_RESOURCES_PASS'
ROLES = {'execution', 'source_before', 'source_after', 'abi'}
DONOR_SCHEMA = 'otzaria.original-import-donor-sdk-input/1'
DONOR_SOURCE = '34b8a7c5ddb34e9287acdb5c189849eeac8cff86'
DONOR_POLICY = 'Tools/OriginalEditor/AnnotationExchange/abi_donor_policy.json'
DONOR_ROLES = {'abi_donor_policy', 'abi_donor_execution', 'abi_donor_source_before',
               'abi_donor_abi', 'abi_donor_debug_qualification', 'abi_donor_pinned_wrapper'}
DONOR_INPUTS = {'Anytype/Sources', 'Anytype/Resources', 'Modules', 'Dependencies/Middleware',
                'Tools/OriginalEditor/ABIPinnedWrapper', 'Tools/OriginalEditor/GeneratedImport',
                'Tools/PinkhaNativeDerived', 'Tools/OriginalEditor/build_local_import_abi.py'}
MINIAPPS_CONTRACT = 'b8a02497aeabab316d85daf2dab5045b1d94dac98a14b7ccc89a3b7c9a6509c0'
FILES_MINIAPPS_CONTRACT = '6ba6e80fad98cbcf967df2866134369df3310b0b231dd462cb0a4c2e71f44141'


# A second reviewed donor preserves the genuinely regenerated schema3 ABI.
# It is distinct from the historical 34b input and cannot inherit its identity.
FILES_DONOR_SOURCE = '1f90175b006be0a19a4e1804f858caaf59d6c174'
FILES_DONOR_POLICY = 'Tools/OriginalEditor/MiniApps/abi_donor_1f90175b.json'
FILES_DONOR_POLICY_SHA256 = 'b9053998299a484604e1ae2d9bc7c4a52afa6df1ccd58b07b4e3cb9ccfb553e6'
FILES_DONOR_VERIFIER = 'Tools/OriginalEditor/donor_abi_input.py'
FILES_DONOR_VERIFIER_SHA256 = 'a3f9cb16256a7adefd01cf139c1a850990d2ad668c99405cc20667cf91fab7ef'
FILES_DONOR_INPUTS = DONOR_INPUTS | {
    'OriginalEditorFramework', 'Tools/OriginalEditor/ImportRPC',
    'Tools/OriginalEditor/NativeRegeneration', 'Tools/OriginalEditor/fresh_swift_input.py',
    'Tools/OriginalEditor/reused_abi_history.py', 'Tools/OriginalEditor/import_abi_input.py'}
FILES_DONOR_ROLES = {'abi_donor_generation_qualification', 'abi_donor_changed_swift_qualification',
                    'abi_donor_final_native_rpc_union', 'abi_donor_fresh_verification'}


def donor_policy_scope(source=None):
    source = DONOR_SOURCE if source is None else source
    require(source in (DONOR_SOURCE, FILES_DONOR_SOURCE), 'Unreviewed original native ABI donor source')
    fresh = source == FILES_DONOR_SOURCE
    return {
        'source': source,
        'path': FILES_DONOR_POLICY if fresh else DONOR_POLICY,
        'schema': 'otzaria.native-abi-donor-policy/2' if fresh else 'otzaria.native-abi-donor-policy/1',
        'inputs': FILES_DONOR_INPUTS if fresh else DONOR_INPUTS,
        'extra_roles': FILES_DONOR_ROLES if fresh else set(),
        'donor_branch': ('codex/anytype-original-miniapps-facade-20261125' if fresh else
                         'codex/otzaria-local-annotation-sdk-20261124'),
        'current_branch': ('codex/anytype-original-sdk-collections13-20261125' if fresh else
                           'codex/anytype-original-miniapps-facade-20261125'),
    }


FRESH_SCHEMA = 'otzaria.original-import-local-sdk-input/3'
FRESH_ROLES = {'abi_generation_qualification', 'abi_changed_swift_qualification',
               'abi_final_native_rpc_union', 'abi_pinned_wrapper', 'abi_fresh_verification'}
FRESH_VERIFIERS = {
    'Tools/OriginalEditor/import_abi_input.py':
        '0cf0497de8847bc522880dd3ccd84e974770a56732ca99485574975422242f03',
    'Tools/OriginalEditor/fresh_swift_input.py':
        'edd9146acfb35f3b190eab88412c30b695f3befeeae5098bf8db421d8e9a1a28',
    'Tools/OriginalEditor/ABIPinnedWrapper/pinned_wrapper.py':
        '178262cdfd5d8b07fb0d8915bb394150ef8988de5fe2115f02bac735f6c65289',
}


def validate_fresh_abi(values, config, heart, before):
    """Retain the new original native/Swift producers without rewriting history."""
    abi, rows = values['abi'], config['local_receipts']
    require(config.get('abi_provenance') == FRESH_SCHEMA
            and config.get('public_host_contract_sha256') == FILES_MINIAPPS_CONTRACT
            and abi.get('schema') == heart.get('schema') == FRESH_SCHEMA,
            'Fresh original ABI requires its explicit complete files contract')
    observation = values['abi_fresh_verification']
    require(observation.get('schema') == 'otzaria.current-original-abi-verification/1'
            and observation.get('status') == 'CURRENT_ORIGINAL_ABI_VERIFIER_PASS'
            and observation.get('returncode') == 0
            and observation.get('producer_source_sha') == config['source_sha']
            and observation.get('source_observation_sha256') == rows['source_before']['sha256']
            and observation.get('abi_sha256') == rows['abi']['sha256']
            and observation.get('verifier_sources') == FRESH_VERIFIERS
            and observation.get('observed_heart') == heart
            and observation.get('new_native_tests') == 0
            and observation.get('new_sdk_or_ui_credit') is False
            and observation.get('source_unchanged') is True
            and all(before.get('source_inputs', {}).get(name, {}).get('sha256') == digest
                    for name, digest in FRESH_VERIFIERS.items()),
            'Fresh original ABI was not reverified by its exact qualified source')
    require(set(abi.get('qualification_receipts', {})) == {
                'generation_qualification', 'changed_swift_qualification', 'final_native_rpc_union'},
            'Fresh generation, Swift and native origins are incomplete')
    for name, reference in abi['qualification_receipts'].items():
        row = rows['abi_' + name]
        require(reference.get('sha256') == row['sha256'] and reference.get('bytes') == row['bytes'],
                'Fresh original qualification receipt differs: ' + name)
    generation = values['abi_generation_qualification']
    swift = values['abi_changed_swift_qualification']
    native = values['abi_final_native_rpc_union']
    require(generation.get('status') == 'PASS'
            and generation.get('aggregate_producer_outcome') == 'FAIL'
            and generation.get('output_counts') == {'native': 11, 'swift': 696, 'middleware': 37}
            and generation.get('generators_replayed_by_abi') == 0
            and generation.get('source_receipt_sha256')
                == 'd7e1074b46a52d7d559304045110da3e13b40630208520566ff840bf12c357e7',
            'Fresh ABI transport cannot replace the original failed generation history')
    swift_execution = swift.get('local_execution', {})
    require(swift.get('status') == 'PASS' and swift.get('execution_origin') == 'local-mac'
            and swift.get('github_run_id') is None
            and swift.get('primary_count') == 2 and swift.get('input_files') == 689
            and swift.get('typecheck_invocations') == 1
            and swift.get('generated_index_sha256') == generation.get('generated_index_sha256')
            and swift.get('generation_replayed') is False and swift.get('full_sdk_typechecked') is False
            and swift.get('historical_missing_receipts_replaced') is False
            and swift.get('owned_command_groups_drained') is True
            and swift.get('original_control_source') == 'fc4a84f68d26bcf36a8662367d08475b4024824a'
            and swift.get('local_execution_sha256')
                == '73ee9eecbf04882d4cb8803adf838ae8bd7a157dbada5bda65c4589d7e74f28e'
            and swift_execution.get('execution_id') == 'local-580a9308-fd9a-4dc7-a2a5-aab8e73205a2'
            and swift_execution.get('control_head') == swift['original_control_source']
            and swift_execution.get('execution_origin') == 'local-mac'
            and swift_execution.get('github_run_id') is None
            and swift.get('source_receipt_sha256')
                == '207aaabf0840383ad19453ab68e34ebc9c892f1aa0f8cae962dae23023894e5f'
            and swift.get('raw_evidence_index_sha256')
                == 'c51e53500db9ac57ccde6643f9f812f958f5e443616bfd1614d4212e98b9cf32',
            'Fresh Swift origin or bounded original execution scope differs')
    counts = {'native9': 9, 'rpc9': 9, 'cancel_panic': 1, 'bundled_semantic': 6,
              'schema_closure': 11, 'relation_target_closure': 12,
              'imported_creation_date': 6, 'bounded_native_metadata': 12}
    require(native == abi.get('native_qualification') == heart.get('native_qualification')
            and native.get('schema') == 'otzaria.fresh-native-rpc-union-qualification/1'
            and native.get('status') == 'PASS' and native.get('execution_origin') == 'local-mac'
            and native.get('github_run_id') is None
            and native.get('original_control_source') == native.get('source_sha')
                == 'c7e9935eb36a47f73d04cf72ea45472d3f2a8a70'
            and native.get('native_source_tree') == config['native_source_tree']
            and native.get('counts') == {name: {'passes': count, 'failures': 0, 'skipped': 0, 'not_run': 0}
                                        for name, count in counts.items()}
            and all(type(value) is int for group in native.get('counts', {}).values() for value in group.values())
            and native.get('source_module_link_stability') == 'PASS'
            and native.get('owned_command_groups_drained') is True
            and native.get('historical_missing_receipts_replaced') is False
            and native.get('full_sdk_accepted') is False and native.get('editor_ui_accepted') is False,
            'Fresh native66 origin, count or source scope differs')
    wrapper, reference, proof = values['abi_pinned_wrapper'], abi['pinned_wrapper'], heart['pinned_wrapper']
    require(rows['abi_pinned_wrapper']['sha256'] == reference['sha256']
            and rows['abi_pinned_wrapper']['bytes'] == reference['bytes']
            and all(wrapper.get(key) == value for key, value in proof.items()
                    if key not in {'receipt_sha256', 'targets'})
            and [row.get('target') for row in wrapper.get('targets', [])] == proof['targets'],
            'Fresh original three-target wrapper receipt differs')
    require(abi.get('generated_files_verified') == heart.get('generated_files_verified') == 733
            and abi.get('generated_files_written') == heart.get('generated_files_written') == 0
            and abi.get('generators_replayed') == 0 and abi.get('source_unchanged_after_bind') is True
            and abi.get('verified_architectures') == {'ios': ['arm64'], 'ios-simulator': ['arm64', 'x86_64']}
            and abi.get('lib_files') == heart.get('lib_files') and len(abi.get('lib_files', [])) == 17,
            'Fresh original generated source or installed native ABI closure differs')
    return {'schema': FRESH_SCHEMA, 'native_control_source': native['source_sha'],
            'changed_swift_control_source': swift['original_control_source'],
            'changed_swift_local_execution_sha256': swift['local_execution_sha256'],
            'native_tests_rerun_by_transport': False, 'new_sdk_or_ui_credit': False,
            'scope': 'EXACT_FRESH_ORIGINAL_NATIVE_SWIFT_ABI_PROVENANCE_ONLY'}


def require(value, reason):
    if not value:
        raise RuntimeError(reason)


def validate_configuration(config):
    require(config.get('schema') == 3 and config.get('producer_kind') == 'local-mac'
            and config.get('repository') == REPOSITORY,
            'Local SDK requires the complete shared-runtime contract')
    execution = config.get('run_id', '')
    require(isinstance(execution, str) and execution.startswith('local-')
            and str(uuid.UUID(execution[6:])) == execution[6:]
            and type(config.get('run_attempt')) is int and config['run_attempt'] == 1,
            'Local SDK execution must have its own canonical UUID')
    require(not ({'artifact_id', 'job_id', 'repository_id', 'workflow_path',
                  'framework_artifact', 'evidence_artifact', 'runtime_qualification_producer'} & set(config)),
            'Local provenance must not borrow GitHub run or artifact identities')
    require(re.fullmatch(r'[0-9a-f]{40}', config.get('source_sha', ''))
            and type(config.get('archive_bytes')) is int and config['archive_bytes'] > 0,
            'Local SDK source/archive identity is incomplete')
    for name in ('archive_sha256', 'distribution_manifest_sha256', 'qualification_sha256',
                 'original_source_sha256', 'hanlin_source_sha256', 'local_execution_sha256'):
        require(re.fullmatch(r'[0-9a-f]{64}', config.get(name, '')), 'Missing local SDK digest: ' + name)
    rows = config.get('local_receipts', {})
    provenance = config.get('abi_provenance')
    require(provenance in (None, DONOR_SCHEMA, FRESH_SCHEMA), 'Unsupported local ABI provenance route')
    require(provenance == DONOR_SCHEMA or 'abi_donor_source_sha' not in config,
            'A native donor identity requires the explicit donor provenance route')
    scope = donor_policy_scope(config.get('abi_donor_source_sha')) if provenance == DONOR_SCHEMA else None
    roles = ROLES | (DONOR_ROLES | scope['extra_roles'] if scope else
                     FRESH_ROLES if provenance == FRESH_SCHEMA else set())
    require(set(rows) == roles, 'Local SDK source/ABI evidence closure is incomplete')
    for role, row in rows.items():
        require(set(row) == {'path', 'bytes', 'sha256'} and type(row['bytes']) is int and row['bytes'] > 0
                and re.fullmatch(r'[0-9a-f]{64}', row['sha256'])
                and isinstance(row['path'], str) and row['path'].startswith('build/'),
                'Malformed local source/ABI receipt: ' + role)
    require(rows['execution']['sha256'] == config['local_execution_sha256'],
            'Local execution descriptor aliases disagree')


def read_receipts(root, config, api):
    validate_configuration(config)
    values = {}
    for role, row in config['local_receipts'].items():
        path = api['owned_path'](root, row['path'], build=True)
        require(path.is_file() and not path.is_symlink() and path.stat().st_size == row['bytes']
                and api['digest'](path) == row['sha256'], 'Local SDK receipt bytes differ: ' + role)
        values[role] = api['read_json'](path)
    return values


def validate_abi_adapter(abi, heart, source_sha):
    """Keep the new audited compiler adapter explicit in downstream provenance."""
    schema = abi.get('schema')
    if schema == 'otzaria.original-import-local-sdk-input/1':
        require('pinned_wrapper' not in abi and 'pinned_wrapper' not in heart,
                'Historical ABI provenance cannot silently admit a wrapper adapter')
        return
    require(schema in ('otzaria.original-import-local-sdk-input/2', FRESH_SCHEMA)
            and heart.get('schema') == schema, 'Unsupported original Import ABI schema')
    reference, proof = abi.get('pinned_wrapper', {}), heart.get('pinned_wrapper', {})
    require(set(reference) == {'path', 'bytes', 'sha256'}
            and reference['path'] == 'pinned-wrapper/RESULT.json'
            and type(reference['bytes']) is int and reference['bytes'] > 0
            and re.fullmatch(r'[a-f0-9]{64}', reference['sha256'])
            and proof.get('schema') == 'otzaria.gomobile-pinned-wrapper-observation/1'
            and proof.get('status') == 'THREE_ACTUAL_PINNED_WRAPPERS_PASS'
            and proof.get('control_sha') == source_sha
            and proof.get('receipt_sha256') == reference['sha256']
            and proof.get('targets') == ['ios-arm64', 'iossimulator-arm64', 'iossimulator-amd64']
            and proof.get('original_go_sum_preserved') is True
            and proof.get('all_targets_admitted_before_compile') is True
            and proof.get('original_gomobile_modified') is False
            and proof.get('rejected_archives_reused') is False,
            'Qualified SDK omits the exact complete pinned-wrapper ABI proof')


def validate_public_contract(config, source_before, api):
    contract = config.get('public_host_contract_sha256')
    reviewed = api['REVIEWED_PUBLIC_HOST_CONTRACTS']
    if contract is None:
        require(source_before.get('public_host_contract_sha256') not in reviewed,
                'Local annotation source requires its exact committed public contract')
        return None
    require(contract in reviewed and source_before.get('public_host_contract_sha256') == contract,
            'Public contract differs from the actual producer source observation')
    return contract


def validate_donor_abi(values, config, heart, before):
    """Transport the original ABI chain without assigning it the new SDK identity."""
    reference, policy = values['abi'], values['abi_donor_policy']
    rows = config['local_receipts']
    scope = donor_policy_scope(config.get('abi_donor_source_sha'))
    donor_source = scope['source']
    fresh_donor = donor_source == FILES_DONOR_SOURCE
    require(set(reference) == {'schema', 'status', 'consumer_source_sha',
                'consumer_local_execution_sha256', 'policy_sha256', 'donor_root',
                'new_sdk_acceptance_granted'}
            and reference.get('schema') == DONOR_SCHEMA
            and reference.get('status') == 'EVIDENCE_REFERENCE_ONLY_REQUIRES_VERIFICATION'
            and reference.get('consumer_source_sha') == config['source_sha']
            and reference.get('consumer_local_execution_sha256') == config['local_execution_sha256']
            and reference.get('policy_sha256') == rows['abi_donor_policy']['sha256']
            and reference.get('new_sdk_acceptance_granted') is False,
            'Donor reference was relabelled or belongs to another SDK execution')
    donor_root = reference.get('donor_root', '')
    require(isinstance(donor_root, str) and Path(donor_root).is_absolute()
            and '..' not in Path(donor_root).parts,
            'Original donor path is not an absolute provenance identity')
    policy_receipts = policy.get('receipts', {})
    policy_fields = {'schema', 'source_sha', 'unchanged_git_inputs', 'receipts',
                     'native_tests_rerun', 'new_sdk_acceptance_granted'}
    if fresh_donor:
        policy_fields.add('reason')
        require(config.get('public_host_contract_sha256') == FILES_MINIAPPS_CONTRACT
                and rows['abi_donor_policy']['sha256'] == FILES_DONOR_POLICY_SHA256
                and before.get('source_inputs', {}).get(FILES_DONOR_VERIFIER, {}).get('sha256')
                    == FILES_DONOR_VERIFIER_SHA256,
                'Fresh donor requires its exact reviewed policy, verifier and complete files contract')
    require(set(policy) == policy_fields
            and policy.get('schema') == scope['schema']
            and policy.get('source_sha') == donor_source
            and set(policy.get('unchanged_git_inputs', {})) == scope['inputs']
            and all(re.fullmatch(r'[0-9a-f]{40}', value)
                    for value in policy['unchanged_git_inputs'].values())
            and set(policy_receipts) == {'execution', 'source_before', 'abi', 'debug_qualification'}
            and policy.get('native_tests_rerun') is False
            and policy.get('new_sdk_acceptance_granted') is False
            and before.get('source_inputs', {}).get(scope['path'], {}).get('sha256')
                == rows['abi_donor_policy']['sha256'],
            'Original native ABI donor policy is not bound to the current source')
    for role, row in policy_receipts.items():
        require(set(row) == ({'path', 'sha256', 'bytes'} if fresh_donor else {'path', 'sha256'})
                and isinstance(row['path'], str)
                and row['path'].startswith('build/') and '..' not in Path(row['path']).parts
                and row['sha256'] == rows['abi_donor_' + role]['sha256']
                and (not fresh_donor or row['bytes'] == rows['abi_donor_' + role]['bytes']),
                'Original donor receipt differs from the committed policy: ' + role)

    donor_execution = values['abi_donor_execution']
    donor_before = values['abi_donor_source_before']
    donor_abi = values['abi_donor_abi']
    donor_qualification = values['abi_donor_debug_qualification']
    donor_identity = donor_before.get('execution_identity', {})
    donor_run = donor_execution.get('execution_id', '')
    require(donor_execution.get('schema') == 'otzaria.original-editor.local-execution/1'
            and donor_execution.get('repository') == REPOSITORY
            and donor_execution.get('source_sha') == donor_source
            and donor_execution.get('root') == donor_root
            and donor_execution.get('head_branch') == scope['donor_branch']
            and isinstance(donor_run, str) and donor_run.startswith('local-')
            and str(uuid.UUID(donor_run[6:])) == donor_run[6:]
            and donor_execution.get('host', {}).get('system') == 'Darwin'
            and donor_execution.get('host', {}).get('architecture') == 'arm64'
            and donor_execution.get('acceptance') == 'PROVENANCE_ONLY_NOT_ACCEPTANCE'
            and donor_identity == donor_qualification.get('execution_identity')
            and donor_identity.get('producer_kind') == 'local-mac'
            and donor_identity.get('source_sha') == donor_source
            and donor_identity.get('run_id') == donor_run and donor_identity.get('run_attempt') == '1'
            and donor_identity.get('local_execution') == donor_execution
            and donor_identity.get('local_execution_sha256') == rows['abi_donor_execution']['sha256']
            and donor_before.get('head_sha') == donor_source
            and donor_before.get('status') == 'SOURCE_BOUND_FRAMEWORK_RUNTIME_NOT_RUN',
            'Original donor execution identity was replaced by the current SDK')
    installation = donor_qualification.get('heart', {})
    validate_abi_adapter(donor_abi, installation, donor_source)
    require(donor_qualification.get('status') == QUALIFIED
            and donor_qualification.get('phase') == 'COMPLETE'
            and donor_qualification.get('source_sha') == donor_source
            and donor_qualification.get('original_framework_build') == 'PASS'
            and donor_qualification.get('external_consumer_build') == 'PASS'
            and donor_abi.get('status') == 'PASS' and donor_abi.get('producer_kind') == 'local-mac'
            and donor_abi.get('sdk_source_sha') == donor_source
            and donor_abi.get('local_execution_sha256') == rows['abi_donor_execution']['sha256']
            and donor_abi.get('full_sdk_accepted') is False
            and donor_abi.get('editor_ui_accepted') is False
            and donor_abi.get('owned_command_groups_drained') is True
            and installation.get('status') == 'PASS'
            and installation.get('app_source_sha') == donor_source
            and installation.get('receipt_sha256') == rows['abi_donor_abi']['sha256']
            and installation.get('native_qualification') == donor_abi.get('native_qualification')
            and installation.get('native_qualification', {}).get('status') == 'PASS',
            'Original donor ABI installation or completed qualification differs')
    wrapper, wrapper_proof = values['abi_donor_pinned_wrapper'], installation['pinned_wrapper']
    wrapper_reference = donor_abi['pinned_wrapper']
    require(rows['abi_donor_pinned_wrapper']['sha256'] == wrapper_reference['sha256']
            and rows['abi_donor_pinned_wrapper']['bytes'] == wrapper_reference['bytes']
            and all(wrapper.get(key) == value for key, value in wrapper_proof.items()
                    if key not in {'receipt_sha256', 'targets'})
            and [row.get('target') for row in wrapper.get('targets', [])] == wrapper_proof['targets'],
            'Original pinned-wrapper receipt or three-target proof differs')

    fresh_proof = None
    if fresh_donor:
        # Validate the original schema3 receipts with their original owner.
        # Current framework execution is never substituted for native66/Swift.
        aliases = {role: 'abi_donor_' + role.removeprefix('abi_') for role in FRESH_ROLES}
        fresh_values = {role: values[donor_role] for role, donor_role in aliases.items()}
        fresh_values['abi'] = donor_abi
        fresh_rows = {role: rows[donor_role] for role, donor_role in aliases.items()}
        fresh_rows.update(abi=rows['abi_donor_abi'], source_before=rows['abi_donor_source_before'])
        fresh_config = {**config, 'abi_provenance': FRESH_SCHEMA, 'source_sha': donor_source,
                        'local_receipts': fresh_rows}
        fresh_proof = validate_fresh_abi(fresh_values, fresh_config, installation, donor_before)
        require(donor_qualification.get('shared_runtime_ownership', {}).get('status')
                    == 'PASS_OBSERVED_SINGLE_SHARED_IMPLEMENTATIONS'
                and {row.get('language') for row in donor_qualification.get('verified_runtime_observations', [])}
                    == {'en', 'he'}
                and len(donor_qualification.get('verified_runtime_observations', [])) == 2,
                'Fresh donor lost its original framework runtime and ownership qualification')

    reuse = heart.get('abi_reuse', {})
    require(heart.get('schema') == DONOR_SCHEMA and heart.get('status') == 'PASS'
            and heart.get('receipt_sha256') == rows['abi']['sha256']
            and heart.get('app_source_sha') == config['source_sha']
            and heart.get('producer_kind') == 'local-mac'
            and heart.get('original_abi_producer_identity') == donor_identity
            and reuse.get('status') == 'EXACT_NATIVE_INPUT_AND_ARTIFACT_EQUIVALENCE'
            and reuse.get('donor_source_sha') == donor_source
            and reuse.get('donor_root') == donor_root
            and reuse.get('donor_receipts') == policy_receipts
            and reuse.get('unchanged_git_inputs') == policy['unchanged_git_inputs']
            and reuse.get('original_abi_installation') == installation
            and reuse.get('native_tests_rerun') is False
            and reuse.get('new_sdk_acceptance_granted') is False
            and all(heart.get(key) == installation.get(key) for key in
                    ('lib_files', 'native_qualification', 'pinned_wrapper')),
            'Current SDK omits the exact original donor installation and reuse scope')
    for observation in (heart, installation):
        require(observation.get('generated_files_verified') == 733
                and observation.get('generated_files_written') == 0
                and observation.get('full_sdk_accepted') is False
                and observation.get('editor_ui_accepted') is False,
                'Donor provenance cannot grant new native, generator or editor acceptance')
    lib_files = installation.get('lib_files', [])
    require(len(lib_files) == 17 and len({row.get('path') for row in lib_files}) == 17
            and all(set(row) == {'path', 'bytes', 'sha256'}
                    and row['path'].startswith('Dependencies/Middleware/Lib.xcframework/')
                    and '..' not in Path(row['path']).parts
                    and type(row['bytes']) is int and row['bytes'] > 0
                    and re.fullmatch(r'[0-9a-f]{64}', row['sha256']) for row in lib_files),
            'Original installed Lib closure is incomplete')
    current_generated = before.get('generated_import_source', {})
    old_generated = donor_before.get('generated_import_source', {})
    generated_keys = ('generated_index_sha256', 'source_adoption_sha256', 'working_generated_files',
                      'committed_generated_blobs', 'postimage_source', 'preimage_source')
    require(all(key in current_generated and current_generated[key] == old_generated.get(key)
                for key in generated_keys)
            and current_generated.get('working_generated_files') == 733
            and current_generated.get('committed_generated_blobs') == 733,
            'The current 733 generated native sources differ from the original donor')
    continuation = current_generated.get('annotation_exchange', {})
    if fresh_donor:
        require(current_generated == old_generated
                and continuation.get('base_source') == DONOR_SOURCE
                and all(before.get('original_trees', {}).get(key)
                        == donor_before.get('original_trees', {}).get(key)
                        == policy['unchanged_git_inputs'][key]
                        for key in ('Anytype/Sources', 'Anytype/Resources', 'Modules')),
                'Fresh donor changed the original generated or application source scope')
    else:
        require(continuation.get('base_source') == donor_source
                and continuation.get('native_acceptance_reused_by_this_document') is False
                and continuation.get('sdk_compiler_and_runtime_acceptance') == 'NOT_GRANTED_BY_SOURCE_OBSERVATION'
                and all(before.get('original_trees', {}).get(key)
                        == continuation.get('reviewed_product_trees', {}).get(key)
                        for key in ('Anytype/Sources', 'Anytype/Resources', 'Modules'))
                and all(before.get('original_trees', {}).get(key) == policy['unchanged_git_inputs'][key]
                        for key in ('Anytype/Resources', 'Modules')),
                'Current Swift continuation exceeds its reviewed source scope')
    return {'schema': DONOR_SCHEMA, 'donor_source_sha': donor_source,
            'original_abi_producer_identity': donor_identity,
            'donor_receipts': policy_receipts,
            **({'original_fresh_abi_provenance': fresh_proof} if fresh_proof else {}),
            'native_tests_rerun': False,
            'new_sdk_acceptance_granted': False,
            'scope': 'EXACT_RETAINED_ORIGINAL_ABI_NOT_NEW_NATIVE_OR_EDITOR_ACCEPTANCE'}


def validate_provenance(root, config, qualification, api):
    values = read_receipts(root, config, api)
    contract = validate_public_contract(config, values['source_before'], api)
    execution = values['execution']
    donor_route = config.get('abi_provenance') == DONOR_SCHEMA
    fresh_route = config.get('abi_provenance') == FRESH_SCHEMA
    require(not donor_route or contract in (MINIAPPS_CONTRACT, FILES_MINIAPPS_CONTRACT),
            'Donor reuse requires the reviewed complete MiniApps public contract')
    branch = (donor_policy_scope(config.get('abi_donor_source_sha'))['current_branch'] if donor_route else
              'codex/anytype-original-miniapps-facade-20261125' if fresh_route else
              'codex/otzaria-local-annotation-sdk-20261124' if contract else
              'codex/otzaria-sdk-mac-20261124')
    require(execution.get('schema') == 'otzaria.original-editor.local-execution/1'
            and execution.get('repository') == REPOSITORY
            and execution.get('execution_id') == config['run_id']
            and execution.get('source_sha') == config['source_sha']
            and re.fullmatch(r'[0-9a-f]{40}', execution.get('source_tree', ''))
            and execution.get('head_branch') == branch
            and execution.get('host', {}).get('system') == 'Darwin'
            and execution.get('host', {}).get('architecture') == 'arm64'
            and execution['host'].get('hostname')
            and execution.get('acceptance') == 'PROVENANCE_ONLY_NOT_ACCEPTANCE',
            'The actual dedicated-Mac producer identity differs')
    identity = qualification.get('execution_identity', {})
    require(identity.get('producer_kind') == 'local-mac'
            and identity.get('source_sha') == config['source_sha']
            and identity.get('run_id') == config['run_id'] and identity.get('run_attempt') == '1'
            and identity.get('local_execution_sha256') == config['local_execution_sha256']
            and identity.get('local_execution') == execution,
            'SDK qualification does not bind the real local producer')
    before, after, abi = values['source_before'], values['source_after'], values['abi']
    require(before == after and before.get('head_sha') == config['source_sha']
            and before.get('execution_identity') == identity
            and before.get('status') == 'SOURCE_BOUND_FRAMEWORK_RUNTIME_NOT_RUN',
            'Actual SDK source closure was not preserved through execution')
    donor_proof = fresh_proof = None
    require((abi.get('schema') == FRESH_SCHEMA) == fresh_route,
            'Fresh original ABI cannot silently use a historical provenance route')
    if donor_route:
        donor_proof = validate_donor_abi(values, config, qualification.get('heart', {}), before)
    else:
        validate_abi_adapter(abi, qualification.get('heart', {}), config['source_sha'])
        if fresh_route:
            fresh_proof = validate_fresh_abi(values, config, qualification.get('heart', {}), before)
        require(abi.get('status') == 'PASS' and abi.get('producer_kind') == 'local-mac'
                and abi.get('sdk_source_sha') == config['source_sha']
                and abi.get('local_execution_sha256') == config['local_execution_sha256']
                and abi.get('full_sdk_accepted') is False and abi.get('editor_ui_accepted') is False
                and abi.get('owned_command_groups_drained') is True
                and qualification.get('heart', {}).get('receipt_sha256') == config['local_receipts']['abi']['sha256']
                and qualification['heart'].get('native_qualification') == abi.get('native_qualification')
                and abi.get('native_qualification', {}).get('status') == 'PASS',
                'SDK does not consume the qualified original Import ABI')
    require(qualification.get('status') == QUALIFIED and qualification.get('phase') == 'COMPLETE'
            and qualification.get('original_framework_build') == 'PASS'
            and qualification.get('external_consumer_build') == 'PASS'
            and qualification.get('native_editor_ui_tests') == 0,
            'Local transport cannot qualify an unfinished framework or award editor UI credit')
    return {'producer_kind': 'local-mac', 'local_execution_sha256': config['local_execution_sha256'],
            'local_receipts': config['local_receipts'], 'native_stageb_qualified': False,
            'scope': 'EXACT_LOCAL_PRODUCER_SOURCE_AND_ABI_PROVENANCE_ONLY',
            **({'abi_reuse': donor_proof} if donor_proof else {}),
            **({'fresh_abi_provenance': fresh_proof} if fresh_proof else {}),
            **({'public_host_contract_sha256': contract} if contract else {})}


def restore_archive(root, config, api, zip_members):
    """Transport exact archived bytes; callers retain their own qualification gates."""
    root = Path(root)
    archive = api['owned_path'](root, config['archive_path'], build=True)
    require(archive.is_file() and archive.stat().st_size == config['archive_bytes']
            and api['digest'](archive) == config['archive_sha256'], 'Local SDK archive bytes differ')
    manifest = api['owned_path'](root, config['distribution_manifest_path'], build=True)
    hanlin = api['owned_path'](root, config['hanlin_source_path'], build=True)
    require(api['digest'](manifest) == config['distribution_manifest_sha256']
            and api['digest'](hanlin) == config['hanlin_source_sha256'], 'Local SDK sidecars differ')
    exported = api['read_json'](manifest)
    expected = dict(exported['files'])
    require(expected and 'QUALIFICATION.json' not in expected, 'Circular local SDK inventory')
    destination = api['owned_path'](root, config['distribution_root'], build=True)
    with zipfile.ZipFile(archive) as zipped:
        members = zip_members(zipped)
        require(set(members) == set(expected) | {'QUALIFICATION.json'}, 'Local SDK ZIP membership differs')
        qualification = members['QUALIFICATION.json']
        require(0 < qualification.file_size <= 16 * 1024 * 1024, 'Oversized local qualification')
        expected['QUALIFICATION.json'] = {'bytes': qualification.file_size, 'sha256': config['qualification_sha256']}
        if destination.exists():
            require(api['inventory'](destination) == expected, 'Existing local SDK distribution differs')
        else:
            destination.mkdir(parents=True)
            for name, item in members.items():
                require(item.file_size == expected[name]['bytes'], 'Local SDK ZIP member size differs')
                target = destination / name
                target.parent.mkdir(parents=True, exist_ok=True)
                with zipped.open(item) as source, target.open('xb') as output:
                    shutil.copyfileobj(source, output)
                require(api['digest'](target) == expected[name]['sha256'], 'Local SDK member digest differs')
                mode = stat.S_IMODE((item.external_attr >> 16) & 0xFFFF) or 0o644
                require(mode & ~0o777 == 0, 'Special local SDK permission bits')
                target.chmod(mode)
            require(api['inventory'](destination) == expected, 'Restored local SDK inventory differs')
    return destination, expected


def restore(root, config, evidence, api, zip_members):
    """Restore an already staged exact local archive using the original ZIP rules."""
    read_receipts(root, config, api)
    evidence = Path(evidence)
    destination, expected = restore_archive(root, config, api, zip_members)
    qualification = api['read_json'](destination / 'QUALIFICATION.json')
    proof = validate_provenance(root, config, qualification, api)
    api['write'](evidence / 'restoration.json', {
        'status': 'EXACT_LOCAL_ORIGINAL_SDK_ARCHIVE_RESTORED', 'producer': proof,
        'files': len(expected), 'source_sha': config['source_sha'], 'run_id': config['run_id'],
        'native_editor_ui_tests': 0, 'overwritten_inputs': 0})