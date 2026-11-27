from pathlib import Path
import base64, gzip, hashlib, json, sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = HERE / 'inputs'
OUT.mkdir(exist_ok=True)
pins = []
sha = lambda b: hashlib.sha256(b).hexdigest()

def record(path, target, transform=None, scope='actual production source'):
    raw = path.read_bytes()
    value = raw if transform is None else transform(raw.decode()).encode()
    p = OUT / target
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(value)
    pins.append({'path': str(path.relative_to(ROOT)), 'sourceBytes': len(raw), 'sourceSHA256': sha(raw),
        'compiledPath': target, 'compiledBytes': len(value), 'compiledSHA256': sha(value), 'scope': scope})

def content(s):
    return (s[:s.index('    func fetchBookInfo(')] + '}\n').replace('import OSLog\n', '')

def publisher(s):
    start = s.index('    func updateContentState(with content: BookContent')
    end = s.index('\n    #if os(iOS)\n    var availableReaderTextModes:', start)
    body = s[start:end].replace('#if os(iOS)', '#if PUBLISHER_IOS').replace('#if os(macOS)', '#if PUBLISHER_MACOS')
    return 'import Foundation\nextension ReaderViewModel {\n' + body + '}\n'

first = ROOT / 'evidence/attempt-1/raw/inputs/candidate'
for variant, base in [('before', first), ('candidate', ROOT / 'candidate')]:
    for name in ['ReaderContentLoadCoordinator.swift', 'ReaderInitialContentRequest.swift']:
        record(base / ('Source/ChavrusaText/Navigation/' + name), variant + '/' + name)
    record(base / 'Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift', variant + '/Reader+Content.swift', content)
    record(base / 'Source/Features/Reader/ViewModel/ReaderViewModel.swift', variant + '/ActualPublisher.swift', publisher)
for name in ['LibraryBackendModels.swift', 'ReaderDestinationResolver.swift']:
    record(ROOT / ('evidence/attempt-1/raw/inputs/compiled/common/' + name), 'common/' + name)
for name in ['Boundary.swift', 'Controls.swift']:
    record(HERE / name, 'common/' + name, scope='explicit domain/backend/platform-state control boundary')
manifest = {'files': pins,
    'scope': 'Exact complete updateContentState body and cold Reader functions/coordinator/request, with explicit original conditional selection and domain/backend/ReaderState shells. Not an app, renderer, Apple SDK or native test.',
    'transformations': ['Extract the whole updateContentState function and wrap in ReaderViewModel extension.',
        'Select original iOS or macOS conditional bodies with PUBLISHER_IOS / PUBLISHER_MACOS on Linux; no body substitution.',
        'Cold content prefix omits only OSLog import and unrelated fetchBookInfo/macOS archive tail, as in preserved first35 controls.'],
    'before': 'Exact first draft fadc9772 and original publisher edbd1574; preserve initial35 results as separate limited evidence.'}
(OUT / 'SOURCE_INPUTS.json').write_text(json.dumps(manifest, indent=2) + '\n')

files = []
def add(path, target):
    b = path.read_bytes()
    files.append({'path': target, 'bytes': len(b), 'sha256': sha(b), 'gzipBase64': base64.b64encode(gzip.compress(b, mtime=0)).decode()})
for p in sorted(OUT.rglob('*')):
    if p.is_file(): add(p, 'compiled/' + str(p.relative_to(OUT)))
for variant, base in [('before', first), ('candidate', ROOT / 'candidate')]:
    for p in sorted(base.rglob('*.swift')):
        add(p, variant + '/' + str(p.relative_to(base)))
add(ROOT/'proposal/SESSION.swift', 'proposal/SESSION.swift')
add(ROOT/'proposal/SESSION_EDITS.json', 'proposal/SESSION_EDITS.json')
originals = json.loads((ROOT / 'evidence/attempt-1/raw/RESULT.json').read_text())['sourceJoins']
payload = {'files': files, 'originals': originals}
encoded = base64.b64encode(gzip.compress(json.dumps(payload).encode(), mtime=0)).decode()
attempt = int(sys.argv[1]) if len(sys.argv) > 1 else 1
runner = (HERE / 'run.py').read_text().replace("attempt=SCOPE/'publisher-followup-attempt-1'", "attempt=SCOPE/'publisher-followup-attempt-%d'" % attempt)
target = HERE / ('runner-attempt-%d.py' % attempt)
assert not target.exists(), 'Preserve every prior attempted runner'
target.write_text('PAYLOAD_B64=' + repr(encoded) + '\n' + runner)
print(json.dumps({'inputs': len(files), 'runnerBytes': target.stat().st_size,
    'runnerSHA256': sha(target.read_bytes())}))
