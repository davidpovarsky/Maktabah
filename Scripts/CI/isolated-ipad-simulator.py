#!/usr/bin/env python3
"""Create/clean only a simulator owned by this exact CI run; never reuse a user's device."""
import argparse,json,os,re,subprocess,uuid
from pathlib import Path

def output(*args): return subprocess.check_output(args,text=True).strip()
def simjson(kind): return json.loads(output('xcrun','simctl','list',kind,'-j'))

def main():
 p=argparse.ArgumentParser();p.add_argument('--cleanup',action='store_true');p.add_argument('--out',default='sim_udid.txt');p.add_argument('--major',type=int,default=27)
 args=p.parse_args();receipt=Path('build/artifacts/simulator-isolation.json')
 run=os.environ.get('GITHUB_RUN_ID','local');attempt=os.environ.get('GITHUB_RUN_ATTEMPT','1')
 if args.cleanup:
  if not receipt.exists(): return
  record=json.loads(receipt.read_text())
  prefix=f'Codex-sefaria-{run}-{attempt}-'
  if record.get('runId')!=run or record.get('attempt')!=attempt or not record.get('name','').startswith(prefix):
   raise SystemExit('Refusing to clean a simulator not owned by this run')
  devices=simjson('devices')['devices']
  matches=[d for group in devices.values() for d in group if d['udid']==record['udid'] and d['name']==record['name']]
  if not matches: return
  subprocess.run(['xcrun','simctl','shutdown',record['udid']],check=False)
  subprocess.run(['xcrun','simctl','delete',record['udid']],check=True)
  print('Removed only this run-owned simulator:',record['udid']);return
 runtimes=[r for r in simjson('runtimes')['runtimes'] if r.get('isAvailable') and r.get('name','').startswith('iOS ')
           and int(r['version'].split('.')[0])==args.major]
 if not runtimes: raise SystemExit(f'No available iOS {args.major} runtime; refusing to use another session device')
 runtime=max(runtimes,key=lambda r:tuple(int(n) for n in r['version'].split('.')))
 types=[d for d in simjson('devicetypes')['devicetypes'] if 'iPad' in d['name']]
 types.sort(key=lambda d:('13-inch' not in d['name'],'M4' not in d['name'],d['name']))
 if not types: raise SystemExit('No iPad device type is available')
 name=f'Codex-sefaria-{run}-{attempt}-{uuid.uuid4().hex[:8]}'
 udid=output('xcrun','simctl','create',name,types[0]['identifier'],runtime['identifier'])
 receipt.parent.mkdir(parents=True,exist_ok=True)
 receipt.write_text(json.dumps(dict(udid=udid,name=name,runtime=runtime['identifier'],runId=run,attempt=attempt),indent=2)+'\n')
 Path(args.out).write_text(udid+'\n')
 print('Created isolated iPad simulator:',name,udid)

if __name__=='__main__': main()
