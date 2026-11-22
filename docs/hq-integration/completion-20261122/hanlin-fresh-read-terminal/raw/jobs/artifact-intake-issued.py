import subprocess,json,hashlib,zipfile,shutil,datetime,stat
from pathlib import Path,PurePosixPath
root=Path(r"C:\Users\DAVID\AppData\Local\Temp\fr450063")
root.mkdir(parents=True,exist_ok=False)
expected=[{"id":14749682058,"kind":"evidence","bytes":6409802,"sha256":"9436a1e07582667ea201da5c36461cf3f1402077133906dcc4cca32a59c1a893"},{"id":14749388619,"kind":"captures","bytes":104633270,"sha256":"cdd24a7b99d1b6c230f0a3c7313db69fdc743cb7b475ecd03f52fca9dc2e9825"}]
result={"schema":"otzaria.native-fresh-read-artifact-intake/1","status":"RUNNING","runID":45006363282,"head":"997bc6872fed666daef8f720ddd1f847647be80c","applicationSource":"7eb9d2a5c8ac7ccb184e3cc50fb36b6272475ff1","attempt":1,"started":datetime.datetime.now(datetime.timezone.utc).isoformat(),"artifacts":[],"downloadsPerArtifact":1,"secretUsed":False}
def j(p,x):p.write_text(json.dumps(x,indent=2)+"\n",encoding="utf-8")
def persist():j(root/"RESULT.json",result)
def sha(b):return hashlib.sha256(b).hexdigest()
persist()
for a in expected:
 row={**a,"status":"DOWNLOADING","command":["gh","api",f"repos/davidpovarsky/Maktabah/actions/artifacts/{a['id']}/zip"]};result["artifacts"].append(row);persist()
 archive=root/(a["kind"]+".zip")
 with archive.open("wb") as out,(root/(a["kind"]+".download.stderr")).open("wb") as err:
  p=subprocess.Popen(row["command"],stdout=out,stderr=err,cwd=r"C:\Users\DAVID\Code\Maktabah-hanlin-fresh-read-diagnostic-20261122")
  row["ownedPID"]=p.pid;persist()
  try:rc=p.wait(timeout=600)
  except subprocess.TimeoutExpired:
   subprocess.run(["taskkill","/PID",str(p.pid),"/T","/F"],stdout=subprocess.PIPE,stderr=subprocess.PIPE);p.wait();raise
 row["returncode"]=rc;persist();assert rc==0
 data=archive.read_bytes();assert len(data)==a["bytes"] and sha(data)==a["sha256"];del data
 row["status"]="VERIFIED_EXTRACTING";persist()
 dest=root/a["kind"];dest.mkdir()
 payloads=[]
 with zipfile.ZipFile(archive) as z:
  infos=z.infolist();assert len(infos)<30000
  names=set();assert sum(i.file_size for i in infos)<4_000_000_000
  for info in infos:
   pp=PurePosixPath(info.filename);assert not pp.is_absolute() and ".." not in pp.parts and "\\" not in info.filename and ":" not in info.filename
   assert info.filename not in names;names.add(info.filename)
   assert not stat.S_ISLNK(info.external_attr>>16)
   path=dest.joinpath(*pp.parts)
   if info.is_dir():path.mkdir(parents=True,exist_ok=True);continue
   path.parent.mkdir(parents=True,exist_ok=True)
   h=hashlib.sha256();written=0
   with z.open(info) as src,path.open("wb") as out:
    while True:
     chunk=src.read(1048576)
     if not chunk:break
     out.write(chunk);h.update(chunk);written+=len(chunk)
   assert written==info.file_size
   payloads.append({"path":pp.as_posix(),"bytes":written,"sha256":h.hexdigest()})
 j(root/(a["kind"]+".FILES.json"),{"archive":a,"files":payloads,"fileCount":len(payloads),"bytes":sum(i["bytes"] for i in payloads)})
 row.update(status="VERIFIED_EXTRACTED",fileCount=len(payloads),expandedBytes=sum(i["bytes"] for i in payloads),finished=datetime.datetime.now(datetime.timezone.utc).isoformat());persist()
result.update(status="PASS",finished=datetime.datetime.now(datetime.timezone.utc).isoformat());persist()
print(json.dumps(result))