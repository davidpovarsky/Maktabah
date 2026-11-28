if not __debug__:
    raise SystemExit("Optimized Python is refused before preservation actions.")
import datetime
import hashlib
import io
import json
import os
import pathlib
import stat
import sys
import time
import zipfile

# Bootstrap supplies the exact frozen CONFIG, README_TEXT and PACKAGER_SOURCE.
# This controller reads preserved scripts as bytes; it never imports them.
def require(condition, message):
    if not condition:
        raise RuntimeError(message)

def digest(data):
    return hashlib.sha256(data).hexdigest()

def json_bytes(value):
    return (json.dumps(value, indent=2, ensure_ascii=False, sort_keys=True) + "\n").encode("utf-8")

def stamp(s):
    return {"device":s.st_dev,"inode":s.st_ino,"mode":stat.S_IMODE(s.st_mode),
            "uid":s.st_uid,"gid":s.st_gid,"nlink":s.st_nlink,"bytes":s.st_size,
            "mtime_ns":s.st_mtime_ns,"ctime_ns":s.st_ctime_ns,"allocated_bytes":s.st_blocks*512}

def safe_relative(value):
    p=pathlib.PurePosixPath(value)
    require(value and not p.is_absolute() and str(p)==value and all(x not in ("",".","..") for x in p.parts), "unsafe relative path")
    return p.parts

def read_exact(root, relative):
    parts=safe_relative(relative)
    opened=[]
    try:
        fd=os.open(root,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW|os.O_CLOEXEC)
        opened.append(fd)
        for part in parts[:-1]:
            fd=os.open(part,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW|os.O_CLOEXEC,dir_fd=fd)
            opened.append(fd)
        parent=fd
        leaf=os.open(parts[-1],os.O_RDONLY|os.O_NOFOLLOW|os.O_CLOEXEC,dir_fd=parent)
        opened.append(leaf)
        before=os.fstat(leaf)
        require(stat.S_ISREG(before.st_mode) and before.st_nlink==1,"input is not a single-link regular file")
        chunks=[]
        while True:
            chunk=os.read(leaf,1024*1024)
            if not chunk:
                break
            chunks.append(chunk)
        data=b"".join(chunks)
        after=os.fstat(leaf)
        named=os.stat(parts[-1],dir_fd=parent,follow_symlinks=False)
        require(stamp(before)==stamp(after)==stamp(named),"input identity changed while reading")
        require(len(data)==before.st_size,"input read length mismatch")
        return data,stamp(before)
    finally:
        for fd in reversed(opened):
            os.close(fd)

def inventory(root):
    p=pathlib.Path(root)
    s=p.lstat()
    require(stat.S_ISDIR(s.st_mode) and p.resolve()==p,"scope root is not an original real directory")
    files={}
    directories={".":stamp(s)}
    for base,ds,fs in os.walk(p,topdown=True,followlinks=False):
        ds.sort()
        fs.sort()
        for name in ds:
            d=pathlib.Path(base)/name
            q=d.lstat()
            require(stat.S_ISDIR(q.st_mode) and not stat.S_ISLNK(q.st_mode),"non-directory or symlink scope entry")
            directories[d.relative_to(p).as_posix()]=stamp(q)
        for name in fs:
            f=pathlib.Path(base)/name
            rel=f.relative_to(p).as_posix()
            safe_relative(rel)
            q=f.lstat()
            require(stat.S_ISREG(q.st_mode) and q.st_nlink==1,"nonregular, symlink or hardlink input")
            require(rel not in files,"duplicate input path")
            files[rel]=stamp(q)
    parents={"."}
    for rel in files:
        for parent in pathlib.PurePosixPath(rel).parents:
            parents.add(parent.as_posix())
    require(set(directories)==parents,"extra or missing scoped directories")
    return files,directories

def listed_records(body):
    files=body["files"]
    if isinstance(files,dict):
        return {path:{"bytes":pin["bytes"],"sha256":pin["sha256"]} for path,pin in files.items()}
    require(isinstance(files,list),"manifest files is neither array nor object")
    result={}
    for row in files:
        require(row["path"] not in result,"duplicate sealed manifest path")
        result[row["path"]]={"bytes":row["bytes"],"sha256":row["sha256"]}
    return result

def current_free():
    s=os.statvfs("/home/ubuntu")
    return s.f_bavail*s.f_frsize

