from pathlib import Path
import hashlib, json, re, subprocess, tempfile

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/hq-ui-routing'
def log(name):
    data = (OUT / name).read_bytes()
    text = data.decode('utf-8-sig', errors='replace')
    rows = re.findall(r'Executed (\d+) tests?, with (\d+) failures?', text)
    return {'file': name, 'sha256': hashlib.sha256(data).hexdigest(),
        'xctest_final': {'methods': int(rows[-1][0]), 'failures': int(rows[-1][1])} if rows else None,
        'compiler_warnings': len(re.findall(r'warning:', text)), 'compiler_errors': len(re.findall(r':\d+:\d+: error:', text))}
def write(name, obj):
    (OUT / name).write_text(json.dumps(obj, indent=2) + '\n', encoding='utf-8')
future = {'status': 'PORTABLE_JOINT_SOURCE_CANDIDATE_NATIVE_HOLD',
    'joint_source': '98e6c7b94fd5e4c06b83cdda57cd6c9d9f41db6e',
    'N_fix': 'd9310293444c6fe9b49739c83d5b2d145960b3c0', 'P_core': '050031fac1bb21f738048beb8b5d011d5d0a6b4d',
    'logs': [log(p) for p in ['N-detached-owner-before.log', 'N-detached-owner-after.log', 'N-detached-owner-full-before-P-joint.log', 'N-detached-owner-joint-full.log', 'N-detached-joint-P-review.log']],
    'scope': '84 actual Host XCTest methods; 2 separate unchanged P review methods in an isolated committed snapshot; synthetic native drivers and controlled clock. Not 86 product cases.',
    'limits': ['Portable Windows Swift6.3.3 only', 'No actual native/SDK/device run', 'Relative Core deadline alone is not the original absolute deadline', 'Finite synchronous observations do not certify arbitrary mutually mutating callbacks', 'Future v2/content/newTab/producer observer inactive']}
assert [(x['xctest_final']['methods'], x['xctest_final']['failures']) for x in future['logs']] == [(4,22),(4,0),(84,0),(84,0),(2,0)]
assert all(x['compiler_warnings'] == 0 and x['compiler_errors'] == 0 for x in future['logs'])
write('N-detached-owner-joint-report.json', future)
baseline = 'fca92176d48017ee0cd22831a1ae31f40958eed9'
paths = ['Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeSceneNavigationOrchestrator.swift',
    'Source/ChavrusaText/UIRoutingHost/Tests/ChavrusaUIRoutingHostTests/NativeSceneNavigationOrchestratorTests.swift']
with tempfile.TemporaryDirectory(prefix='nv1check-', dir='C:/Users/DAVID/.codex/tmp') as tmp:
    for path in paths:
        dest = Path(tmp) / path; dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(subprocess.check_output(['git', 'show', f'{baseline}:{path}'], cwd=ROOT))
    result = subprocess.run(['git', 'apply', '--check', str(OUT / 'N_V1_FCA_POST_GUARD_DRIVER_TOKEN_UNAPPLIED.diff'), str(OUT / 'N_V1_FCA_REGRESSION_UNAPPLIED.diff')], cwd=tmp, capture_output=True, text=True)
    check = {'exit': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr}
    assert result.returncode == 0, check
backport = {'status': 'EXACT_V1_BASELINE_PORTABLE_BACKPORT_UNAPPLIED_TO_MANAGER', 'base': baseline,
    'production_patch': 'N_V1_FCA_POST_GUARD_DRIVER_TOKEN_UNAPPLIED.diff', 'test_patch': 'N_V1_FCA_REGRESSION_UNAPPLIED.diff',
    'applicability_original_baseline': check,
    'logs': [log(p) for p in ['N-v1-fca-detached-before.log', 'N-v1-fca-detached-after.log', 'N-v1-fca-detached-full.log']],
    'scope': 'Original public v1 commit API only; 3 backends x 3 owner changes in 1 method. Full58 includes baseline57.',
    'native_sdk': 'NOT_RUN', 'P_core_backport': 'SEPARATE_P_OWNERSHIP', 'manager_sources_modified': False}
assert [(x['xctest_final']['methods'], x['xctest_final']['failures']) for x in backport['logs']] == [(1,18),(1,0),(58,0)]
assert all(x['compiler_warnings'] == 0 and x['compiler_errors'] == 0 for x in backport['logs'])
write('N-v1-fca-report.json', backport)
print('Finalized future84 + separateP2 and separate current-v1 RED18 / GREEN58 evidence; exact patches check clean.')
