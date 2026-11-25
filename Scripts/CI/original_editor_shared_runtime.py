"""Admit one source-identical implementation for the original Stage B consumer.

This module never grants editor UI credit. Native ownership, all Hanlin package
files, actual Pod source memberships, headers, locks and defined symbols are
required before the generated Debug app may reuse the shared providers.
"""
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shlex

from original_editor_host_clang_context import bounded_file, digest, host_module_inventory, modules, require
from original_editor_clang_imports import read_clang_imports
from original_editor_hanlin_equivalence import read_review, verify_hanlin_sources

RUNTIME = 'OriginalEditorSharedFirebase'
EDITOR = 'AnytypeOriginalEditor'
PRODUCTS = [
    'HanlinHostContracts', 'HanlinAgentCore', 'HanlinChatCore', 'HanlinScriptUI',
    'HanlinChatUI', 'HanlinPresentationKit', 'HanlinRichUI', 'HanlinPlatformContracts',
    'FloatingPanel', 'TorahInspectorCore', 'TorahInspectorUI', 'ZIPFoundation',
]
PODS = {
    'FirebaseCore': ('firebase-ios-sdk', '12.8.0'),
    'FirebaseCoreInternal': ('firebase-ios-sdk', '12.8.0'),
    'FirebaseInstallations': ('firebase-ios-sdk', '12.8.0'),
    'GoogleUtilities': ('googleutilities', '8.1.5'),
    'GoogleDataTransport': ('googledatatransport', '10.1.1'),
    'PromisesObjC': ('promises', '2.4.1'),
    'PromisesSwift': ('promises', '2.4.1'),
    'nanopb': ('nanopb', '3.30910.0'),
}
CLANG_PODS = {
    'FBLPromises': ('PromisesObjC', 'promises/Sources/FBLPromises/include'),
    'GoogleDataTransport': ('GoogleDataTransport', 'GoogleDataTransport/GoogleDataTransport/GDTCORLibrary/Public'),
    'nanopb': ('nanopb', 'nanopb/spm_headers'),
    'FirebaseInstallations': ('FirebaseInstallations', 'firebase-ios-sdk/FirebaseInstallations/Source/Library/Public'),
    'FirebaseCore': ('FirebaseCore', 'firebase-ios-sdk/FirebaseCore/Sources/Public'),
}
HANLIN_ROOTS = ('Packages/HanlinAgentSDK/', 'Packages/HanlinPlatform/', 'Packages/HanlinPresentationSDK/')
POD_XCCONFIG = 'Pods/Target Support Files/Pods-Maktabah-iOS/Pods-Maktabah-iOS.debug.xcconfig'
SWIFT_POD_MODULES = ('FirebaseCoreInternal', 'Promises')