def allocated(out):
    if not out.exists():
        return 0
    total=0
    for base,ds,fs in os.walk(out,followlinks=False):
        b=pathlib.Path(base)
        q=b.lstat()
        require(stat.S_ISDIR(q.st_mode) and not stat.S_ISLNK(q.st_mode),"output directory changed")
        total+=q.st_blocks*512
        for name in fs:
            q=(b/name).lstat()
            require(stat.S_ISREG(q.st_mode) and q.st_nlink==1,"output is not a single-link regular file")
            total+=q.st_blocks*512
        for name in ds:
            q=(b/name).lstat()
            require(stat.S_ISDIR(q.st_mode) and not stat.S_ISLNK(q.st_mode),"output symlink directory")
    return total

def main():
    cfg=CONFIG
    out=pathlib.Path(cfg["output"])
    floor=cfg["root_floor_bytes"]
    cap=cfg["reserve_and_cap_bytes"]
    require(out.parent==pathlib.Path("/home/ubuntu"),"unexpected output parent")
    require(not out.exists() and not out.is_symlink(),"fresh output scope must be absent")
    initial_free=current_free()
    require(initial_free>=floor+cap,"rootfs floor plus full reserve not met before allocation")
    require(cfg["total_files"]==121 and cfg["total_bytes"]==3630077,"unexpected closed bundle size")
    raw={}
    snapshots={}
    rows=[]
    closure=[]
    forbidden=[b"-----BEGIN PRIVATE KEY-----",b"-----BEGIN ENCRYPTED PRIVATE KEY-----",
               b"-----BEGIN OPENSSH PRIVATE KEY-----",b"-----BEGIN RSA PRIVATE KEY-----",
               b"-----BEGIN EC PRIVATE KEY-----",b"-----BEGIN DSA PRIVATE KEY-----"]
    for scope in cfg["scopes"]:
        label=scope["label"]
        root=scope["root"]
        before,dirs=inventory(root)
        expected=scope["expected"]
        require(len(before)==scope["files"] and set(before)==set(expected),"sealed scope closed-set mismatch: "+label)
        scope_raw={}
        for rel in sorted(expected):
            data,identity=read_exact(root,rel)
            pin=expected[rel]
            require(identity==before[rel],"scope identity changed before archive: "+label+"/"+rel)
            require(len(data)==pin["bytes"] and digest(data)==pin["sha256"],"sealed input hash mismatch: "+label+"/"+rel)
            require(not any(token in data for token in forbidden),"private-key PEM material found; refusing entire bundle")
            scope_raw[rel]=data
            member=label+"/"+rel
            raw[member]=data
            rows.append({"scope":label,"path":rel,"original_path":root+"/"+rel,"zip_member":member,
                         "bytes":len(data),"sha256":digest(data),"original_metadata":identity})
        for rel,pin in scope["anchors"].items():
            require(len(scope_raw[rel])==pin["bytes"] and digest(scope_raw[rel])==pin["sha256"],"independent seal mismatch")
        manifest=json.loads(scope_raw[scope["manifest"]])
        sealed=listed_records(manifest)
        for rel,pin in scope["anchors"].items():
            require(rel not in sealed or sealed[rel]==pin,"seal anchor conflict")
            sealed[rel]=pin
        require(sealed==expected,"sealed manifest does not match exact expected closed set")
        require(sum(len(x) for x in scope_raw.values())==scope["bytes"],"scope byte total mismatch")
        if label.startswith("native-"):
            seal=json.loads(scope_raw["SOURCE_SEAL.json"])
            require(seal["proposalPinSHA256"]==digest(scope_raw["PROPOSAL_PIN.json"]),"Native seal-to-pin mismatch")
            require(seal["status"]=="SOURCE_PROPOSAL_ONLY_NOT_RUN","Native sealed status changed")
            for rel,pin in seal["files"].items():
                require(pin==expected[rel],"Native tool seal mismatch")
        if label=="toc-common":
            handoff=json.loads(scope_raw["HANDOFF.json"])
            require(handoff["manifest"]["sha256"]==digest(scope_raw["PACKAGE_MANIFEST.json"]),"common handoff mismatch")
            require(handoff["source_only"] is True and handoff["swift_runs"]==0 and handoff["native_runs"]==0,"TOC status mismatch")
        if label=="owner-audit":
            handoff=json.loads(scope_raw["HANDOFF.json"])
            require(handoff["target"]==cfg["source_head"] and handoff["Source"]==cfg["source_tree"],"audit target mismatch")
            require(handoff["existing_signatures"]["valid"]==55 and handoff["existing_signatures"]["new_approval"] is False,"audit historical signature boundary changed")
            coverage=handoff["current_protected_coverage"]
            require((coverage["paths"],coverage["exact"],coverage["stale"],coverage["no_approved_record"])==(69,31,24,14),"audit current coverage changed")
            require(handoff["full_release_gate"]=="NOT_RUN" and handoff["current_external_key_provisioning"]=="NOT_PROBED","audit gate boundary changed")
            require(handoff["capsule"]["sha256"]==digest(scope_raw["OWNER_VERIFICATION_RAW.zip"]),"audit inner capsule mismatch")
            with zipfile.ZipFile(io.BytesIO(scope_raw["OWNER_VERIFICATION_RAW.zip"])) as inner:
                names=inner.namelist()
                inner_expected=set(listed_records(manifest))|{"FINAL_MANIFEST.json"}
                require(len(names)==37 and len(names)==len(set(names)) and set(names)==inner_expected,"audit inner capsule closed set mismatch")
                require(inner.testzip() is None,"audit inner capsule CRC failure")
                for name in names:
                    require(inner.read(name)==scope_raw[name],"audit inner capsule raw member mismatch")
        snapshots[label]={"root":root,"files":before,"directories":dirs}
        closure.append({"label":label,"root":root,"files":len(before),"bytes":scope["bytes"],
                        "manifest":scope["manifest"],"anchors":scope["anchors"],"closed_set_verified":True})
    require(len(raw)==cfg["total_files"] and sum(map(len,raw.values()))==cfg["total_bytes"],"bundle total mismatch")
    for newer,older in [("native-v3-review2","native-v3"),("native-v3-review3","native-v3-review2")]:
        for name in ("mac_producer.py","oracle_controller.py","reviewed_runtime.py","stream_format.py"):
            require(raw[newer+"/baseline_"+name]==raw[older+"/"+name],"Native preserved-generation inverse mismatch")
    require(current_free()>=floor+cap,"rootfs floor/reserve lost before output creation")
    out.mkdir(mode=0o755)
    guards=[]
    def guard(step,extra=0):
        free=current_free()
        used=allocated(out)
        require(free>=floor+cap,"rootfs floor plus full reserve lost at "+step)
        require(used+extra<=cap,"allocated output budget exceeded at "+step)
        guards.append({"step":step,"rootfs_free_bytes":free,"allocated_bytes":used,"planned_additional_bytes":extra})
    def write(name,data):
        require("/" not in name and name not in ("",".",".."),"unexpected output filename")
        guard("before "+name,((len(data)+4095)//4096)*4096)
        fd=os.open(out/name,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW|os.O_CLOEXEC,0o644)
        try:
            with os.fdopen(fd,"wb",closefd=False) as f:
                f.write(data)
                f.flush()
                os.fsync(f.fileno())
        finally:
            os.close(fd)
        require((out/name).read_bytes()==data,"new artifact readback mismatch")
        guard("after "+name)
    write("PACKAGER.py",PACKAGER_SOURCE.encode("utf-8"))
    write("INPUT_PINS.json",json_bytes(cfg))
    write("README.md",README_TEXT.encode("utf-8"))
    manifest={"schema":"otzaria.source-owner-checkpoint.manifest.v1","source_head":cfg["source_head"],
              "source_tree":cfg["source_tree"],"files":rows,"file_count":len(rows),
              "payload_bytes":cfg["total_bytes"],"scopes":closure,"archive_names_are_relative":True,
              "no_normalization":True,"zip":"PRESERVATION_RAW.zip"}
    write("SOURCE_MANIFEST.json",json_bytes(manifest))
    zip_name="PRESERVATION_RAW.zip"
    guard("before ZIP",cfg["total_bytes"]+len(raw)*512+1048576)
    zfd=os.open(out/zip_name,os.O_RDWR|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW|os.O_CLOEXEC,0o644)
    try:
        with os.fdopen(zfd,"w+b",closefd=False) as stream:
            with zipfile.ZipFile(stream,"w",compression=zipfile.ZIP_DEFLATED,compresslevel=6,allowZip64=False) as z:
                for row in rows:
                    zi=zipfile.ZipInfo(row["zip_member"],(2026,11,28,0,0,0))
                    zi.create_system=3
                    zi.compress_type=zipfile.ZIP_DEFLATED
                    zi.external_attr=(stat.S_IFREG|row["original_metadata"]["mode"])<<16
                    z.writestr(zi,raw[row["zip_member"]])
            stream.flush()
            os.fsync(stream.fileno())
    finally:
        os.close(zfd)
    guard("after ZIP")
    with zipfile.ZipFile(out/zip_name) as z:
        names=z.namelist()
        require(len(names)==len(set(names))==121 and set(names)==set(raw),"outer ZIP closed membership mismatch")
        require(z.testzip() is None,"outer ZIP CRC failure")
        for row in rows:
            data=z.read(row["zip_member"])
            require(len(data)==row["bytes"] and digest(data)==row["sha256"] and data==raw[row["zip_member"]],"outer ZIP raw member readback mismatch")
    for scope in cfg["scopes"]:
        label=scope["label"]
        files,dirs=inventory(scope["root"])
        require(files==snapshots[label]["files"] and dirs==snapshots[label]["directories"],"original scope changed during preservation")
        for rel in sorted(files):
            data,identity=read_exact(scope["root"],rel)
            require(identity==files[rel] and data==raw[label+"/"+rel],"original source final rejoin mismatch")
    guard("after original-source final rejoin")
    zip_data=(out/zip_name).read_bytes()
    result={"schema":"otzaria.source-owner-checkpoint.result.v1","status":"PRESERVED_AND_VERIFIED",
            "time_utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "source_head":cfg["source_head"],"source_tree":cfg["source_tree"],
            "scopes":len(cfg["scopes"]),"files":121,"payload_bytes":cfg["total_bytes"],
            "zip":{"path":zip_name,"bytes":len(zip_data),"sha256":digest(zip_data),"members":121,
                   "crc_verified":True,"all_member_bytes_and_sha256_verified":True},
            "independent_seals_and_closed_sets_verified":True,
            "native_generation_baselines_byte_exact":True,
            "nested_owner_capsule_bytes_unchanged":True,"nested_owner_capsule_members_verified":37,
            "all_original_bytes_and_identity_metadata_rejoined":True,
            "symlinks_hardlinks_nonregular_extra_leaves_or_directories":0,
            "original_atime_not_claimed_unchanged":True,
            "original_scope_writes":False,"product_or_git_writes":False,"data_writes":False,
            "preserved_source_execution_imports_tests_compilation_native_auth_signing":False,
            "new_approval_or_release_qualification":False,
            "owner_audit":{"historical_valid_unexpired":55,"current_paths":69,"matching":31,"stale":24,"missing_approved_record":14,
                           "full_release_gate":"NOT_RUN","current_external_key_provisioning":"NOT_PROBED"},
            "resources":{"root_floor_bytes":floor,"full_reserve_and_allocated_cap_bytes":cap,
                         "rootfs_free_before":initial_free,"before_result_allocated_bytes":allocated(out),"guard_events":guards}}
    write("PRESERVATION_RESULT.json",json_bytes(result))
    artifact_rows=[]
    for p in sorted(out.iterdir()):
        require(p.is_file() and not p.is_symlink(),"unexpected output entry")
        b=p.read_bytes()
        artifact_rows.append({"path":p.name,"bytes":len(b),"sha256":digest(b)})
    handoff={"schema":"otzaria.source-owner-checkpoint.handoff.v1","status":"PRESERVED_ONLY_NOT_RELEASE_QUALIFIED",
             "output":str(out),"source_head":cfg["source_head"],"source_tree":cfg["source_tree"],
             "files_preserved":121,"original_payload_bytes":cfg["total_bytes"],"zip_members":121,
             "artifacts_excluding_handoff":artifact_rows,"source_scopes_unchanged":True,
             "root_repository_writes":False,"root_checkpoint_commit":"NOT_PERFORMED",
             "resources":{"root_floor_bytes":floor,"reserve_and_cap_bytes":cap,"free_before_handoff":current_free(),
                          "allocated_before_handoff":allocated(out)}}
    write("HANDOFF.json",json_bytes(handoff))
    expected_outputs={"PACKAGER.py","INPUT_PINS.json","README.md","SOURCE_MANIFEST.json",
                      "PRESERVATION_RAW.zip","PRESERVATION_RESULT.json","HANDOFF.json"}
    require({p.name for p in out.iterdir()}==expected_outputs,"unexpected final output entry")
    guard("final complete scope")
    outputs=[]
    for p in sorted(out.iterdir()):
        b=p.read_bytes()
        outputs.append({"path":p.name,"bytes":len(b),"sha256":digest(b),"allocated_bytes":p.stat().st_blocks*512})
    print(json.dumps({"status":"PRESERVED_AND_VERIFIED","output":str(out),"files":outputs,
                      "archive_members":121,"original_payload_bytes":cfg["total_bytes"],
                      "allocated_total_bytes":allocated(out),"rootfs_free_after":current_free(),
                      "root_floor_plus_full_reserve":floor+cap,"original_scopes_unchanged":True,
                      "source_tests_or_git_execution":False},sort_keys=True))

main()
