"""Admit the one reviewed simulator Debug continuation of the original Import ABI.

The current Swift SDK ran the complete external checks in both languages. The
native archive build and its native test counts continue to belong to the
earlier producer. No receipt here participates in the final release routes.
"""

DEBUG_CONTINUATION = 'otzaria.original-import-sdk-debug-continuation/1'
DEBUG_QUALIFIED = 'ACTUAL_CURRENT_ORIGINAL_DEBUG_EXTERNAL_NATIVE_CONSUMER_PASS'
DEBUG_SOURCE = '1b5fb6a68b1f8e1e61ac20ce02920e6c1fdb09e3'
DEBUG_TREE = '5cc874f8238c9c510c90fff77ff8bd9c523f3ab6'
DEBUG_BRANCH = 'codex/otzaria-annotation-sdk-requalification-20261125'
ORIGIN_SOURCE = '4c9fcd14af2ffcbd223fd8a47a0c806c88429d21'
NATIVE_SOURCE = '54ba7095178f77b5f80473581e28c226b74f6182'
NATIVE_TREE = 'ccff9278b2c165eb470891e4dac41e0eca65a5e7'
EXTERNAL_RESULT = '671734345dbe58658f24ee91edda2374a1cd5be04dc660edfa8401048baeff3b'
SOURCE_OBSERVATION = '0cca110276077d42f476015f93e9dd2202ad7fc69fd9c94b7d26d90294fc01d1'
ABI_ORIGIN = '29b7e8472c9c80245c26101e716e4687cdc4c2666ad4aadf8d3543a9b94d30de'
ABI_VERIFICATION = '968f57544d061ec76c39d83feeb5d624e10dd7037d355efb5a2366272d5c3658'
ABI_CONTEXT = 'daa628a8616350e83e7bd196e28fa802d23b8512f9d5489f18264cce6fe69e60'
PRODUCER_VERIFICATION = '05b7e336562327ad910de250208488c020a8263eb2aa3205d5b912a8fc2d3219'
SHARED_OWNERSHIP = 'c061878f64950a32132df68bb04e10fba0d875d4046fd5e4527b511f035c5dbc'
ROLES = {'debug_origin_abi', 'debug_origin_verification', 'debug_producer_verification',
         'debug_shared_runtime_ownership'}


def require(value, message):
    if not value:
        raise RuntimeError(message)


def validate_configuration(config):
    require(config.get('configuration') == 'Debug'
            and config.get('platform') == 'iphonesimulator'
            and config.get('source_sha') == DEBUG_SOURCE
            and config.get('native_source_tree') == NATIVE_TREE
            and config.get('qualification_sha256') == EXTERNAL_RESULT
            and config.get('device_framework_qualified') is False
            and config.get('native_stageb_qualified') is False
            and 'signing_team_id' not in config,
            'The exact Debug-only SDK continuation cannot be substituted for a release input')
    expected = {'source_before': SOURCE_OBSERVATION, 'source_after': SOURCE_OBSERVATION,
                'abi': ABI_CONTEXT, 'debug_origin_abi': ABI_ORIGIN,
                'debug_origin_verification': ABI_VERIFICATION,
                'debug_producer_verification': PRODUCER_VERIFICATION,
                'debug_shared_runtime_ownership': SHARED_OWNERSHIP}
    require(all(config['local_receipts'].get(name, {}).get('sha256') == digest
                for name, digest in expected.items()),
            'The original SDK continuation receipt digests differ')