def validate_provider(root, config, qualification, admitted):
    shared = config['shared_runtime']
    require(shared.get('kind') == 'original-shared-implementations/1'
            and shared.get('host_products') == PRODUCTS
            and shared.get('host_pod_versions') == {k: v[1] for k, v in PODS.items()},
            'Unreviewed exact shared implementation contract')
    owner = qualification.get('shared_runtime_ownership', {})
    identity = {'source_sha': config['source_sha'], 'run_id': str(config['run_id']),
                'run_attempt': str(config['run_attempt'])}
    require(qualification.get('strict_dependency_resolution') == 'PASS_EXACT_COMMITTED_LOCK_UNCHANGED'
            and owner.get('status') == 'PASS_OBSERVED_SINGLE_SHARED_IMPLEMENTATIONS'
            and owner.get('producer') == identity and owner.get('shared_host_products') == PRODUCTS
            and owner.get('stageb_qualified') is False
            and owner.get('host_semantic_equality_required') is True,
            'Original producer has not proven the exact shared implementations')
    require(owner.get('hanlin_package_files') == admitted['hanlin_source']['files']
            and owner.get('hanlin_source_revision') == admitted['hanlin_source']['revision']
            == shared['hanlin_revision']
            and owner.get('shared_swift_ai_sdk_revision') == shared['swift_ai_revision'],
            'Native shared Hanlin source identity differs')
    distribution = root / admitted['distribution_root']
    resolved = {p['identity']: p['state'] for p in
                json.loads((distribution / 'SourceProvenance/Original-Package.resolved').read_text())['pins']}
    require(owner.get('resolved_package_states') == resolved, 'Native resolved package inventory differs')
    for name in [RUNTIME, EDITOR]:
        require(name + '.framework' in admitted['dynamic_frameworks']
                and digest(distribution / 'Frameworks' / (name + '.framework') / name)
                == owner['binary_identity'][name]['sha256'], 'Actual shared implementation binary differs')
    for module in PRODUCTS:
        directory = distribution / 'Modules' / (module + '.swiftmodule')
        actual = {p.relative_to(directory).as_posix(): digest(p) for p in sorted(directory.rglob('*')) if p.is_file()}
        require(actual and actual == owner['shared_module_declarations'][module]
                and owner['host_module_definition_counts'][module] > 0,
                'Shared Host declaration/implementation pair differs: ' + module)
    clang_identity = {**identity, 'original_package_lock_sha256': admitted['original_package_lock_sha256'],
                      'manifest_sha256': shared['clang_manifest_sha256']}
    clang = read_clang_imports(distribution, clang_identity)
    require(clang == shared['clang_roots'], 'Reviewed complete Clang import closure differs')
    equivalence = shared.get('host_source_equivalence')
    equivalence = read_review(root, equivalence, shared['hanlin_revision']) if equivalence is not None else None
    return {'schema': 1, 'producer_identity': identity, 'ownership': owner,
            **({'host_source_equivalence': equivalence} if equivalence is not None else {}),
            'host_products': PRODUCTS, 'host_pod_versions': shared['host_pod_versions'],
            'clang_context': {'producer_identity': clang_identity, **clang},
            'hanlin_revision': shared['hanlin_revision'], 'swift_ai_revision': shared['swift_ai_revision'],
            'producer_original_implementations_preserved': True, 'native_stageb_qualified': False}


def verify_host_sources(root, admitted, report):
    shared = admitted['shared_runtime']
    owner = shared['ownership']
    host_files, hanlin_identity = verify_hanlin_sources(root, shared, report['hanlin_sdk_source'])
    locks = {}
    for name in [
        'Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved',
        'Maktabah.xcworkspace/xcshareddata/swiftpm/Package.resolved',
    ]:
        path = root / name
        pins = {p['identity']: p['state']['revision'] for p in json.loads(path.read_text())['pins']}
        require(pins == report['package_pins'] and pins['swift-ai-sdk'] == shared['swift_ai_revision'],
                'An operative Host project/workspace lock differs: ' + name)
        locks[name] = digest(path)
    for name in [p for p in host_files if p.endswith('Package.resolved')]:
        pins = json.loads((root / 'Vendor/HanlinSDK' / name).read_text()).get('pins', [])
        for pin in pins:
            if pin['identity'] == 'swift-ai-sdk':
                require(pin['state']['revision'] == shared['swift_ai_revision'],
                        'An operative Hanlin package lock differs')
        locks['Vendor/HanlinSDK/' + name] = digest(root / 'Vendor/HanlinSDK' / name)
    raw = (root / 'Podfile.lock').read_text()
    installed = (root / 'Pods/Manifest.lock').read_text()
    require(raw == installed and raw.startswith('PODS:\n'), 'Installed CocoaPods resolution differs')
    top = raw.split('\n\n', 1)[0]
    versions = {}
    for name, version in re.findall(r'^  - ([^\s(]+) \(([^)]+)\)', top, re.M):
        name = name.split('/')[0]
        require(name not in versions or versions[name] == version, 'Conflicting installed Pod versions')
        versions[name] = version
    require(all(versions.get(name) == version for name, (_, version) in PODS.items()),
            'Host CocoaPods and shared provider versions differ')
    dependencies = owner['shared_dependency_sources']
    require(set(dependencies) == {identity for identity, _ in PODS.values()},
            'Native shared provider source inventory is incomplete')
    for identity, row in dependencies.items():
        require(row['revision'] == owner['root_dependency_revisions'][identity]['revision']
                and row['files'], 'Native shared dependency provenance differs')
    return {'status': 'EXACT_COMPLETE_SHARED_HOST_SOURCE_CLOSURE', 'hanlin_files': len(host_files),
            **hanlin_identity,
            'hanlin_revision': shared['hanlin_revision'], 'swift_ai_revision': shared['swift_ai_revision'],
            'operative_lock_sha256': locks, 'podfile_lock_sha256': digest(root / 'Podfile.lock'),
            'host_pod_versions': {name: versions[name] for name in PODS},
            'pod_source_contracts': {name: dependencies[identity] for name, (identity, _) in PODS.items()},
            'native_stageb_qualified': False}


