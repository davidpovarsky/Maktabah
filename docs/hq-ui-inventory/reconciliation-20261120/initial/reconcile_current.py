#!/usr/bin/env python3
"""Source-bound UI inventory crosswalk. No app execution or product mutation."""
import argparse
import collections
import hashlib
import json
import re
import subprocess
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--repo', type=Path, required=True)
p.add_argument('--source', required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
if a.output.exists():
    raise SystemExit('Preserve prior evidence: output must not exist')

def git(repo, *args, required=True):
    r = subprocess.run(['git', '-C', str(repo), *args], capture_output=True)
    if required and r.returncode:
        raise RuntimeError(r.stderr.decode('utf-8', errors='replace'))
    return r

source = git(a.repo, 'rev-parse', a.source + '^{commit}').stdout.decode().strip()
assert source == '0e879ae85c4533a7687095cf640f1dc02baf0e60'
cache = {}
def blob(repo, ref, path):
    key = (str(repo), ref, path)
    if key not in cache:
        r = git(repo, 'show', ref + ':' + path, required=False)
        cache[key] = r.stdout if r.returncode == 0 else None
    return cache[key]
def read(path):
    value = blob(a.repo, source, path)
    if value is None: raise RuntimeError('Missing source: ' + path)
    return value
def sha(raw): return hashlib.sha256(raw).hexdigest()

historical_path = 'docs/hq-ui-inventory/continuation-20261118/UI_ROUTE_COVERAGE.json'
historical = json.loads(read(historical_path))
prior_path = 'docs/hq-ui-inventory/current/UI01_CURRENT_HANDOFF.json'
prior = json.loads(read(prior_path))
old_report_path = 'docs/hq-ui-inventory/continuation-20261118/RECONCILIATION_REPORT.json'
old_report = json.loads(read(old_report_path))
rows = historical['semantic_surfaces']
assert len(rows) == len(set(x['id'] for x in rows)) == 294
assert set(x['id'] for x in prior['semantic_surfaces']).issubset(x['id'] for x in rows)

composition = 'Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift'
registry = 'Source/Otzaria/Actions/Sources/OtzariaActionCore/Registry/ActionRegistry.swift'
hanlin = 'Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinHostAdapter.swift'
runtime = read(composition).decode()
core_text = read(registry).decode()
implemented = sorted(re.findall(r'"([^"\n]+)"', re.search(r'public static let implemented: Set<String> = \[(.*?)\]', core_text, re.S)[1]))
catalog_path = 'Source/Otzaria/Actions/Sources/OtzariaActionCore/Resources/action-catalog.v1.json'
catalog = json.loads(read(catalog_path))
catalog_ids = {x['id'] for x in catalog['actions']}
assert set(implemented) <= catalog_ids
descriptor_text = runtime.split('registry = try UIDestinationRegistry(descriptors: [', 1)[1].split('\n        ])', 1)[0]
parts = re.split(r'(?=\.init\(id: id\("native\.)', descriptor_text)
descriptors = {}
for part in parts:
    match = re.search(r'\.init\(id: id\("([^"]+)"\)', part)
    if not match: continue
    name = match[1]
    presentations = re.search(r'presentations: \[([^]]+)\]', part)[1]
    actions = re.search(r'requiredCoreActions: \[([^]]*)\]', part)[1]
    descriptors[name] = {
        'presentations': re.findall(r'\.(\w+)', presentations),
        'required_core_actions': re.findall(r'"([^"]+)"', actions),
        'supported_backends': ['otzaria', 'sefaria', 'sefariaEmbedded'] if 'supportedBackends: ActionBackendID.allCases' in part else [],
        'public_v2_policy': 'publicNavigationV2:' in part,
        'requires_content': 'requiresContent: true' in part,
        'source_anchor': '.init(id: id("' + name + '")',
    }
assert len(descriptors) == 10
binding_tools = sorted(re.findall(r'"([^"]+)"', re.search(r'availableReadActions: \[([^]]*)\]', runtime)[1]))
assert binding_tools == ['catalog.resolveReference', 'catalog.resolveWork', 'system.listBackends']

groups = {
    'native.library': ['tab.library', 'library.catalog', 'native.library'],
    'native.reader.toc': ['toc.contents', 'native.reader.toc'],
    'native.history': ['tab.history', 'history.list', 'native.history'],
    'native.search': ['tab.search', 'native.search', 'search.input-focus'],
    'native.annotations': ['tab.annotations', 'annotations.list', 'native.annotations'],
    'native.settings': ['shell.settings-sheet', 'settings.root', 'native.settings'],
    'native.reader.inspector': ['inspector.panel', 'inspector.sheet', 'native.reader.inspector'],
    'native.reader': ['reader.content', 'reader.viewport', 'native.reader', 'native.reader-new-tab'],
}
mapped = {'inventory.v1.' + ident: dest for dest, ids in groups.items() for ident in ids}
host_only = {
    'inventory.v1.notes.draft': ('native.reader.noteDraft', 'notes.prepareDraft'),
    'inventory.v1.search.global': ('native.search.results', 'search.openResults'),
    'inventory.v1.inspector.related-source': ('native.reader', 'reader.openCommentary'),
}
intent_definitions = {'inventory.v1.native.foreground-intent', 'inventory.v1.native.shortcut', 'inventory.v1.native.reader-intent'}
legacy_links = {'inventory.v1.legacy-link.history', 'inventory.v1.legacy-link.annotation'}
assert set(mapped) | set(host_only) | intent_definitions | legacy_links <= {x['id'] for x in rows}

lock_path = 'Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
pins = json.loads(read(lock_path))['pins']
inspector_pin = next(x['state']['revision'] for x in pins if x['identity'] == 'torahinspectorkit')
entry = git(a.repo, 'ls-tree', source, '--', 'Vendor/SefariaMobile/Upstream').stdout.decode().strip()
embedded_pin = entry.split()[2]
external = [
    ('DependencyObjects/TorahInspectorKit/', Path('C:/Users/DAVID/Code/TorahInspectorKit'), inspector_pin),
    ('Vendor/SefariaMobile/Upstream/', Path(historical['embedded_source']['object_repository']), embedded_pin),
]

def current_anchor(old):
    path = old['path']; repo, ref, object_path = a.repo, source, path
    for prefix, extrepo, pin in external:
        if path.startswith(prefix): repo, ref, object_path = extrepo, pin, path[len(prefix):]
    raw = blob(repo, ref, object_path)
    base = {'path': path, 'repository': str(repo), 'source_ref': ref, 'historical_sha256': old.get('sha256'), 'historical_anchor': old.get('anchor')}
    if raw is None: return {**base, 'status': 'SOURCE_OBJECT_UNAVAILABLE'}
    lines = raw.decode('utf-8', errors='strict').splitlines()
    anchor = old.get('anchor', '')
    matches = [i + 1 for i, line in enumerate(lines) if anchor and anchor in line]
    occurrence = old.get('occurrence', 1)
    return {**base, 'status': 'ANCHOR_PRESENT' if len(matches) >= occurrence else 'HISTORICAL_ANCHOR_MISSING',
            'current_sha256': sha(raw), 'unchanged_file': sha(raw) == old.get('sha256'),
            'matching_lines': matches, 'historical_occurrence': occurrence}

backends = ['otzaria', 'sefaria', 'sefariaEmbedded']
ingresses = ['in_app', 'app_intents', 'urls', 'hanlin', 'guides']
surfaces = []
for row in rows:
    ident = row['id']; action = (row.get('linked_semantic_action') or {}).get('id')
    anchor = current_anchor(row['source'])
    dest = mapped.get(ident) or (host_only.get(ident) or (None,))[0]
    mapping_kind = 'EXACT_ROOT_OR_CANONICAL_READER_SUBSET' if ident in mapped else ('HOST_API_ONLY' if ident in host_only else 'NO_EXACT_DESTINATION_MAPPING')
    statuses = dict.fromkeys(ingresses, 'NOT_EXPOSED_BY_CURRENT_HOST')
    statuses['guides'] = 'NOT_IMPLEMENTED'
    statuses['in_app'] = 'ORIGINAL_UI_SOURCE_ONLY' if anchor['status'] == 'ANCHOR_PRESENT' else 'SOURCE_ANCHOR_UNVERIFIED'
    if ident in mapped:
        statuses['in_app'] = 'SOURCE_WIRED_CONDITIONAL'
        statuses['app_intents'] = 'SOURCE_WIRED_CONDITIONAL'
        statuses['urls'] = 'CUSTOM_SCHEME_ONLY_CONDITIONAL'
        if dest == 'native.reader': statuses['hanlin'] = 'SOURCE_LINK_TRANSITION_ONLY'
    if ident in host_only:
        statuses['in_app'] = 'HOST_API_WIRED_NO_PRODUCTION_CALLER'
    if action in binding_tools and statuses['hanlin'] == 'NOT_EXPOSED_BY_CURRENT_HOST':
        statuses['hanlin'] = 'METADATA_TOOL_ONLY_NO_UI_MAPPING'
    if ident in intent_definitions:
        mapping_kind = 'INGRESS_DEFINITION'
        statuses['app_intents'] = 'SOURCE_WIRED_CONDITIONAL'
    if ident in legacy_links:
        mapping_kind = 'LEGACY_URL_HANDLER'
        statuses['urls'] = 'LEGACY_DELEGATED_NO_REGISTRY_ACK'
    cells = {backend: {ingress: {'source_status': statuses[ingress], 'fresh_runtime': 'NOT_RUN_BY_THIS_AUDIT'} for ingress in ingresses} for backend in backends}
    surfaces.append({'id': ident, 'area': row['area'], 'label': row['screen_section_component'],
                     'current_source': anchor, 'historical_route_status': row.get('route_implementation'),
                     'linked_core_action': action, 'core_implemented_now': action in implemented if action else None,
                     'historical_core_implemented': (row.get('linked_semantic_action') or {}).get('core_v1_implemented'),
                     'destination': dest, 'mapping_kind': mapping_kind,
                     'historical_case_plan_id': row.get('tests', {}).get('case_plan_id'), 'cells': cells})

evidence_paths = [composition, registry, hanlin, catalog_path, lock_path,
    'Source/Otzaria/UIRouting/Sources/OtzariaUIRouting/Registry/UIDestinationRegistry.swift',
    'Source/Otzaria/UIRouting/Sources/OtzariaUIRouting/Resources/catalog-status.json',
    'Source/Otzaria/Actions/Sources/OtzariaActionCore/BackendSemantics/BackendSemanticProfile.swift',
    'Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneBindings.swift',
    'Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneSession.swift',
    'Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneProjection.swift',
    'Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeIntents.swift',
    'Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeURLHandler.swift',
    'Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeDestinationIntents.swift',
    'Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeReaderIntents.swift',
    'Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeSceneNavigationOrchestrator.swift',
    'Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativePublicNavigationURLV2.swift',
    'Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeRouteURL.swift',
    'Source/ChavrusaText/StudyWorkspace/UI/StudyProfileManagementView.swift',
    'Maktabah.xcodeproj/project.pbxproj', 'Source/ChavrusaText-iOS.entitlements']
evidence = {path: {'sha256': sha(read(path)), 'lines': len(read(path).splitlines())} for path in evidence_paths}
summary = {'source_sha': source, 'semantic_rows': len(surfaces), 'unique_ids': len(surfaces),
           'potential_backend_ingress_cells': len(surfaces) * len(backends) * len(ingresses),
           'fresh_runtime_executions': 0, 'fresh_runtime_passes': 0,
           'core_implemented_count': len(implemented), 'composition_descriptor_count': len(descriptors),
           'source_anchor_statuses': dict(collections.Counter(x['current_source']['status'] for x in surfaces)),
           'mapping_kinds': dict(collections.Counter(x['mapping_kind'] for x in surfaces)),
           'per_ingress_source_statuses': {ingress: dict(collections.Counter(x['cells']['otzaria'][ingress]['source_status'] for x in surfaces)) for ingress in ingresses}}
report = {'schema_version': 1, 'source_sha': source, 'boundary': 'Source implementation coverage only, not runtime availability or Native acceptance. Potential cells are not executed tests. Current source presence never upgrades a historical result.',
    'historical_inputs': {historical_path: {'sha256': sha(read(historical_path)), 'actual_rows': len(rows), 'source_sha': historical['source_sha']},
                          prior_path: {'sha256': sha(read(prior_path)), 'actual_rows': len(prior['semantic_surfaces'])},
                          old_report_path: {'sha256': sha(read(old_report_path)), 'declared_rows': old_report['semantic_surfaces']}},
    'count_reconciliation': {'retained_base': 227, 'visible_cancel': 1, 'native_search': 54, 'native_contract_rows': 12, 'total': 294,
                             'unsubstantiated_292_not_used': True, 'historical_files_unchanged': True},
    'backends': backends, 'ingresses': ingresses, 'core_implemented_actions': implemented,
    'core_catalog_actions_not_implemented': sorted(catalog_ids - set(implemented)),
    'composition_descriptors': descriptors, 'production_hanlin_read_actions': binding_tools,
    'backend_conditions': {'otzaria': 'Active exact backend generation; original local catalog/reference/index readiness and live native owner.',
        'sefaria': 'Active exact generation; source-backed references; search requires network readiness; no implicit backend switch.',
        'sefariaEmbedded': 'Active exact generation/RPC epoch; host and embedded catalog readiness; search requires embedded search plus response-fidelity evidence.'},
    'crosscutting_gates': {'iOS26': 'BLOCKED_BY_CURRENT_APP_DEPLOYMENT_27_0', 'iOS27': 'SOURCE_TARGET_ONLY_NATIVE_NOT_EXECUTED_HERE',
        'universal_links': 'NO_ASSOCIATED_DOMAINS_IN_INSPECTED_IOS_ENTITLEMENTS_AASA_NOT_PROVISIONED_BY_THIS_AUDIT',
        'remote_MCP': 'NO_PAIRED_ACTIVE_HOST_EXECUTION_ESTABLISHED', 'guides': 'NO_PRODUCT_WORKFLOW_RUNNER_ESTABLISHED',
        'physical_iPad': 'NOT_RUN', 'real_model_journeys': 'NOT_RUN', 'live_backend_matrix': 'NOT_RUN'},
    'source_evidence': evidence, 'external_source_pins': {'TorahInspectorKit': inspector_pin, 'SefariaMobile': embedded_pin},
    'summary': summary, 'surfaces': surfaces}
a.output.parent.mkdir(parents=True, exist_ok=True)
a.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
print(json.dumps({'output': str(a.output), 'sha256': sha(a.output.read_bytes()), **summary}, ensure_ascii=False))
