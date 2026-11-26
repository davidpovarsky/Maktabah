"""Additional evidence for the real compiled MiniApps bootstrap and UI processes.
The original native runner, selected methods and result verifiers remain unchanged.
"""
from pathlib import Path
import hashlib, json, os, plistlib, re, runpy, subprocess, sys, threading, time, datetime
def digest(path):
    h=hashlib.sha256()
    with Path(path).open("rb") as f:
        for b in iter(lambda:f.read(1024*1024),b""): h.update(b)
    return h.hexdigest()
class ImageAudit:
    def __init__(self,root,evidence,app,*,bundle_id,runner_bundle_id,required_images=(),display_names=()):
        assert not sys.flags.optimize,"Image-origin integrity assertions require normal Python execution"
        self.root=Path(root);self.e=Path(evidence);self.app=Path(app)
        self.e.mkdir(parents=True,exist_ok=True)
        self.out=self.e/"actual-image-origin";self.out.mkdir()
        self.bundle_id=bundle_id;self.runner_bundle_id=runner_bundle_id
        info=plistlib.loads((self.app/"Info.plist").read_bytes())
        assert info["CFBundleIdentifier"]==bundle_id,"Artifact bundle identity differs"
        self.executable=info["CFBundleExecutable"]
        assert Path(self.executable).name==self.executable,"Malformed executable identity"
        self.display_names=set(display_names)|{info.get("CFBundleDisplayName",""),info.get("CFBundleName","")}
        self.display_names.discard("")
        self.uuid_cache={}
        # Reuse the inventory contract already admitting the original producer.
        helper=runpy.run_path(str(self.root/"Scripts/CI/miniapps-local-producer.py"))
        self.inventory=helper["app_inventory"];self.files=self.inventory(self.app)
        self.required_images={self.executable,*required_images}
        debug=self.executable+".debug.dylib"
        if debug in self.files:self.required_images.add(debug)
        assert self.required_images<=self.files.keys(),"Required original runtime image is absent"
        self.save("built-app-inventory.json",self.files)
        self.sim=None;self.stop=threading.Event();self.thread=None
        self.rows=[];self.errors=[];self.verified=set();self.cache={}
    def save(self,name,value):
        (self.e/name).write_text(json.dumps(value,indent=2)+"\n")
    def artifact_uuids(self,relative):
        if relative not in self.uuid_cache:
            target=self.app/relative
            result=subprocess.run(["xcrun","dwarfdump","--uuid",str(target)],
                                  capture_output=True,text=True,timeout=20)
            name="artifact-uuid-"+hashlib.sha256(relative.encode()).hexdigest()+".txt"
            (self.out/name).write_text(result.stdout+result.stderr)
            assert result.returncode==0,("Cannot inspect admitted artifact UUID",relative,name)
            rows=re.findall(r"^UUID:\s*([0-9A-Fa-f-]{36})\s+\(([^)]+)\)",result.stdout,re.M)
            assert rows,("Artifact has no Mach-O UUID",relative,name)
            self.uuid_cache[relative]={"uuids":sorted({value.upper() for value,arch in rows}),
                "architectures":sorted({arch for value,arch in rows}),"evidence":name,
                "evidence_sha256":digest(self.out/name)}
        return self.uuid_cache[relative]
    def observe(self,pid,installed,raw,name,phase,sample_raw,sample_name):
        installed=Path(installed);paths=set()
        for source in (raw,sample_raw):
            process=re.search(r"^Process:\s+.+\[(\d+)\]\s*$",source,re.M)
            main_path=re.search(r"^Path:\s+(/.+)\s*$",source,re.M)
            assert process and int(process.group(1))==pid,("Wrong actual process report",pid)
            assert main_path and Path(main_path.group(1).strip()).resolve()==(installed/self.executable).resolve(),("Actual process is not the installed target",pid)
        actual_uuids=sample_image_uuids(sample_raw)
        paths.update(actual_uuids)
        for line in raw.splitlines():
            if line.startswith("__TEXT "):
                m=re.search(r"\s(/.*)$",line)
                if m:paths.add(m.group(1))
        assert paths,("No actual vmmap images",pid)
        private=[];foreign=[]
        for text in sorted(paths):
            p=Path(text);relative=None;location=None
            if p.is_relative_to(self.app):
                relative=p.relative_to(self.app).as_posix();location="CURRENT_VERIFIED_BUILT_APP"
            elif p.is_relative_to(installed):
                relative=p.relative_to(installed).as_posix();location="ACTUAL_INSTALLED_APP"
            if relative is not None:
                expected=self.files.get(relative)
                assert expected and expected.get("kind")=="file",("Unqualified private image",text)
                s=p.stat();key=(text,s.st_ino,s.st_mtime_ns,s.st_size)
                if key not in self.cache:self.cache[key]=digest(p)
                assert self.cache[key]==expected["sha256"],("Private image differs",text)
                observed=actual_uuids.get(text)
                assert observed,("Loaded private image has no actual sampled UUID",pid,text)
                expected_uuid=self.artifact_uuids(relative)
                assert observed in expected_uuid["uuids"],("Loaded private image UUID differs",pid,text,observed)
                private.append({"path":text,"manifest_relative_path":relative,"sha256":self.cache[key],
                    "origin":location,"loaded_uuid":observed,"artifact_uuid_proof":expected_uuid})
            elif text.startswith(("/System/","/usr/","/Library/Apple/","/Applications/Xcode.app/","/private/var/run/com.apple.security.cryptexd/","/var/run/com.apple.security.cryptexd/","/Library/Developer/CoreSimulator/Volumes/")):
                continue
            else:foreign.append(text)
        assert not foreign,("Foreign loaded image",foreign)
        assert any(x["manifest_relative_path"]==self.executable and x["origin"]=="ACTUAL_INSTALLED_APP" for x in private)
        debug=[x for x in private if x["manifest_relative_path"]==self.executable+".debug.dylib"]
        assert not debug or all(x["origin"]=="ACTUAL_INSTALLED_APP" for x in debug),("Debug metadata image outside installed main bundle",debug)
        full=self.required_images<={x["manifest_relative_path"] for x in private}
        row={"utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),"pid":pid,"phase":phase,
             "bundle_id":self.bundle_id,"installed_app":str(installed),
             "vmmap_file":name,"vmmap_sha256":digest(self.out/name),
             "sample_file":sample_name,"sample_sha256":digest(self.out/sample_name),
             "full_original_runtime_presence":full,"private_images":private,"unqualified_images":foreign}
        self.rows.append(row)
        if full:self.verified.add(pid)
        with(self.out/"observations.jsonl").open("a") as f:f.write(json.dumps(row)+"\n")
        return full
    def scoped_processes(self,reason):
        argv=["/usr/bin/xcrun","simctl","spawn",self.sim,"launchctl","list"]
        p=subprocess.run(argv,capture_output=True,text=True,timeout=5)
        raw=p.stdout+p.stderr
        raw_sha=hashlib.sha256(raw.encode()).hexdigest()
        name=f"owned-launchctl-{raw_sha}.txt"
        raw_path=self.out/name
        if raw_path.exists():assert raw_path.read_text()==raw
        else:raw_path.write_text(raw)
        assert p.returncode==0,("Owned simulator process observation failed",p.returncode,name)
        lines=p.stdout.splitlines()
        assert lines and lines[0].split()==["PID","Status","Label"],("Unexpected launchctl format",name)
        roles={"app":[],"ui_runner":[]}
        all_pids=set()
        for line in lines[1:]:
            if not line.strip():continue
            fields=line.split(None,2)
            assert len(fields)==3,("Malformed scoped process row",name,line)
            pid_text,status,label=fields
            assert pid_text=="-" or pid_text.isdigit(),("Malformed scoped PID",name,line)
            if pid_text=="-":continue
            pid=int(pid_text);all_pids.add(pid)
            if re.match(r"^UIKitApplication:"+re.escape(self.bundle_id)+r"(?:\[|$)",label):role="app"
            elif re.match(r"^UIKitApplication:"+re.escape(self.runner_bundle_id)+r"(?:\[|$)",label):role="ui_runner"
            else:continue
            roles[role].append({"pid":pid,"label":label})
        row={"utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),"reason":reason,"simulator_udid":self.sim,"argv":argv,"raw_file":name,"raw_sha256":raw_sha,"roles":roles}
        with(self.out/"owned-process-scopes.jsonl").open("a") as f:f.write(json.dumps(row)+"\n")
        return roles,all_pids
    def installed_app(self,pid):
        argv=["/usr/bin/xcrun","simctl","get_app_container",self.sim,self.bundle_id,"app"]
        p=subprocess.run(argv,capture_output=True,text=True,timeout=5)
        name=f"installed-app-pid-{pid}.txt"
        (self.out/name).write_text(p.stdout+p.stderr)
        assert p.returncode==0,("Owned installed app query failed",pid,name)
        path=Path(p.stdout.strip())
        prefix=f"/CoreSimulator/Devices/{self.sim}/data/Containers/Bundle/Application/"
        assert prefix in str(path) and path.name==self.app.name and path.is_dir(),("Unexpected owned installed bundle",str(path))
        info=plistlib.loads((path/"Info.plist").read_bytes())
        assert info["CFBundleIdentifier"]==self.bundle_id
        return path
    def capture(self,pid,installed,phase):
        name=f"pid-{pid}-{time.time_ns()}.vmmap.txt"
        p=subprocess.run(["/usr/bin/vmmap","-wide",str(pid)],capture_output=True,text=True,timeout=20)
        (self.out/name).write_text(p.stdout+p.stderr)
        if p.returncode:
            _,live=self.scoped_processes("vmmap_failure_liveness")
            if pid not in live:
                with(self.out/"terminated-before-capture.jsonl").open("a") as f:f.write(json.dumps({"pid":pid,"file":name,"exit":p.returncode})+"\n")
                return False
            raise RuntimeError(("Live own process vmmap failed",pid,p.returncode,name))
        sample_name=f"pid-{pid}-{time.time_ns()}.sample.txt"
        sample=subprocess.run(["/usr/bin/sample",str(pid),"1","1","-mayDie","-file",str(self.out/sample_name)],
                              capture_output=True,text=True,timeout=20)
        (self.out/(sample_name+".command.log")).write_text(sample.stdout+sample.stderr)
        if sample.returncode or not (self.out/sample_name).is_file():
            _,live=self.scoped_processes("sample_failure_liveness")
            if pid not in live:
                with(self.out/"terminated-before-capture.jsonl").open("a") as f:
                    f.write(json.dumps({"pid":pid,"file":sample_name,"exit":sample.returncode})+"\n")
                return False
            raise RuntimeError(("Live own process sample failed",pid,sample.returncode,sample_name))
        return self.observe(pid,installed,p.stdout,name,phase,
                            (self.out/sample_name).read_text(),sample_name)
    def bootstrap(self,sim,pid,installed):
        self.sim=sim
        roles,_=self.scoped_processes("bootstrap_admission")
        assert pid in {x["pid"] for x in roles["app"]},"Bootstrap PID absent from owned simulator launchd"
        assert self.installed_app(pid)==Path(installed),"Bootstrap installed bundle identity changed"
        for _ in range(10):
            if self.capture(pid,installed,"ORIGINAL_BOOTSTRAP"):return
            time.sleep(1)
        raise RuntimeError("Bootstrap never produced complete original runtime image proof")
    def loop(self):
        seen={};installed={}
        while not self.stop.wait(1):
            try:
                roles,_=self.scoped_processes("actual_ui_process_observation")
                # These are the actual owned simulator launchd records, not a host-wide
                # process scan. Native unit methods retain original instrumentation.
                if not roles["ui_runner"]:continue
                for process in roles["app"]:
                    pid=process["pid"]
                    if time.monotonic()-seen.get(pid,0)<(20 if pid in self.verified else 1):continue
                    seen[pid]=time.monotonic()
                    if pid not in installed:installed[pid]=self.installed_app(pid)
                    self.capture(pid,installed[pid],"ACTUAL_ORIGINAL_APP_UI")
            except Exception as ex:
                row={"utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),"error":str(ex)}
                self.errors.append(row)
                with(self.out/"errors.jsonl").open("a") as f:f.write(json.dumps(row)+"\n")
    def start(self,sim=None):
        if sim is not None:self.sim=sim
        assert self.sim,"Owned simulator identity is required"
        self.thread=threading.Thread(target=self.loop,daemon=True);self.thread.start()
    def stop_observing(self):
        self.stop.set()
        if self.thread:
            self.thread.join(30)
            assert not self.thread.is_alive(),"Image observer did not complete"
    def finish(self,log_paths=(),attachment_dirs=()):
        self.stop.set()
        if self.thread:
            self.thread.join(30)
            assert not self.thread.is_alive(),"Image observer did not complete"
        assert self.inventory(self.app)==self.files,"Qualified built app changed during test-without-building"
        texts=[]
        for path in [self.e/"xcodebuild.log",*map(Path,log_paths)]:
            if path.is_file():texts.append(path.read_text(errors="replace"))
        for directory in [self.e/"ui-attachments",*map(Path,attachment_dirs)]:
            for path in directory.glob("*.txt"):texts.append(path.read_text(errors="replace"))
        pids=set()
        for text in texts:
            pids.update(map(int,re.findall(re.escape(self.bundle_id)+r":\s*(\d+)",text)))
            pids.update(map(int,re.findall(r"OTZARIA_MINIAPPS_IMAGE_PID bundle="+re.escape(self.bundle_id)+r" pid=(\d+)",text)))
            for label in self.display_names:
                pids.update(map(int,re.findall(r"Application,\s*(?:0x[0-9a-fA-F]+,\s*)?pid:\s*(\d+),\s*label:\s*'"+re.escape(label)+r"'",text)))
        ui_verified={row["pid"] for row in self.rows if row["phase"]=="ACTUAL_ORIGINAL_APP_UI" and row["full_original_runtime_presence"]}
        missing=sorted(pids-ui_verified)
        status="PASS" if pids and ui_verified and not self.errors and not missing else "IMAGE_ORIGIN_INCOMPLETE"
        result={"status":status,"bundle_id":self.bundle_id,"artifact_app":str(self.app),"required_images":sorted(self.required_images),"all_private_image_uuids_verified":bool(self.rows) and not self.errors,"scope":"Authentic shipping bootstrap and actual original-app UI processes; native unit methods retain original Apple test instrumentation and are classified separately.","referenced_ui_pids":sorted(pids),"complete_observed_pids":sorted(self.verified),"complete_observed_ui_pids":sorted(ui_verified),"missing_referenced_ui_pids":missing,"nonempty_ui_pid_sets_required":True,"observations":len(self.rows),"errors":self.errors,"all_built_app_entries_unchanged":True}
        self.save("actual-image-origin-result.json",result)
        return result
def create_bundled_ui_configuration(root,e,app,derived,target_name="Maktabah-iOSUITests"):
    products=Path(derived)/"Build/Products"
    originals=list(products.glob("Maktabah-iOS_*.xctestrun"));assert len(originals)==1,originals
    original=originals[0];raw=original.read_bytes();data=plistlib.loads(raw)
    assert target_name in data and data[target_name].get("IsUITestBundle"),"Original UI test target is absent"
    def resolve(v):
        if isinstance(v,str):return v.replace("__TESTROOT__",str(products))
        if isinstance(v,list):return [resolve(x) for x in v]
        if isinstance(v,dict):return {k:resolve(x) for k,x in v.items()}
        return v
    data=resolve(data)
    target=data[target_name]
    assert Path(target["UITargetAppPath"])==Path(app)
    before=dict(target["UITargetAppEnvironmentVariables"]);after=dict(before)
    after["DYLD_FRAMEWORK_PATH"]=str(Path(app)/"Frameworks")
    after["__XPC_DYLD_FRAMEWORK_PATH"]=str(Path(app)/"Frameworks")
    after.pop("DYLD_LIBRARY_PATH",None);after.pop("__XPC_DYLD_LIBRARY_PATH",None)
    target["UITargetAppEnvironmentVariables"]=after
    e=Path(e);(e/"original-built.xctestrun").write_bytes(raw)
    output=e/"ActualBundledMiniAppsConsumer.xctestrun";output.write_bytes(plistlib.dumps(data))
    changes={"source_configuration":str(original),"source_sha256":hashlib.sha256(raw).hexdigest(),"effective_configuration":str(output),"effective_sha256":digest(output),"change":"Resolve TESTROOT because the copy has a different directory; constrain only actual UI application framework lookup to its own verified bundled frameworks and remove target debug-library relocation overrides.","ui_environment_before":before,"ui_environment_after":after,"all_original_targets_retained":True,"native_unit_and_runner_environments_unchanged_after_path_resolution":True}
    (e/"actual-bundled-xctestrun-admission.json").write_text(json.dumps(changes,indent=2)+"\n")
    return output

def sample_image_uuids(raw):
    """Read actual load UUIDs from Apple's sample, never from a path guess."""
    assert "Binary Images:\n" in raw,"Actual process sample has no binary-image section"
    rows={}
    for line in raw.split("Binary Images:\n",1)[1].splitlines():
        match=re.match(r"\s*0x[0-9a-fA-F]+\s*-\s*0x[0-9a-fA-F]+\s+.*<([0-9A-Fa-f-]{36})>\s+(/.*)$",line)
        if not match:continue
        value,path=match.group(1).upper(),match.group(2)
        assert path not in rows or rows[path]==value,"Ambiguous actual image UUID"
        rows[path]=value
    assert rows,"Actual process sample has no load identities"
    return rows
