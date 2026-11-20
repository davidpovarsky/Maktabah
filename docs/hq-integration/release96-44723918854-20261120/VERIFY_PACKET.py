#!/usr/bin/env python3
"""Read-only verification of retained historical evidence; executes no app/tests."""
from pathlib import Path
import collections, gzip, hashlib, json, zipfile, zlib

ROOT = Path(__file__).resolve().parent
def require(ok, message):
    if not ok: raise RuntimeError(message)
def sha(data): return hashlib.sha256(data).hexdigest()
def read(p): return json.loads(p.read_bytes())
manifest = read(ROOT/'ARTIFACTS.json')
expected = {x['path']:x for x in manifest['files']}
actual = {str(p.relative_to(ROOT)) for p in ROOT.rglob('*') if p.is_file() and p.name!='ARTIFACTS.json'}
require(actual==set(expected),'packet file set mismatch')
for rel, item in expected.items():
    data=(ROOT/rel).read_bytes()
    require(len(data)==item['bytes'] and sha(data)==item['sha256'],f'file bytes mismatch: {rel}')
    if rel.endswith('.gz'):
        raw=gzip.decompress(data)
        require(len(raw)==item['uncompressed_bytes'] and sha(raw)==item['uncompressed_sha256'],f'gzip bytes mismatch: {rel}')
review=read(ROOT/'AUTHENTIC_RESULT_REVIEW.json')
run=read(ROOT/'RUN_METADATA.json')
require(run['id']==44723918854 and run['run_attempt']==1 and run['head_sha']=='60a57972acb28739ec738565083bf17fb7503028','run identity')
require(run['status']=='completed' and run['conclusion']=='failure','historical result changed')
api_artifacts={x['id']:x for x in read(ROOT/'ARTIFACTS_METADATA.json')['artifacts']}
for artifact, count in [(14647558906,59),(14626257677,82)]:
    p=ROOT/f'raw/artifact-{artifact}.zip'; data=p.read_bytes(); api=api_artifacts[artifact]
    proof=read(ROOT/f'VERIFICATION-{artifact}.json')
    require(len(data)==proof['archiveBytes']==api['size_in_bytes'],'ZIP size')
    require(sha(data)==proof['archiveSha256']==api['digest'].removeprefix('sha256:'),'ZIP digest')
    with zipfile.ZipFile(p) as archive:
        entries=archive.infolist(); require(len(entries)==count,'ZIP member count')
        require(archive.testzip() is None,'ZIP CRC failure')
        bound={x['path']:x for x in proof['entries']}
        require(len(bound)==count and set(bound)==set(archive.namelist()),'ZIP member set')
        for entry in entries:
            raw=archive.read(entry); item=bound[entry.filename]
            require(len(raw)==item['bytes'] and sha(raw)==item['sha256'],'ZIP member bytes')
            require(format(zlib.crc32(raw)&0xffffffff,'08x')==item['crc32'],'ZIP member CRC')
        if artifact==14647558906:
            nodes=json.loads(archive.read('runtime27/verified-11.tests.json'))
            summary=json.loads(archive.read('runtime27/verified-11.summary.json'))
            original=json.loads(archive.read('runtime27/verified-11.json'))
            for data,key in [(nodes,'tests_sha256'),(summary,'summary_sha256')]:
                require(sha(json.dumps(data,sort_keys=True).encode())==original[key],'original verifier canonical digest')
            def walk(v):
                if isinstance(v,dict):
                    if v.get('nodeType')=='Test Case': yield v
                    for child in v.values(): yield from walk(child)
                elif isinstance(v,list):
                    for child in v: yield from walk(child)
            leaves=list(walk(nodes)); outcomes=collections.Counter(x['result'] for x in leaves)
            require(len(leaves)==55 and outcomes=={'Passed':32,'Failed':23},'actual iPad11 leaves')
            ids=[x['nodeIdentifier'].removesuffix('()') for x in leaves]
            release=json.loads(archive.read('runtime27/release-manifest.json'))
            lane=next(x for x in release['configurations'] if x['id']=='ipad11-native')
            require(len(set(ids))==55 and set(ids)==set(lane['required_ui_cases']+lane['required_oracle_cases']),'iPad11 selected leaf set')
            require('runtime27/verified-13.tests.json' not in archive.namelist() and 'runtime27/verified-13.summary.json' not in archive.namelist(),'iPad13 review unexpectedly has a final result')
for item in read(ROOT/'SOURCE_AUTHORITY.json'):
    raw=gzip.decompress((ROOT/'raw/source'/(item['path']+'.gz')).read_bytes())
    require(len(raw)==item['bytes'] and sha(raw)==item['sha256'],'source snapshot SHA')
    require(hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==item['gitBlob'],'source Git blob')
require(review['full_release_acceptance'] is False and review['current_source_native_qualification'] is False,'scope widening')
print(json.dumps({'verified_packet_files':len(expected),'zip_members_crc_and_sha':141,'verified_ipad11_leaves':55,'passed':32,'failed':23,'skipped':0,'ipad13':'UNVERIFIED_PARTIAL_STDOUT','full_release_acceptance':False,'new_app_or_native_execution':0},sort_keys=True))