def project_clang_context(root, distribution, context):
    host_maps = host_module_inventory(root)
    maps, reused, replacements = [], [], {}
    for relative in context['module_maps']:
        original = bounded_file(distribution / relative, distribution)
        names = modules(original)
        collisions = [name for name in names if name in host_maps]
        if not collisions:
            maps.append(str((distribution / relative).relative_to(root)))
            continue
        require(len(names) == len(collisions) == 1 and names[0] in CLANG_PODS,
                'Unreviewed Host/producer Clang collision: ' + repr(names))
        name = names[0]
        pod, suffix = CLANG_PODS[name]
        candidates = [h for h in context['header_search_paths'] if h == 'Clang/Packages/' + suffix]
        require(len(candidates) == 1, 'Shared Clang module lacks its exact declaration root')
        sdk_root = distribution / candidates[0]
        public = root / 'Pods/Headers/Public' / pod
        require(public.is_dir(), 'Actual installed Pod header root is absent')
        host_headers = {}
        for path in public.rglob('*'):
            if path.is_file() and path.suffix in {'.h', '.hh', '.hpp', '.hxx', '.inc', '.def'}:
                real = bounded_file(path, root)
                host_headers.setdefault(path.name, []).append((path, digest(real)))
        exact = {}
        for path in sorted(sdk_root.rglob('*')):
            if not path.is_file() or path.suffix not in {'.h', '.hh', '.hpp', '.hxx', '.inc', '.def'}:
                continue
            expected = digest(bounded_file(path, distribution))
            matches = [p for p, sha in host_headers.get(path.name, []) if sha == expected]
            require(len(matches) == 1, 'Host lacks an unambiguous byte-identical shared declaration: ' + path.name)
            exact[path.relative_to(sdk_root).as_posix()] = {
                'sha256': expected, 'host': matches[0].relative_to(root).as_posix()}
        require(exact, 'Shared declaration root is empty')
        host_map = root / host_maps[name]
        bounded_file(host_map, root)
        require(modules(host_map) == [name], 'Actual Host canonical map has extra or renamed modules')
        maps.append(host_maps[name])
        replacements[candidates[0]] = public.relative_to(root).as_posix()
        reused.append({'module': name, 'sdk_map': relative, 'sdk_map_sha256': digest(original),
                       'host_map': host_maps[name], 'host_map_sha256': digest(host_map),
                       'declarations': exact})
    require({r['module'] for r in reused} == set(CLANG_PODS),
            'Exact known CocoaPods collision set differs')
    headers = [replacements.get(h, (distribution / h).relative_to(root).as_posix())
               for h in context['header_search_paths']]
    require(len(maps) == len(set(maps)) == len(context['module_maps'])
            and len(headers) == len(set(headers)) == len(context['header_search_paths']),
            'Shared projection changed or duplicated the full import closure')
    return {'schema': 1, 'status': 'HOST_CLANG_CONTEXT_COMPOSED',
            'producer_identity': context['producer_identity'], 'module_maps': maps,
            'header_search_paths': headers, 'runtime_collisions': [],
            'reused_identical_host_modules': reused, 'original_export_modified': False,
            'shared_implementation_required': True, 'native_build_or_runtime_qualified': False}


