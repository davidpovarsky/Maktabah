#!/usr/bin/env python3
import argparse,hashlib,json,subprocess,sys,tempfile,zipfile
from pathlib import Path,PurePosixPath

def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--run-controls',action='store_true');a=ap.parse_args()
 here=Path(__file__).resolve().parent;root=here.parents[2]
 m=json.loads((here/'ARTIFACTS.json').read_text());count=0
 for item in m['files']:
  p=root/item['path'];b=p.read_bytes()
  assert len(b)==item['bytes'] and sha(b)==item['sha256'] and blob(b)==item['git_blob'],item['path']
  count+=1
 for item in m['candidate_sources']:
  p=root/item['path'];b=p.read_bytes()
  assert len(b)==item['bytes'] and sha(b)==item['sha256'] and blob(b)==item['git_blob'],item['path']
  count+=1
 with zipfile.ZipFile(here/'BASE_INPUTS.zip') as z:
  assert z.testzip() is None
  expected=json.loads((here/'BASE_INPUTS.json').read_text());assert set(z.namelist())==set(expected)
  for n in z.namelist():
   p=PurePosixPath(n);assert not p.is_absolute() and '..'not in p.parts and str(p)==n
   b=z.read(n);assert len(b)==expected[n]['bytes'] and sha(b)==expected[n]['sha256'] and blob(b)==expected[n]['git_blob']
  if a.run_controls:
   with tempfile.TemporaryDirectory(prefix='focused-native-source-') as d:
    out=Path(d)
    for n in z.namelist():
     p=out/n;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(z.read(n))
    r=subprocess.run([sys.executable,str(root/'Scripts/CI/test-reader-inspector-focused-native.py'),'--base-dir',str(out)],timeout=30)
    assert r.returncode==0
 print(json.dumps({'status':'PACKET_SOURCE_BYTES_VERIFIED','verified_records':count,'candidate_sources':len(m['candidate_sources']),'original_inputs':len(expected),'controls_replayed':a.run_controls,'native_cases_executed':0,'full_native116_acceptance':False,'full_release114_acceptance':False},indent=2))
if __name__=='__main__':main()
