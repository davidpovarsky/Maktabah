#!/usr/bin/env python3
"""Create/clean only a simulator owned by this exact CI run; never reuse a user's device."""
import argparse,json,os,re,subprocess,uuid
from pathlib import Path

def output(*args): return subprocess.check_output(args,text=True,timeout=90).strip()
def simjson(kind): return json.loads(output('xcrun','simctl','list',kind,'-j'))

def main():
 p=argparse.ArgumentParser();p.add_argument('--cleanup',action='store_true');p.add_argument('--out',default='sim_udid.txt');p.add_argument('--major',type=int,default=27);p.add_argument('--receipt',default='build/artifacts/simulator-isolation.json')
 args=p.parse_args();receipt=Path(args.receipt)
 run=os.environ.get('GITHUB_RUN_ID',str(os.getppid()));attempt=os.environ.get('GITHUB_RUN_ATTEMPT','1')
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
           and (args.major == 0 or int(r['version'].split('.')[0])==args.major)]
 if not runtimes: raise SystemExit(f'No available iOS {args.major} runtime; refusing to use another session device')
 runtimes.sort(key=lambda r:(tuple(int(n) for n in r['version'].split('.')), '-iPhone' not in r['identifier']),reverse=True)
 types=[d for d in simjson('devicetypes')['devicetypes'] if 'iPad' in d['name']]
 types.sort(key=lambda d:('13-inch' not in d['name'],'M4' not in d['name'],d['name']))
 if not types: raise SystemExit('No iPad device type is available')
 name=f'Codex-sefaria-{run}-{attempt}-{uuid.uuid4().hex[:8]}'
 failures=[];udid=None;selected_type=None;selected_runtime=None
 for runtime in runtimes:
  supported={entry['identifier'] for entry in runtime.get('supportedDeviceTypes',[])}
  for device_type in types:
   if supported and device_type['identifier'] not in supported: continue
   created=subprocess.run(['xcrun','simctl','create',name,device_type['identifier'],runtime['identifier']],text=True,capture_output=True,timeout=90)
   if created.returncode==0:
    udid=created.stdout.strip();selected_type=device_type;selected_runtime=runtime;break
   failures.append(dict(deviceType=device_type['identifier'],runtime=runtime['identifier'],error=created.stderr.strip()))
  if udid: break
 if not udid: raise SystemExit('No compatible run-owned iPad could be created: '+json.dumps(failures))
 receipt.parent.mkdir(parents=True,exist_ok=True)
 receipt.write_text(json.dumps(dict(udid=udid,name=name,runtime=selected_runtime['identifier'],deviceType=selected_type['identifier'],runId=run,attempt=attempt,failedPairs=failures),indent=2)+'\n')
 Path(args.out).parent.mkdir(parents=True,exist_ok=True)
 Path(args.out).write_text(udid+'\n')
 print('Created isolated iPad simulator:',name,udid)

if __name__=='__main__': main()
