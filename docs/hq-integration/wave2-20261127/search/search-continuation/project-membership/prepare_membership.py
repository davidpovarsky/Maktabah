#!/usr/bin/env python3
"""Prepare a local-only, exact-base Xcode membership proposal.

This reuses the repository's unchanged OpenStep parser. It does not run Xcode,
compile Swift, mutate an integration checkout, or claim native qualification.
"""
from copy import deepcopy
import difflib
import hashlib
import json
from pathlib import Path
import re
import runpy

ROOT = Path(__file__).resolve().parent
PROJECT = 'Maktabah.xcodeproj/project.pbxproj'
BASE = '15d283aa0ccbbfe6966f26a2c182810cb39fdafa'
BASE_SHA256 = 'db527467c59ac351b1db13b7208fe4f7f89da089916978302c2d55e68b42b2ee'
PARSER_SHA256 = 'eff5cf3c0935562f9e9b1bbcd296f192c4daf2922cc9185d8fa5ad0ab3246a18'
GROUP = 'CFEE00000000000000000001'
ALL_APPS = ['Maktabah', 'Maktabah-Direct', 'Maktabah-iOS']
SOURCES = [
    ('Source/ChavrusaText/SearchContinuation/OriginalSearchPageLedger.swift', ALL_APPS,
     ROOT.parent / 'search-page-ledger/candidate/Source/ChavrusaText/SearchContinuation/OriginalSearchPageLedger.swift'),
    ('Source/ChavrusaText/SearchContinuation/OriginalSearchContinuationClaim.swift', ['Maktabah-iOS'],
     ROOT.parent / 'search-intent-continuation/candidate/Source/ChavrusaText/SearchContinuation/OriginalSearchContinuationClaim.swift'),
    ('Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSearchContinuation.swift', ['Maktabah-iOS'],
     ROOT.parent / 'search-intent-continuation/candidate/Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSearchContinuation.swift'),
]
CALLERS = [
    'Source/Otzaria/Search/OtzariaTextSearchViewModel.swift',
    'Vendor/ZayitSearchPort/Swift/ZayitSearchViewModel.swift',
    'Source/Features/Search/ViewModel/SearchViewModel.swift',
    'Source/Features/Search/ViewModel/Extensions/Search+Execution.swift',
    'Source/ZayitSearch/UnifiedSearchSessionController.swift',
    'Source/Features/Search/iOS/SearchResultsListView.swift',
    'Source/Features/Search/iOS/SearchModeView.swift',
    'Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSearchEntry.swift',
    'Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneBindings.swift',
]


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def read_stable(path):
    assert path.is_file() and not path.is_symlink(), path
    before = path.stat()
    raw = path.read_bytes()
    after = path.stat()
    assert (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) == (
        after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns)
    return raw


