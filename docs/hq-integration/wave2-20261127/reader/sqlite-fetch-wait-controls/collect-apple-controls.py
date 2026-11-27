import pathlib,subprocess,shlex,json,zlib,base64,hashlib,pwd,os
root=pathlib.Path('/mnt/development/projects/worktrees/Maktabah-wave2-reader-20261127/docs/hq-integration/wave2-20261127/reader/sqlite-fetch-wait-controls')
u=pwd.getpwnam('ubuntu');summary=[]
for number in ('run01','run02'):
 local=root/number;assert json.loads((local/'TRANSPORT_RESULT.json').read_text())['exit']==0
 response=json.loads((local/'REMOTE_RESPONSE.json').read_text());report=response['result'];mac=report['directory']
 assert mac.startswith('/Users/m1/builds/otzaria-wave2-reader-controls-20261127/sqlite-fetch-wait-')
 destination=local/'actual-apple-files';assert not destination.exists()
 program="""import pathlib,json,zlib,base64,hashlib,stat
root=pathlib.Path(MAC_ROOT);assert root.resolve()==root
paths=[]
for path in root.iterdir():
 if path.is_file() and path.suffix in ('.swift','.json','.stdout','.stderr'):paths.append(path)
 elif path.is_dir() and 'fixture' in path.name:
  paths.extend(p for p in path.iterdir() if p.is_file() and p.suffix=='.json')
files={};total=0
for path in paths:
 st=path.lstat();assert stat.S_ISREG(st.st_mode) and not path.is_symlink() and st.st_size<=2*1024*1024
 data=path.read_bytes();total+=len(data);assert total<=8*1024*1024
 files[str(path.relative_to(root))]={'base64':base64.b64encode(data).decode(),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
binaries={}
for name in ('BaselineControls','CandidateControls','ReleaseControls','CatalystControls'):
 path=root/name
 if path.exists():
  st=path.lstat();assert stat.S_ISREG(st.st_mode) and st.st_size<=8*1024*1024
  binaries[name]={'path':str(path),'bytes':st.st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
import sys;sys.stdout.buffer.write(zlib.compress(json.dumps({'files':files,'binaries':binaries},ensure_ascii=False).encode(),9))
""".replace('MAC_ROOT',repr(mac))
 result=subprocess.run(['sudo','-n','-u','ubuntu','ssh','-o','BatchMode=yes','-o','ConnectTimeout=8','scaleway-mac','python3 -c '+shlex.quote(program)],capture_output=True,timeout=30)
 assert result.returncode==0,result.stderr.decode(errors='replace')
 body=json.loads(zlib.decompress(result.stdout));files=body['files']
 for name,digest in report['inputSHA256'].items():assert files[name]['sha256']==digest
 for record in report['records']:
  for suffix in ('stdout','stderr'):assert files[record['name']+'.'+suffix]['sha256']==record[suffix+'SHA256']
 actual_report=json.loads(base64.b64decode(files['RESULT.json']['base64']));assert actual_report==report
 destination.mkdir();os.chown(destination,u.pw_uid,u.pw_gid)
 for name,value in files.items():
  p=pathlib.PurePosixPath(name);assert not p.is_absolute() and '..' not in p.parts
  data=base64.b64decode(value['base64']);assert len(data)==value['bytes'] and hashlib.sha256(data).hexdigest()==value['sha256']
  target=destination/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
  os.chown(target,u.pw_uid,u.pw_gid);os.chown(target.parent,u.pw_uid,u.pw_gid)
 manifest={'schema':1,'originalMacDirectory':mac,'files':{name:{k:v for k,v in value.items() if k!='base64'} for name,value in files.items()},'binariesRetainedOnMac':body['binaries'],'transportExit':result.returncode,'compressedTransferSHA256':hashlib.sha256(result.stdout).hexdigest(),'scope':'Exact retained source controls and their original raw observations; no application UI/performance acceptance'}
 (destination/'TRANSFER.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n');os.chown(destination/'TRANSFER.json',u.pw_uid,u.pw_gid)
 summary.append({'run':number,'files':len(files),'rawBytes':sum(v['bytes'] for v in files.values()),'compressedBytes':len(result.stdout),'allCommandsPassed':report['allCommandsPassed'],'actualDirectory':mac})
print(json.dumps(summary))
