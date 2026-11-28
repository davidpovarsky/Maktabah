"""Pinned storage resolver for fourteen preserved historical focused-control sources.
Only the documented source-read storage boundary changes. Original dispatcher,
workers, tests, protocol, allocation guards, process handling and output caps stay exact.
"""
if not __debug__: raise RuntimeError("Optimized storage resolver refused")
import argparse,base64,hashlib,io,json,os,stat,sys,types,zipfile
from pathlib import Path
ROOT=Path('/home/ubuntu/otzaria-wave3-native116-v3-focused-controls-20261128')
ARCHIVE=ROOT/'HISTORICAL_SOURCES.zip'
ARCHIVE_BYTES=87596
ARCHIVE_SHA='d00812b52bbfedc7ad8424f92c346f673fe82d74ded02ad89a4491259aa11433'
MANIFEST_BYTES=8450
MANIFEST_SHA='ba71f53a74c4caf90ecf6c92ad7f4f13d1d54b6170e6e10b20db6b28cd682dae'
SEAL_SHA='91310e5dd7f4e72289c6575f4e07d47853b28d48beab460f88caecf26c555b09'
DISPATCH_SHA='698a39e097827e596c98ccb9afee193fcf08aa6f7405cfe5db114ac3a5a8aa48'
def need(ok,message):
    if not ok: raise RuntimeError(message)
def sha(b): return hashlib.sha256(b).hexdigest()
def ident(s):
    return (s.st_dev,s.st_ino,s.st_mode,s.st_uid,s.st_gid,s.st_nlink,s.st_size,s.st_mtime_ns,s.st_ctime_ns)
def exact(path,limit):
    need(path.resolve(strict=True)==path,'Exact unsymlinked storage path')
    before=path.lstat()
    need(stat.S_ISREG(before.st_mode) and before.st_nlink==1 and before.st_size<=limit,'Bounded single regular storage')
    fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW)
    try:
        need(ident(os.fstat(fd))==ident(before),'Storage open identity')
        with os.fdopen(os.dup(fd),'rb') as stream: raw=stream.read(limit+1)
        need(len(raw)==before.st_size and ident(os.fstat(fd))==ident(before),'Complete stable storage read')
    finally: os.close(fd)
    need(ident(path.lstat())==ident(before),'Storage path identity')
    return raw
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--resolver-sha256',required=True)
    parser.add_argument('--source-seal-sha256',required=True)
    parser.add_argument('--phase',choices=('mac-candidate','close'),required=True)
    args=parser.parse_args()
    need(sys.flags.isolated==1 and sys.dont_write_bytecode and os.geteuid()==1001,'Original isolated owner runtime')
    need(ROOT.resolve(strict=True)==ROOT and stat.S_ISDIR(ROOT.lstat().st_mode),'Fixed owned controls root')
    own=Path(__file__)
    need(own==ROOT/'resolve_preserved_sources.py','Fixed resolver source')
    need(sha(exact(own,16384))==args.resolver_sha256,'Root-pinned resolver source')
    need(args.source_seal_sha256==SEAL_SHA,'Original reporting seal unchanged')
    seal_raw=exact(ROOT/'SOURCE_SEAL_REVIEW3.json',65536)
    need(sha(seal_raw)==SEAL_SHA,'Exact original seal')
    seal=json.loads(seal_raw)
    need(seal['schema']=='otzaria.native116-focused-control-reporting-seal/3' and seal['root']==str(ROOT),'Original seal schema')
    historical=seal['originalFourteen']
    need(len(historical)==14 and all(Path(n).name==n for n in historical),'Closed fourteen historical names')
    need(sum(p['bytes'] for p in historical.values())==275022,'Closed historical logical bytes')
    paths={str(ROOT/name):name for name in historical}
    def archive_members():
        need(all(not os.path.lexists(ROOT/name) for name in historical),'Archived raw source path reappeared')
        raw=exact(ARCHIVE,131072)
        need(len(raw)==ARCHIVE_BYTES and sha(raw)==ARCHIVE_SHA,'Pinned complete source archive')
        out={}
        with zipfile.ZipFile(io.BytesIO(raw)) as z:
            infos=z.infolist()
            need(len(infos)==15 and {i.filename for i in infos}==set(historical)|{'MANIFEST.json'},'Exact archive members without duplicates')
            for info in infos:
                need(not info.is_dir() and info.compress_type==zipfile.ZIP_DEFLATED and not info.flag_bits&1,'Closed regular unencrypted member')
                need(stat.S_ISREG(info.external_attr>>16),'Original regular member type')
                pin={'bytes':MANIFEST_BYTES,'sha256':MANIFEST_SHA} if info.filename=='MANIFEST.json' else historical[info.filename]
                need(info.file_size==pin['bytes'] and info.file_size<=65536,'Bounded declared member length')
                with z.open(info) as f:
                    body=f.read(pin['bytes']+1)
                    need(f.read(1)==b'','Complete member EOF')
                need(len(body)==pin['bytes'] and sha(body)==pin['sha256'],'Complete original member byte/hash pin')
                out[info.filename]=body
        manifest=json.loads(out.pop('MANIFEST.json'))
        need(manifest['schema']=='otzaria.focused-legacy-source-archive/1' and manifest['root']==str(ROOT),'Archive metadata schema/root')
        need(manifest['sourceSealSHA256']==SEAL_SHA and manifest['originalFourteen']==historical,'Original fourteen bindings')
        rows=manifest['entries']
        need(len(rows)==14 and {r['name'] for r in rows}==set(historical),'Exact metadata membership')
        for row in rows:
            pin=historical[row['name']]
            need(row['bytes']==pin['bytes'] and row['sha256']==pin['sha256'] and stat.S_ISREG(row['mode']) and row['nlink']==1,'Original metadata bindings')
        return out
    archive_members()
    dispatcher_path=ROOT/'dispatch_focused_controls_review3.py'
    body=exact(dispatcher_path,65536)
    need(len(body)==32825 and sha(body)==DISPATCH_SHA,'Original dispatcher body unchanged')
    module=types.ModuleType('focused_dispatcher_preserved_storage')
    module.__file__=str(dispatcher_path)
    exec(compile(body,str(dispatcher_path),'exec'),module.__dict__)
    original_read=module.read_fixed
    def preserved_read(path,limit,single=True):
        name=paths.get(str(path))
        if name is None: return original_read(path,limit,single=single)
        need(type(limit) is int and limit>=0 and historical[name]['bytes']<=limit,'Original requested source-read limit')
        return archive_members()[name]
    module.read_fixed=preserved_read
    print(json.dumps({'kind':'EXPLICIT_PRESERVED_SOURCE_STORAGE','phase':args.phase,'resolverSHA256':args.resolver_sha256,
                      'archiveBytes':ARCHIVE_BYTES,'archiveSHA256':ARCHIVE_SHA,'historicalMembers':14,
                      'originalDispatcherSHA256':DISPATCH_SHA,'originalSealSHA256':SEAL_SHA,
                      'testOrProtocolBodiesChanged':False,'allocationAndOutputCapsChanged':False},separators=(',',':')),flush=True)
    sys.argv=[str(dispatcher_path),'--source-seal-sha256',SEAL_SHA,'--phase',args.phase]
    module.main()
if __name__=='__main__': main()
