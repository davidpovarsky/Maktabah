"""Consume minimal immutable P current-v1 input in isolated N v1 archive."""
from pathlib import Path
import hashlib, json, subprocess
ROOT = Path(__file__).resolve().parents[2]
DEST = Path('C:/Users/DAVID/.codex/tmp/n-v1-fca92176-inputs')
P = '9fadde58093d352fa2fa8b7cc18d07904382e880'
BASE = 'fca92176d48017ee0cd22831a1ae31f40958eed9'
assert subprocess.check_output(['git', 'rev-parse', P + '^'], cwd=ROOT, text=True).strip() == BASE
paths = subprocess.check_output(['git', 'diff-tree', '--no-commit-id', '--name-only', '-r', P], cwd=ROOT, text=True).splitlines()
assert paths == ['Source/Otzaria/Actions/Sources/OtzariaActionCore/Ports/ActionNavigationAuthority.swift',
    'Source/Otzaria/UIRouting/Tests/OtzariaUIRoutingTests/Ports/NavigationAuthorizationTests.swift']
report = {'base': BASE, 'P_minimal_commit': P, 'P_inputs': {}, 'scope': 'Existing fca public v1 plus N7-line preapply patch and separate P two-path current-Core patch only; no future dependencies.'}
for path in paths:
    data = subprocess.check_output(['git', 'show', f'{P}:{path}'], cwd=ROOT)
    (DEST / path).write_bytes(data)
    report['P_inputs'][path] = {'sha256': hashlib.sha256(data).hexdigest(), 'git_blob': subprocess.check_output(['git', 'rev-parse', f'{P}:{path}'], cwd=ROOT, text=True).strip()}
assert report['P_inputs'][paths[0]]['git_blob'] == 'fbe9db5962dde66685d272231d77e6257640ae54'
report['joint_inputs_sha256'] = {p.relative_to(DEST).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(DEST.rglob('*')) if p.is_file()}
(ROOT / 'docs/hq-ui-routing/N-v1-fca-P9f-pair-inputs.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print('Prepared minimal current-v1 N/P pair; exact P production blob verified.')
