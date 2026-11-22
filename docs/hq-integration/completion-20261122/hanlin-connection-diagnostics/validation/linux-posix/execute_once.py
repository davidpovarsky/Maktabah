#!/usr/bin/env python3
from pathlib import Path
import datetime,hashlib,json,os,subprocess,sys,time
root=Path(__file__).resolve().parent
assert not (root/"PYTHON_EXECUTION.json").exists(),"Preserve previous command receipt"
cmd=[sys.executable,"-B",str(root/"run_diagnostic_controls.py")]
start=datetime.datetime.now(datetime.timezone.utc).isoformat();t=time.monotonic()
proc=subprocess.Popen(cmd,cwd=root,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
try:
    stdout,stderr=proc.communicate(timeout=60)
    timeout=False
except subprocess.TimeoutExpired:
    proc.kill();stdout,stderr=proc.communicate();timeout=True
(root/"python.stdout").write_bytes(stdout);(root/"python.stderr").write_bytes(stderr)
record={"schemaVersion":1,"command":cmd,"cwd":str(root),"supervisorPID":os.getpid(),"childPID":proc.pid,
"startedUTC":start,"elapsedSeconds":time.monotonic()-t,"timeoutSeconds":60,"timedOut":timeout,
"exitCode":proc.returncode,"stdoutBytes":len(stdout),"stdoutSHA256":hashlib.sha256(stdout).hexdigest(),
"stderrBytes":len(stderr),"stderrSHA256":hashlib.sha256(stderr).hexdigest(),
"launcherSHA256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
(root/"PYTHON_EXECUTION.json").write_text(json.dumps(record,indent=2)+"\n")
print(json.dumps(record));print(stdout.decode("utf-8","replace"));print(stderr.decode("utf-8","replace"))
sys.exit(124 if timeout else proc.returncode)

