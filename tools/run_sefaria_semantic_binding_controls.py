#!/usr/bin/env python3
"""Compile COMPLETE actual RN binding and RPC source over explicit boundaries."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from run_sefaria_semantic_geometry_controls import method


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--source-root', type=Path, required=True)
    p.add_argument('--shared-proposal', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--module-cache', type=Path, required=True)
    args = p.parse_args()
    root, shared, out = args.source_root, args.shared_proposal, args.output
    assert not out.exists() and shutil.disk_usage(root).free >= 987865856
    out.mkdir(parents=True)
    paths = {
        'bridge': root / 'Source/SefariaEmbedded/Bridge/SefariaJSRPCBridge.swift',
        'models': root / 'Source/SefariaEmbedded/Bridge/SefariaRPCModels.swift',
        'contract': root / 'Source/SefariaEmbedded/UI/SefariaEmbeddedSurfaceContract.swift',
        'semantic': root / 'Source/SefariaEmbedded/UI/SefariaEmbeddedSemanticNavigation.swift',
        'host': root / 'Source/SefariaEmbedded/UI/SefariaEmbeddedNativeSurfaceHost.swift',
        'binding': root / 'Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSefariaSurfaceBinding.swift',
        'observation': shared / 'Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeComponentSourceObservation.swift',
        'component': shared / 'Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeComponentBinding.swift',
        'owner': shared / 'Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeWorkspaceOwner.swift',
        'boundary': root / 'tools/sefaria_binding_control_boundaries.swift',
        'controls': root / 'tools/test_sefaria_semantic_binding.swift',
        'extractionHelper': root / 'tools/run_sefaria_semantic_geometry_controls.py',
        'runner': Path(__file__),
    }
    texts = {k: x.read_text() for k, x in paths.items()}
    captured = out / 'source-inputs'; captured.mkdir()
    for name, path in paths.items():
        (captured / (name + path.suffix)).write_bytes(path.read_bytes())
    component = method(texts['component'], '@MainActor final class MaktabahNativeComponentSourceObservation')
    owner = texts['owner'].replace('import ChavrusaUIRoutingHost\n', '')
    observation = texts['observation'].replace('import OtzariaUIRouting\n', '')
    semantic = texts['semantic'].replace('import ChavrusaUIRoutingHost\n', '')
    observer = method(texts['host'], '@MainActor protocol SefariaEmbeddedNativeSurfaceObserver:')
    boundary = texts['boundary'].replace('__ACTUAL_HOST_OBSERVER_PROTOCOL__', observer)
    binding = method(texts['binding'], '@MainActor @Observable\nfinal class MaktabahNativeSefariaSurfaceBinding:')
    actual = '\n'.join(['import Foundation\nimport Observation\nimport Synchronization\n',
                         boundary, texts['models'], observation, component, owner, texts['bridge'],
                         texts['contract'], semantic, binding, texts['controls']])
    before = '            ticket.revoke()\n        }\n    }'
    assert actual.count(before) == 1
    negative = actual.replace(before, '            // Counterfactual: removed only synchronous cancellation revocation.\n        }\n    }')
    report = {'scope': 'Complete actual RN binding, RPC actor, retained source/runtime/ticket/lease; explicit platform/domain/receipt boundary, native NOT_RUN',
              'inputs': [{'name': name, 'path': str(x), 'bytes': x.stat().st_size, 'sha256': sha(x.read_bytes())} for name, x in paths.items()],
              'extraction': {'bindingSHA256': sha(binding.encode()), 'componentSHA256': sha(component.encode()),
                             'boundarySHA256': sha(boundary.encode()), 'observerSHA256': sha(observer.encode())}, 'runs': []}
    (out / 'INPUTS.json').write_text(json.dumps(report, indent=2) + '\n')
    for name, source in [('candidate', actual), ('omit-synchronous-cancellation-revoke', negative)]:
        assert shutil.disk_usage(root).free >= 887865856
        run = out / name; run.mkdir()
        src = run / 'ActualSourceWithControls.swift'; src.write_text(source)
        argv = ['swiftc', '-swift-version', '6', '-strict-concurrency=complete', '-parse-as-library',
                '-module-cache-path', str(args.module_cache), str(src), '-o', str(run / 'controls')]
        with (run / 'compile.stdout').open('wb') as stdout, (run / 'compile.stderr').open('wb') as stderr:
            compilation = subprocess.run(argv, stdout=stdout, stderr=stderr, timeout=90)
        item = {'name': name, 'compileExit': compilation.returncode, 'argv': argv, 'sourceSHA256': sha(source.encode())}
        if compilation.returncode == 0:
            with (run / 'run.stdout.json').open('wb') as stdout, (run / 'run.stderr').open('wb') as stderr:
                result = subprocess.run([str(run / 'controls')], stdout=stdout, stderr=stderr, timeout=45)
            item['runExit'] = result.returncode
            item['result'] = json.loads((run / 'run.stdout.json').read_text())
        item['artifacts'] = [{'path': str(x.relative_to(out)), 'bytes': x.stat().st_size, 'sha256': sha(x.read_bytes())}
                             for x in sorted(run.iterdir()) if x.is_file() and x.name != 'controls']
        report['runs'].append(item)
        (out / 'RESULT.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps({'name': name, 'compileExit': item['compileExit'], 'runExit': item.get('runExit'),
                          'passed': item.get('result', {}).get('passed'), 'failed': item.get('result', {}).get('failed')}), flush=True)
        if compilation.returncode or (name == 'candidate' and item['runExit'] != 0):
            return 1
        if name != 'candidate' and item['runExit'] == 0:
            return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
