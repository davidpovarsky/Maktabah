import pathlib,subprocess,shlex,json,time
p=pathlib.Path('/mnt/development/projects/worktrees/Maktabah-wave2-reader-20261127/docs/hq-integration/wave2-20261127/reader/sqlite-fetch-wait-controls/run02')
started=time.time()
cmd=['sudo','-n','-u','ubuntu','ssh','-o','BatchMode=yes','-o','ConnectTimeout=8','scaleway-mac','python3 -c '+shlex.quote((p/'run-apple-controls.py').read_text())]
with (p/'REMOTE_RESPONSE.json').open('wb') as stdout,(p/'transport.stderr').open('wb') as stderr:
 try:
  result=subprocess.run(cmd,input=(p/'payload.zlib').read_bytes(),stdout=stdout,stderr=stderr,timeout=900)
  code=result.returncode
 except subprocess.TimeoutExpired:code=124
(p/'TRANSPORT_RESULT.json').write_text(json.dumps({'exit':code,'startedAtUnix':started,'finishedAtUnix':time.time()},indent=2)+'\n')
