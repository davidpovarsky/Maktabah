from pathlib import Path
import datetime,hashlib,importlib.util,json,tempfile,zipfile
P=Path(__file__).resolve().parent
def sha(b):return hashlib.sha256(b).hexdigest()
def read(p):return json.loads(p.read_text())
def unpack(path,dest):
    with zipfile.ZipFile(path) as z:
        assert z.testzip() is None
        assert len(z.namelist())==len(set(z.namelist()))
        for i in z.infolist():
            q=Path(i.filename)
            assert not q.is_absolute() and '..' not in q.parts
            if i.is_dir():continue
            out=dest/q;out.parent.mkdir(parents=True,exist_ok=True);out.write_bytes(z.read(i))
manifest=read(P/'MANIFEST.json')
for entry in manifest['files']:
    b=(P/entry['path']).read_bytes()
    assert len(b)==entry['bytes'] and sha(b)==entry['sha256'],entry['path']
artifact=read(P/'ARTIFACT_METADATA.json')
run=read(P/'WORKFLOW_RUN.json')
assert run['id']==44743177022 and run['run_attempt']==1 and run['status']=='completed' and run['conclusion']=='success'
assert run['head_sha']=='ce56baedf0fec15f61a117e5649e8c6865781120'
assert artifact['id']==14634164383 and artifact['size_in_bytes']==59956
assert artifact['workflow_run']['id']==run['id'] and artifact['workflow_run']['head_sha']==run['head_sha']
zb=(P/'ORIGINAL_ARTIFACT.zip').read_bytes()
assert len(zb)==59956 and sha(zb)=='7fc1d299c61bf9d34eb8674cf4b262f880a7189b9b0de4171d49fc66f6ad94d7'
assert artifact['digest']=='sha256:'+sha(zb)
with tempfile.TemporaryDirectory(prefix='otzaria-apple55-evidence-') as temporary:
    t=Path(temporary);unpack(P/'ORIGINAL_ARTIFACT.zip',t/'artifact');unpack(P/'CANONICAL_SOURCE_CLOSURE.zip',t/'source')
    for m in read(P/'ZIP_MEMBERS.json')['members']:
        b=(t/'artifact'/m['path']).read_bytes()
        assert len(b)==m['bytes'] and sha(b)==m['sha256']
    e=t/'artifact/artifacts/sefaria-toc-apple55'
    sources=read(e/'SOURCE_INPUTS.json')
    assert len(sources)==13
    for p,m in sources.items():
        b=(t/'source'/p).read_bytes()
        assert len(b)==m['bytes'] and sha(b)==m['sha256'] and m['gitBlobExact'] is True
    for m in read(e/'RAW_INDEX.json'):
        b=(e/'raw'/m['path']).read_bytes()
        assert len(b)==m['bytes'] and sha(b)==m['sha256']
    spec=importlib.util.spec_from_file_location('original_apple55_gate',t/'source/Scripts/CI/sefaria-toc-apple55.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    result=module.verify_driver_result(e/'raw',sources)
    pairs=[]
    for mode,names in read(e/'raw/CASES_EXPECTED.json').items():
        rows=read(e/'raw'/mode/'CASES.json')
        assert rows==read(e/'raw'/mode/'runtime.stdout.log')
        assert (e/'raw'/mode/'runtime.stderr.log').read_bytes()==b''
        pairs.extend((mode,row['name']) for row in rows)
    assert len(pairs)==len(set(pairs))==55
    outer=read(e/'RESULT.json')
    assert outer['driverResult']==result and outer['expectedSHA']==run['head_sha']
    assert outer['status']=='APPLE_FOUNDATION_55_PASS' and result['executed']==result['passed']==55
    assert outer['host']['platform']=='darwin' and outer['host']['machine']=='arm64'
    for key in ['native','iPadSDK','realNetwork','embeddedHermes','physicalOffline']:
        assert outer[key]=='NOT_RUN'
print(json.dumps({'status':'VERIFIED_APPLE_FOUNDATION_55_PASS','source':run['head_sha'],'cases':55,'source_inputs':13,'new_test_executions':0,'Native_UI':'NOT_RUN'}))

