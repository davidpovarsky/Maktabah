#!/usr/bin/env python3
"""Compile actual original witness bodies over declared geometry boundaries."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess


def method(source, signature):
    start = source.index(signature)
    opening = source.index('{', start)
    depth, quote, escape = 0, False, False
    for i in range(opening, len(source)):
        c = source[i]
        if quote:
            if escape:
                escape = False
            elif c == '\\':
                escape = True
            elif c == '"':
                quote = False
        elif c == '"':
            quote = True
        elif c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return source[start:i + 1]
    raise ValueError(signature)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--source-root', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--module-cache', type=Path, required=True)
    args = p.parse_args()
    root, out = args.source_root, args.output
    assert not out.exists()
    assert shutil.disk_usage(root).free >= 987865856
    out.mkdir(parents=True)
    paths = [root / 'Source/SefariaEmbedded/UI/SefariaEmbeddedNativeSurfaceHost.swift',
             root / 'Source/SefariaEmbedded/UI/SefariaEmbeddedSemanticNavigation.swift',
             root / 'Source/SefariaEmbedded/UI/SefariaEmbeddedSurfaceContract.swift',
             root / 'tools/test_sefaria_semantic_geometry.swift', Path(__file__)]
    texts = [x.read_text() for x in paths]
    captured = out / 'source-inputs'; captured.mkdir()
    for path in paths:
        (captured / path.name).write_bytes(path.read_bytes())
    host, semantic, contract, template = texts[:4]
    structs_start = host.index('    struct Evidence:')
    structs = host[structs_start:host.index('    let identity:', structs_start)]
    assert 'struct Evidence:' in structs and 'struct SemanticEvidence:' in structs
    signatures = ['    func evidence()', '    func semanticEvidence(', '    private func visibleOriginalText(']
    methods = [method(host, s) for s in signatures]
    target = method(semantic, 'enum SefariaEmbeddedSemanticTarget:')
    identity = method(contract, 'struct SefariaEmbeddedSurfaceIdentity:')
    assert template.count('__ACTUAL_EVIDENCE_TYPES__') == template.count('__ACTUAL_EVIDENCE_METHODS__') == 1
    actual = 'import Foundation\n' + target + '\n' + identity + '\n' + template.replace('__ACTUAL_EVIDENCE_TYPES__', structs).replace('__ACTUAL_EVIDENCE_METHODS__', '\n'.join(methods))
    before = 'guard leaves.count == 1, let actual = leaves.first,'
    assert actual.count(before) == 1
    negative = actual.replace(before, 'guard !leaves.isEmpty, let actual = leaves.first,')
    report = {'scope': 'Actual original three geometry methods and target/identity; UIKit boundary, no SDK/native claim',
              'inputs': [{'path': str(x), 'bytes': x.stat().st_size, 'sha256': sha(x.read_bytes())} for x in paths],
              'methods': [{'signature': s, 'sha256': sha(t.encode()), 'body': t} for s, t in zip(signatures, methods)],
              'runs': []}
    (out / 'INPUTS.json').write_text(json.dumps(report, indent=2) + '\n')
    for name, source in [('candidate', actual), ('omit-original-uniqueness', negative)]:
        assert shutil.disk_usage(root).free >= 887865856
        run = out / name; run.mkdir()
        src = run / 'ActualSourceWithControls.swift'; src.write_text(source)
        argv = ['swiftc', '-swift-version', '6', '-strict-concurrency=complete', '-parse-as-library',
                '-module-cache-path', str(args.module_cache), str(src), '-o', str(run / 'controls')]
        with (run / 'compile.stdout').open('wb') as stdout, (run / 'compile.stderr').open('wb') as stderr:
            compile_result = subprocess.run(argv, stdout=stdout, stderr=stderr, timeout=90)
        item = {'name': name, 'compileExit': compile_result.returncode, 'argv': argv, 'sourceSHA256': sha(source.encode())}
        if compile_result.returncode == 0:
            with (run / 'run.stdout.json').open('wb') as stdout, (run / 'run.stderr').open('wb') as stderr:
                result = subprocess.run([str(run / 'controls')], stdout=stdout, stderr=stderr, timeout=30)
            item['runExit'] = result.returncode
            item['result'] = json.loads((run / 'run.stdout.json').read_text())
        item['artifacts'] = [{'path': str(x.relative_to(out)), 'bytes': x.stat().st_size, 'sha256': sha(x.read_bytes())}
                             for x in sorted(run.iterdir()) if x.is_file() and x.name != 'controls']
        report['runs'].append(item)
        (out / 'RESULT.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps({'name': name, 'compileExit': item['compileExit'], 'runExit': item.get('runExit'),
                          'passed': item.get('result', {}).get('passed'), 'failed': item.get('result', {}).get('failed')}), flush=True)
        if compile_result.returncode or (name == 'candidate' and item['runExit'] != 0):
            return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