def plan_pod_link_route(root, source_proof, *, configuration='Debug'):
    require(configuration in {'Debug', 'Release'}, 'Unreviewed app Pod configuration')
    relative = POD_XCCONFIG.replace('.debug.xcconfig', '.' + configuration.lower() + '.xcconfig')
    path = root / relative
    require(path.is_file() and not path.is_symlink(), 'Missing generated app ' + configuration + ' xcconfig')
    raw = path.read_text()
    rows = [line for line in raw.splitlines(keepends=True) if line.startswith('OTHER_LDFLAGS = ')]
    require(len(rows) == 1, 'Ambiguous generated CocoaPods linker settings')
    before = rows[0]
    after = before
    for pod in PODS:
        token = ' -l"' + pod + '"'
        require(after.count(token) == 1, 'Missing or repeated actual shared Pod link input: ' + pod)
        after = after.replace(token, '', 1)
    before_tokens, after_tokens = shlex.split(before), shlex.split(after)
    expected_removed = {'-l' + pod for pod in PODS}
    require([t for t in before_tokens if t not in expected_removed] == after_tokens
            and all(before_tokens.count(t) == 1 for t in expected_removed),
            'Shared link projection changed another linker input')
    projected = raw.replace(before, after, 1)
    require(projected.replace(after, before, 1) == raw, 'Generated linker configuration inverse differs')
    return {'path': relative, 'before_sha256': hashlib.sha256(raw.encode()).hexdigest(),
            'after_sha256': hashlib.sha256(projected.encode()).hexdigest(),
            'before_line': before, 'after_line': after,
            'shared_pod_libraries': list(PODS), 'pod_source_contracts': source_proof['pod_source_contracts'],
            'other_linker_inputs_unchanged': True}


def swift_import_arguments(distribution, context):
    require(read_clang_imports(distribution, context['producer_identity'])
            == {k: context[k] for k in ['module_maps', 'header_search_paths']},
            'Admitted shared Clang input closure changed')
    return [argument for path in context['header_search_paths'] for argument in
            ['-Xcc', '-I' + str(distribution / path)]] + [
            argument for path in context['module_maps'] for argument in
            ['-Xcc', '-fmodule-map-file=' + str(distribution / path)]]


def recorded_host_library_paths(root, records):
    """Recheck actual build-phase library observations without guessing archive paths."""
    root = Path(root).resolve()
    require(isinstance(records, dict) and set(records) == set(PODS),
            'Incomplete original Host library observations')
    result = {}
    for pod, record in records.items():
        path = Path(record['canonical_path'])
        require(path.is_absolute() and path.resolve() == path
                and path.is_relative_to(root / 'build') and path.is_file() and not path.is_symlink()
                and type(record.get('bytes')) is int and record['bytes'] > 0
                and path.stat().st_size == record['bytes'] and digest(path) == record['sha256'],
                'Observed original Host library changed or escaped its owned build: ' + pod)
        result[pod] = path
    return result


