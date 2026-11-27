import json,os,threading,time
print(json.dumps({"event":"started","pid":os.getpid(),"threadID":threading.get_native_id(),"monotonicNs":time.monotonic_ns(),"unixNs":time.time_ns()}),flush=True)
deadline=time.monotonic()+7
iterations=0
while time.monotonic()<deadline:
 end=min(deadline,time.monotonic()+0.12)
 while time.monotonic()<end:
  iterations+=sum(range(500))
 time.sleep(0.04)
print(json.dumps({"event":"finished","pid":os.getpid(),"threadID":threading.get_native_id(),"monotonicNs":time.monotonic_ns(),"unixNs":time.time_ns(),"iterations":iterations}),flush=True)
