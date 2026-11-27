import subprocess,json,pathlib,hashlib,datetime,os
w=pathlib.Path('/mnt/development/projects/worktrees/Maktabah-wave3-integration-20261127'); out=w/'build/wave3-late-reply-capacity-intake-20261127-0856'
planpath=out/'PLAN.json';assert hashlib.sha256(planpath.read_bytes()).hexdigest()=='90a4e39416129f568c7f3c58d4d2dc7404912412c704ecb642743f357aa49bf9'
plan=json.loads(planpath.read_text())
prefix=['git','-C',str(w),'-c','gc.auto=0','-c','maintenance.auto=false','-c','user.name=ChatGPT','-c','user.email=chatgpt-agent@users.noreply.github.com']
def g(*args):return subprocess.check_output(prefix+list(args))
assert g('rev-parse','HEAD').decode().strip()==plan['rootBase']
assert not g('status','--porcelain=v1')
receipts=[]
for i,packet in enumerate(plan['packets']):
 donor=packet['donor'];start=datetime.datetime.now(datetime.timezone.utc).isoformat();before=g('rev-parse','HEAD').decode().strip()
 r=subprocess.run(prefix+['cherry-pick','-x',donor],capture_output=True)
 (out/(str(i).zfill(2)+'-'+donor+'.stdout')).write_bytes(r.stdout);(out/(str(i).zfill(2)+'-'+donor+'.stderr')).write_bytes(r.stderr)
 receipt={'donor':donor,'before':before,'startedUTC':start,'exit':r.returncode}
 if r.returncode:
  receipt['status']=g('status','--porcelain=v1').decode();receipts.append(receipt);(out/'INTAKE_PARTIAL.json').write_text(json.dumps(receipts,indent=2)+'\n');print(json.dumps(receipt));raise SystemExit(1)
 cat=subprocess.Popen(prefix+['cat-file','--batch'],stdin=subprocess.PIPE,stdout=subprocess.PIPE)
 for f in packet['files']:
  cat.stdin.write(('HEAD:'+f['path']+'\n').encode());cat.stdin.flush();h=cat.stdout.readline()
  if h.endswith(b' missing\n'):actual=None;n=None
  else:
   n=int(h.split()[2]);b=cat.stdout.read(n);assert cat.stdout.read(1)==b'\n';actual=hashlib.sha256(b).hexdigest()
  assert actual==f['expectedSHA256'] and n==f['expectedBytes'],('integrated-file-mismatch',donor,f['path'],actual)
 cat.stdin.close();cat.wait()
 after=g('rev-parse','HEAD').decode().strip(); receipt.update({'after':after,'sourceTree':g('rev-parse','HEAD:Source').decode().strip(),'verifiedFiles':len(packet['files']),'completeUTC':datetime.datetime.now(datetime.timezone.utc).isoformat()})
 receipts.append(receipt);(out/'INTAKE_PARTIAL.json').write_text(json.dumps(receipts,indent=2)+'\n')
assert not g('status','--porcelain=v1')
result={'schema':1,'status':'SELECTIVE_INTAKE_VERIFIED','base':plan['rootBase'],'head':g('rev-parse','HEAD').decode().strip(),'sourceTree':g('rev-parse','HEAD:Source').decode().strip(),'planSHA256':hashlib.sha256(planpath.read_bytes()).hexdigest(),'receipts':receipts,'clean':True,'nativeTests':'NOT_RUN','historicalResultsReattributed':False,'freeBytes':os.statvfs(w).f_bavail*os.statvfs(w).f_frsize}
p=out/'RESULT.json';p.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'result':result,'resultSHA256':hashlib.sha256(p.read_bytes()).hexdigest()}))