def main():
    original = read_stable(ROOT / 'original' / PROJECT)
    assert sha(original) == BASE_SHA256
    text = original.decode('utf-8')
    parser_path = ROOT / 'original-tools/verify_source_registration.py'
    assert sha(read_stable(parser_path)) == PARSER_SHA256
    parser = runpy.run_path(str(parser_path))
    project, inherited_duplicates = parser['parse'](text)
    objects = project['objects']
    phases = parser['target_sources'](project)
    assert objects[GROUP]['isa'] == 'PBXGroup' and objects[GROUP]['path'] == 'ChavrusaText'

    # Resolve actual project group paths, rather than qualifying a basename.
    resolved = {}
    def walk(identifier, parent, ancestors=()):
        assert identifier not in ancestors, ('group cycle', identifier)
        value = objects[identifier]
        tree = value.get('sourceTree', '<group>')
        path = value.get('path', '')
        if tree == 'SOURCE_ROOT': full = Path(path)
        elif tree == '<group>': full = parent / path
        else: return  # SDK/framework roots are not app-source membership.
        if value['isa'] == 'PBXFileReference':
            resolved.setdefault(identifier, set()).add(full.as_posix())
        elif value['isa'] == 'PBXGroup':
            for child in value.get('children', []):
                walk(child, full, ancestors + (identifier,))
    walk(objects[project['rootObject']]['mainGroup'], Path())

    caller_mapping = []
    for path in CALLERS:
        refs = [identifier for identifier, paths in resolved.items() if path in paths]
        assert len(refs) == 1, (path, refs)
        ref = refs[0]
        builds = {identifier for identifier, item in objects.items() if item.get('fileRef') == ref}
        targets = {name: [identifier for identifier in files if identifier in builds]
                   for name, (_, files) in phases.items() if any(identifier in builds for identifier in files)}
        caller_mapping.append({'path': path, 'fileReferenceID': ref, 'targets': targets})
    by_caller = {item['path']: set(item['targets']) for item in caller_mapping}
    assert by_caller[CALLERS[2]] == by_caller[CALLERS[3]] == set(ALL_APPS)
    assert all(by_caller[path] == {'Maktabah-iOS'} for path in [CALLERS[0], CALLERS[1], *CALLERS[4:]])

    new_objects = {}
    source_records = []
    def identifier(kind, path, target=''):
        value = sha(('otzaria-wave2-search-membership-20261127|' + kind + '|' + path + '|' + target).encode())[:24].upper()
        assert value not in text and value not in new_objects
        return value

    for path, targets, delivered in SOURCES:
        assert not any(path in paths for paths in resolved.values()), path
        raw = read_stable(delivered)
        relative = str(Path(path).relative_to('Source/ChavrusaText'))
        name = Path(path).name
        ref = identifier('file-reference', path)
        new_objects[ref] = {'isa': 'PBXFileReference', 'lastKnownFileType': 'sourcecode.swift',
                            'path': relative, 'sourceTree': '<group>'}
        builds = {}
        for target in targets:
            build = identifier('build-file', path, target)
            new_objects[build] = {'isa': 'PBXBuildFile', 'fileRef': ref}
            builds[target] = build
        source_records.append({'path': path, 'name': name, 'fileReferenceID': ref,
                               'relativeGroupPath': relative, 'buildFileIDsByTarget': builds,
                               'observedDeliveredSource': {'path': str(delivered), 'bytes': len(raw), 'sha256': sha(raw)}})
    assert len(new_objects) == 8
    assert read_stable(SOURCES[2][2]).startswith(b'#if os(iOS)\n')

    inserts = []
    def add(offset, content, purpose):
        assert content not in text
        inserts.append({'offset': offset, 'content': content, 'purpose': purpose})
    build_lines, ref_lines = [], []
    for item in source_records:
        name, ref = item['name'], item['fileReferenceID']
        for target, build in item['buildFileIDsByTarget'].items():
            build_lines.append(f'\t\t{build} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};\n')
        ref_lines.append(f'\t\t{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {item["relativeGroupPath"]}; sourceTree = "<group>"; }};\n')
    add(text.index('/* End PBXBuildFile section */'), ''.join(build_lines), 'Five new target build-file objects')
    add(text.index('/* End PBXFileReference section */'), ''.join(ref_lines), 'Three new file-reference objects')

    def list_end(object_id, field):
        match = re.search(r'(?m)^\t\t' + object_id + r'(?: /\*[^\n]*?\*/)? = \{\n', text)
        assert match, object_id
        end = text.index('\n\t\t};', match.end())
        block = text[match.start():end]
        listing = re.search(r'(?m)^\t\t\t' + field + r' = \(\n[\s\S]*?(^\t\t\t\);)', block)
        assert listing, (object_id, field)
        return match.start() + listing.start(1)

    add(list_end(GROUP, 'children'), ''.join(f'\t\t\t\t{x["fileReferenceID"]} /* {x["name"]} */,\n' for x in source_records), 'Append three ChavrusaText children')
    for target in ALL_APPS:
        lines = ''.join(f'\t\t\t\t{x["buildFileIDsByTarget"][target]} /* {x["name"]} in Sources */,\n' for x in source_records if target in x['buildFileIDsByTarget'])
        add(list_end(phases[target][0], 'files'), lines, 'Append source membership for ' + target)

    candidate = text
    for insertion in sorted(inserts, key=lambda x: x['offset'], reverse=True):
        candidate = candidate[:insertion['offset']] + insertion['content'] + candidate[insertion['offset']:]
    recovered = candidate
    for insertion in inserts:
        assert recovered.count(insertion['content']) == 1
        recovered = recovered.replace(insertion['content'], '', 1)
    assert recovered.encode() == original, 'changed bytes outside the six insertions'

    after, duplicates = parser['parse'](candidate)
    assert duplicates == inherited_duplicates
    expected = deepcopy(project)
    expected['objects'].update(new_objects)
    expected['objects'][GROUP]['children'] += [item['fileReferenceID'] for item in source_records]
    for target in ALL_APPS:
        expected['objects'][phases[target][0]]['files'] += [item['buildFileIDsByTarget'][target] for item in source_records if target in item['buildFileIDsByTarget']]
    assert after == expected, 'project graph differs from the explicit additive projection'
    new_phases = parser['target_sources'](after)
    for item in source_records:
        actual = {target: [x for x in files if x in item['buildFileIDsByTarget'].values()]
                  for target, (_, files) in new_phases.items() if any(x in item['buildFileIDsByTarget'].values() for x in files)}
        assert actual == {target: [identifier] for target, identifier in item['buildFileIDsByTarget'].items()}
    assert set(after['objects']) - set(objects) == set(new_objects)
    changed = sorted(key for key in objects if objects[key] != after['objects'][key])
    assert set(changed) == {GROUP, *(phases[target][0] for target in ALL_APPS)}

    output = ROOT / 'proposal' / PROJECT
    output.parent.mkdir(parents=True, exist_ok=True)
    assert not output.exists()
    output.write_text(candidate)
    patch = ''.join(difflib.unified_diff(text.splitlines(keepends=True), candidate.splitlines(keepends=True),
                                       fromfile='a/' + PROJECT, tofile='b/' + PROJECT))
    (ROOT / 'membership.patch').write_text(patch)
    report = {
        'schema': 1, 'status': 'REVIEWABLE_PATCH_ONLY_NOT_APPLIED',
        'verificationScope': 'Unchanged original OpenStep parser plus exact additive graph and byte-preservation checks only; no Xcode, Swift build, linkage or UI',
        'baselineCommit': BASE, 'projectPath': PROJECT,
        'baselineBlob': '24ab48b84d61fe4bae88eb41c53506664db44701',
        'baseline': {'bytes': len(original), 'sha256': sha(original)},
        'candidate': {'bytes': len(candidate.encode()), 'sha256': sha(candidate.encode())},
        'patch': {'bytes': len(patch.encode()), 'sha256': sha(patch.encode())},
        'parser': {'repositoryPath': 'docs/hq-integration/verify_source_registration.py', 'sha256': PARSER_SHA256},
        'newSources': source_records, 'existingCallerMemberships': caller_mapping,
        'targets': {name: {'sourcePhaseID': phase, 'before': len(files), 'after': len(new_phases[name][1])} for name, (phase, files) in phases.items()},
        'addedObjects': new_objects, 'modifiedExistingObjects': changed,
        'inheritedDuplicateKeysUnchanged': inherited_duplicates,
        'allOtherOriginalBytesPreserved': True,
        'unmodifiedAreas': ['build configurations', 'SDK/platform settings', 'package references', 'frameworks', 'resources', 'shell phases', 'existing source order', 'existing object definitions', 'test targets', 'widget target'],
        'swiftPMOnlySourcesNotRegisteredInApp': [
            'Source/Otzaria/Actions/Sources/OtzariaActionCore/Contracts/ActionSearchContinuation.swift',
            'Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeSearchContinuationService.swift'],
        'ownerApplicationRequired': True,
        'oracleDataWrites': False, 'integrationWorktreeOrRefChanges': False, 'sourceCodeChanges': False,
    }
    (ROOT / 'MEMBERSHIP_MANIFEST.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    (ROOT / 'INSERTIONS.json').write_text(json.dumps(inserts, indent=2, sort_keys=True) + '\n')
    print(json.dumps({'status': report['status'], 'candidate': report['candidate'], 'patch': report['patch'],
                      'addedObjects': len(new_objects), 'modifiedExistingObjects': changed,
                      'targetMapping': {item['path']: list(item['buildFileIDsByTarget']) for item in source_records}}, indent=2))


if __name__ == '__main__':
    main()