def verify_native_origin(values, config, qualification, source_before, validate_abi_adapter):
    abi, origin, original_check = (
        values['abi'], values['debug_origin_abi'], values['debug_origin_verification'])
    validate_abi_adapter(origin, original_check, ORIGIN_SOURCE)
    prior = origin['native_qualification']
    require(origin.get('status') == original_check.get('status') == 'PASS'
            and origin.get('sdk_source_sha') == original_check.get('app_source_sha') == ORIGIN_SOURCE
            and original_check.get('receipt_sha256') == ABI_ORIGIN
            and prior == original_check.get('native_qualification')
            and prior.get('source_sha') == ORIGIN_SOURCE
            and prior.get('original_control_source') == ORIGIN_SOURCE
            and prior.get('native_source_commit') == NATIVE_SOURCE
            and prior.get('native_source_tree') == NATIVE_TREE
            and origin.get('generated_files_verified') == original_check.get('generated_files_verified') == 733
            and original_check.get('full_sdk_accepted') is False
            and original_check.get('editor_ui_accepted') is False,
            'The reproduced original native ABI verification has a different scope or identity')
    require(abi == qualification.get('heart')
            and abi.get('status') == 'PASS_CURRENT_INSTALLED_LIB_MATCHES_ORIGINAL_VERIFIED_V3'
            and abi.get('current_sdk_source') == DEBUG_SOURCE
            and abi.get('current_local_execution_sha256') == config['local_execution_sha256']
            and abi.get('original_sdk_control_source') == ORIGIN_SOURCE
            and abi.get('original_v3_receipt_sha256') == ABI_ORIGIN
            and abi.get('original_native_execution') == original_check
            and abi.get('current_generated_directory_verified') is True
            and abi.get('current_native_compiler_reexecuted') is False
            and abi.get('current_generated_swift_link_reexecuted') is False
            and abi.get('grants_sdk_runtime_qualification') is False
            and abi.get('lib_files') == origin.get('lib_files') == original_check.get('lib_files')
            and len(abi['lib_files']) == 17 and source_before.get('head_sha') == DEBUG_SOURCE,
            'The current Debug runtime did not consume the exact retained original ABI')
    require(qualification.get('status') == DEBUG_QUALIFIED
            and qualification.get('formal_sdk_release_qualification') is False
            and qualification.get('device_framework_build') == 'NOT_RUN'
            and qualification.get('original_app_runtime') == 'NOT_RUN',
            'The external Debug observation cannot grant editor UI or device qualification')


    observed = values['debug_producer_verification']
    owner = values['debug_shared_runtime_ownership']
    expected_native = {'source_sha': NATIVE_SOURCE, 'tree': NATIVE_TREE,
                       'original_abi_swift_sha': ORIGIN_SOURCE, 'original_abi_sha256': ABI_ORIGIN}
    require(observed.get('schema') == 'otzaria.exact-original-debug-native-continuation/1'
            and observed.get('status') == 'VERIFIED_ACTUAL_ORIGINAL_DEBUG_EXTERNAL_NATIVE_CONSUMER'
            and observed.get('source_sha') == DEBUG_SOURCE and observed.get('native') == expected_native
            and observed.get('distribution_manifest_sha256') == config['distribution_manifest_sha256']
            and observed.get('external_observations') == qualification.get('verified_runtime_observations')
            and observed.get('editor_ui_tests') == 0
            and observed.get('sdk_device_build') is False and observed.get('release_qualification') is False,
            'The reviewed current external continuation and staged Debug distribution differ')
    identity = {'source_sha': DEBUG_SOURCE, 'run_id': config['run_id'], 'run_attempt': '1'}
    require(owner.get('status') == 'PASS_OBSERVED_SINGLE_SHARED_IMPLEMENTATIONS'
            and owner.get('producer') == identity
            and owner.get('original_debug_external_runtime_sha256') == EXTERNAL_RESULT
            and owner.get('verified_debug_continuation_sha256') == PRODUCER_VERIFICATION
            and owner.get('qualification_write_performed') is False
            and owner.get('release_qualification') is False
            and owner.get('stageb_qualified') is False
            and all(owner.get('binary_identity', {}).get(name, {}).get('sha256') == digest
                    for name, digest in observed['images'].items()),
            'Actual shared ownership belongs to a different distribution or producer')
    return {'status': DEBUG_QUALIFIED, 'scope': 'INDEPENDENT_DEBUG_SIMULATOR_ONLY',
            'source_sha': DEBUG_SOURCE, 'original_abi_source': ORIGIN_SOURCE,
            'original_abi_sha256': ABI_ORIGIN, 'native_source_tree': NATIVE_TREE,
            'release_qualified': False, 'native_stageb_qualified': False,
            'shared_runtime_ownership': owner}