def verify_app_ownership(root, admitted, app, evidence, command, *, after_ui=False, host_library_files=None):
    owner = admitted['shared_runtime']['ownership']
    images = {app.name: app / plistlib.loads((app / 'Info.plist').read_bytes())['CFBundleExecutable']}
    for path in sorted(app.rglob('*.framework')):
        info = plistlib.loads((path / 'Info.plist').read_bytes())
        binary = path / info['CFBundleExecutable']
        if binary.is_file():
            require(path.name not in images, 'Duplicate embedded framework identity')
            images[path.name] = binary
    for path in sorted(app.glob('*.dylib')):
        images[path.name] = path
    if after_ui:
        previous = json.loads((evidence / 'shared-app-ownership.json').read_text())
        current = {name: digest(path) for name, path in images.items()}
        require(previous['status'] == 'PASS_SINGLE_SHARED_APP_IMPLEMENTATIONS'
                and previous['producer'] == owner['producer']
                and previous['image_sha256'] == current,
                'Previously verified app/provider image closure changed during UI execution')
        reused = {**previous, 'source_receipt_sha256': digest(evidence / 'shared-app-ownership.json'),
                  'verification': 'EXACT_BINARY_CLOSURE_REUSES_PRE_UI_NATIVE_SYMBOL_PROOF',
                  'native_symbol_commands_replayed': False}
        (evidence / 'after-ui-shared-app-ownership.json').write_text(
            json.dumps(reused, indent=2, sort_keys=True) + '\n')
        return reused
    symbols = {}
    prefix = 'after-ui-' if after_ui else ''
    for index, (name, binary) in enumerate(images.items()):
        output = command(['xcrun', 'nm', '-gjU', str(binary)], root=root, evidence=evidence,
                         label=prefix + 'shared-owner-' + str(index), timeout=60)
        symbols[name] = {line.strip() for line in output.splitlines() if line.startswith('_')}
    runtime, editor = RUNTIME + '.framework', EDITOR + '.framework'
    require(runtime in symbols and editor in symbols, 'Built app lacks shared implementation images')
    namespaces = ['_$s' + str(len(m)) + m for m in PRODUCTS]
    required_editor = {s for s in symbols[editor] if s.startswith(tuple(namespaces))
                       or s.startswith('_cmark_') or s.startswith(('_OBJC_CLASS_$_MT', '_OBJC_METACLASS_$_MT'))}
    require(required_editor and all(any(s.startswith(p) for s in required_editor) for p in namespaces),
            'Built app lost a required shared Host module implementation')
    required_runtime = set()
    library_proofs = {}
    observed_libraries = (recorded_host_library_paths(root, host_library_files)
                          if host_library_files is not None else None)
    for pod in PODS:
        candidates = ([observed_libraries[pod]] if observed_libraries is not None else
                      [p for p in app.parent.rglob('lib' + pod + '.a') if p.is_file() and not p.is_symlink()])
        require(len(candidates) == 1, 'Missing or ambiguous actual Host Pod library: ' + pod)
        library = candidates[0]
        output = command(['xcrun', 'nm', '-gjU', str(library)], root=root, evidence=evidence,
                         label='shared-host-library-' + pod, timeout=60)
        selected = set()
        for line in output.splitlines():
            symbol = line.strip()
            if not symbol.startswith('_') or 'PodsDummy_' in symbol:
                continue
            if symbol.startswith(('_$s', '_$S')):
                if not any(symbol.startswith('_$s' + str(len(m)) + m) for m in SWIFT_POD_MODULES):
                    continue
            selected.add(symbol)
        require(selected and selected <= symbols[runtime],
                'Shared provider does not preserve every actual Host library implementation: ' + pod
                + ': ' + repr(sorted(selected - symbols[runtime])[:20]))
        required_runtime |= selected
        library_proofs[pod] = {'path': library.relative_to(root).as_posix(), 'sha256': digest(library),
                               'required_symbol_count': len(selected)}
    for target, required_symbols in [(runtime, required_runtime), (editor, required_editor)]:
        for symbol in required_symbols:
            actual = sorted(name for name, values in symbols.items() if symbol in values)
            require(actual == [target], 'Built app has a duplicate or wrong shared provider: ' + symbol)
    result = {'status': 'PASS_SINGLE_SHARED_APP_IMPLEMENTATIONS',
              'producer': owner['producer'], 'host_library_proofs': library_proofs,
              'runtime_required_symbols': sorted(required_runtime),
              'editor_shared_symbol_count': len(required_editor),
              'image_sha256': {name: digest(path) for name, path in images.items()},
              'stageb_qualified': False}
    (evidence / (prefix + 'shared-app-ownership.json')).write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    return result
