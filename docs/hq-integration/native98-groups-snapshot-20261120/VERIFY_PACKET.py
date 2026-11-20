from pathlib import Path
import hashlib,gzip,json,re,difflib
P=Path(__file__).resolve().parent
def sha(b):return hashlib.sha256(b).hexdigest()
def read(p):return json.loads(p.read_bytes())
manifest=read(P/'MANIFEST.json')
for item in manifest['files']:
    b=(P/item['path']).read_bytes()
    assert len(b)==item['bytes'] and sha(b)==item['sha256']
raw={}
for item in read(P/'RAW_FILES.json')['files']:
    g=(P/item['stored']).read_bytes()
    assert sha(g)==item['gzip_sha256']
    b=gzip.decompress(g);assert len(b)==item['bytes'] and sha(b)==item['sha256']
    raw[item['original']]=b
base=raw['Faithful.baseline.swift'].decode();candidate=raw['Faithful.candidate.swift'].decode()
assert sha(base.encode())=='a61c37fdb602c466f2e6925f22726feb2c253247007ecaa9ddaf919fba9daeee'
assert sha(candidate.encode())=='76b37e57bb844bf95eb2828a599655f444a7cc2fe25cfc5b51ba58faffed5460'
patch=''.join(difflib.unified_diff(base.splitlines(True),candidate.splitlines(True),fromfile='a/Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift',tofile='b/Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift'))
assert patch.encode()==(P/'PROPOSED.patch').read_bytes()
def span(text,a,b):
    start=text.index(a);return text[start:text.index(b,start)]
restored=candidate
a='@MainActor\nprivate enum GroupStressSnapshot {';b='@MainActor\nprivate final class GroupStressNativeObservation'
helper=span(restored,a,b)
assert '@MainActor\n        func visit' in helper
restored=restored.replace(helper,'',1)
regions=[('@MainActor\nprivate final class GroupStressNativeObservation','@MainActor\nprivate final class GroupStressEvidence'),
('    @MainActor\n    private func selectOriginalStressGroup(named name: String)','    @MainActor\n    private func waitForOriginalGroup(named name: String')]
for a,b in regions:
    restored=restored.replace(span(restored,a,b),span(base,a,b),1)
for line in [
'            let selectionReturnedAt = ProcessInfo.processInfo.systemUptime\n',
'            let observationReturnedAt = ProcessInfo.processInfo.systemUptime\n',
'            observation["automationSelectionElapsedSeconds"] = selectionReturnedAt - start\n',
'            observation["automationObservationElapsedSeconds"] = observationReturnedAt - selectionReturnedAt\n']:
    assert restored.count(line)==1;restored=restored.replace(line,'',1)
assert restored==base
ids=lambda text:re.findall(r'func (test\w+)\(',text)
assert ids(base)==ids(candidate) and len(ids(candidate))==40
old=raw['Faithful.original-M87.swift'].decode()
for a,b in regions:assert span(old,a,b)==span(base,a,b)
review=read(P/'PEER_REVIEW.json')
assert review['candidate_sha256']==sha(candidate.encode()) and review['result']=='NO_CONCRETE_SOURCE_BLOCKER_FOUND'
failure=read(P/'NATIVE_FAILURE_REVIEW.json')
case=raw['ACTUAL_CASE.log']
assert sha(case)==failure['case_sha256'] and len(case)==failure['case_bytes']==161069
assert len(case.decode().splitlines())==failure['case_line_count']==1679
name='testOneHundredConsecutiveOriginalGroupSwitchesPreserveDocumentsAndColdRestore'
lines=case.decode().splitlines()
timeout=next(i for i,l in enumerate(lines) if name in l and 'exceeded execution time allowance of 10 minutes' in l)
pairs=[]
for i,line in enumerate(lines):
    if line.startswith('GROUP_STRESS_OBSERVATION '):
        pairs.append((i>timeout,json.loads(line.removeprefix('GROUP_STRESS_OBSERVATION '))))
assert [x['step'] for after,x in pairs if not after and x['state']=='committed']==list(range(1,29))
assert [x['step'] for after,x in pairs if after and x['state']=='committed']==list(range(29,35))
assert max(x['step'] for _,x in pairs if x['state']=='attempted')==35
print(json.dumps({'status':'SOURCE_AND_RETAINED_FAILURE_VERIFIED','exact_inverse':True,'test_declarations_unchanged':40,'before600_commits':28,'after_timeout_commits':6,'new_tests_executed':0,'Swift_parse':'NOT_RUN','Apple_typecheck':'NOT_RUN','Native':'NOT_RUN'}))

