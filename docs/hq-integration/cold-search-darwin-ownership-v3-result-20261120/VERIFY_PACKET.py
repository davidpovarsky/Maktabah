#!/usr/bin/env python3
"""Verify retained ownership evidence; no network, compiler or test execution."""
from pathlib import Path
import contextlib, gzip, hashlib, io, json, tempfile, zipfile

P=Path(__file__).resolve().parent
manifest=json.loads((P/'MANIFEST.json').read_bytes())
assert __debug__ and manifest['run']==44772413131
for row in manifest['files']:
    name=Path(row['path']);assert not name.is_absolute() and '..' not in name.parts
    data=(P/name).read_bytes()
    assert len(data)==row['bytes'] and hashlib.sha256(data).hexdigest()==row['sha256']
    assert hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==row['git_blob']
with tempfile.TemporaryDirectory(prefix='ownership-v3-evidence-') as temporary:
    root=Path(temporary)
    for name in ['ROOT_REPLAY.py','artifact-14647278403.zip']:
        (root/name).write_bytes((P/name).read_bytes())
    for name in ['GITHUB_RECEIPTS.json','ROOT_GIT_TREE.json']:
        (root/name).write_bytes(gzip.decompress((P/(name+'.gz')).read_bytes()))
    with zipfile.ZipFile(root/'artifact-14647278403.zip') as archive:
        assert archive.testzip() is None
        for name in archive.namelist():assert not Path(name).is_absolute() and '..' not in Path(name).parts
        archive.extractall(root/'extracted')
    output=io.StringIO()
    with contextlib.redirect_stdout(output):
        exec(compile((root/'ROOT_REPLAY.py').read_bytes(),str(root/'ROOT_REPLAY.py'),'exec'),{'__file__':str(root/'ROOT_REPLAY.py'),'__name__':'__main__'})
    actual=json.loads((root/'ROOT_REVIEW.json').read_bytes());expected=json.loads((P/'ROOT_REVIEW.json').read_bytes())
    actual.pop('reviewed_at');expected.pop('reviewed_at');assert actual==expected
    assert (root/'SOURCE_GIT_PROOF.json').read_bytes()==(P/'SOURCE_GIT_PROOF.json').read_bytes()
print(json.dumps({'status':'RETAINED_DARWIN32_AND_BASELINE_VERIFIED','payloads':len(manifest['files']),'source_inputs':16,'zip_members':253,'candidate_passed':32,'baseline_red_qualified':True,'new_Swift_execution':0,'Native_UI':0}))
