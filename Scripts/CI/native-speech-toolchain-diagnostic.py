"""Probe Apple system speech on a disposable iPad, independent of Maktabah."""
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path.cwd()
out = root / 'build/artifacts/runtime27/voiceover-toolchain-probe'
out.mkdir(parents=True, exist_ok=True)
source = root / 'Tests/Diagnostics/NativeSpeechToolchain'


def capture(*args):
    return subprocess.check_output(args, text=True, timeout=60).strip()


sdk = capture('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version')
runtimes = json.loads(capture('xcrun','simctl','list','runtimes','-j'))['runtimes']
identifiers = [r['identifier'] for r in runtimes if r.get('isAvailable') and r.get('version') == sdk and r['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-')]
device_types = json.loads(capture('xcrun','simctl','list','devicetypes','-j'))['devicetypes']
devices = [d['identifier'] for d in device_types if d['name']=='iPad Pro 11-inch (M5)']
assert sdk.startswith('27.') and len(identifiers) == len(devices) == 1, (sdk, identifiers, devices)
udid = capture('xcrun','simctl','create','Otzaria Apple Speech Toolchain Probe',devices[0],identifiers[0])
evidence = {'source': os.environ['EXPECTED_CHECKOUT_SHA'], 'xcode': capture('xcodebuild','-version'),
            'sdk_version': sdk, 'runtime': identifiers[0], 'udid': udid, 'scope': 'Independent Apple VoiceOver fixture only'}
result = out / 'voiceover.xcresult'
try:
    subprocess.run(['xcrun','simctl','boot',udid],check=True,timeout=90)
    with (out/'boot.log').open('w') as log:
        subprocess.run(['xcrun','simctl','bootstatus',udid,'-b'],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=240)
    command = ['xcodebuild','test','-project',str(source/'VoiceOverHostProbe.xcodeproj'),'-scheme','VoiceOverHostProbe',
               '-destination',f'platform=iOS Simulator,id={udid}','-parallel-testing-enabled','NO',
               '-only-testing:VoiceOverHostProbeUITests/VoiceOverHostProbeUITests/testAppleVoiceOverEnablesAndProducesSpeech',
               '-derivedDataPath',str(root/'build/local-voiceover-derived'),'-resultBundlePath',str(result)]
    with (out/'xcodebuild.log').open('w') as log:
        process = subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,timeout=600)
    evidence['xcodebuild_exit_code'] = process.returncode
    raw = capture('xcrun','xcresulttool','get','test-results','summary','--path',str(result),'--compact')
    (out/'apple-summary.json').write_text(raw+'\n')
    summary = json.loads(raw)
    evidence.update({k:summary[k] for k in ('result','passedTests','failedTests','skippedTests')})
    passed = (process.returncode == 0 and evidence['passedTests'] == 1
              and evidence['failedTests'] == evidence['skippedTests'] == 0)
    sys.exit(0 if passed else 1)
finally:
    for action in ('shutdown','delete'):
        p = subprocess.run(['xcrun','simctl',action,udid],capture_output=True,text=True,timeout=90)
        evidence['owned_device_'+action] = p.returncode
    (out/'probe-receipt.json').write_text(json.dumps(evidence,indent=2)+'\n')
