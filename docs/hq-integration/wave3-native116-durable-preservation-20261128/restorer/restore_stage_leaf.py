#!/usr/bin/env python3
"""Future Root-admitted opaque stage-leaf restore; no source-tree extraction."""
if not __debug__:
    raise RuntimeError("OPTIMIZED_RESTORER_REFUSED")
from pathlib import Path
import argparse,base64,datetime,hashlib,json,os,selectors,shlex,signal,stat,struct,subprocess,sys,time,uuid

FAMILY=Path("/home/ubuntu/otzaria-wave3-native116-stage-leaf-restore-execution-20261128")
HISTORICAL_FAMILIES=json.loads("[{\"path\":\"/home/ubuntu/otzaria-wave3-native116-stage-leaf-preflight-proposal-20261128\",\"allocatedCap\":630784,\"lastObservedAllocated\":589824,\"sourceSeal\":{\"bytes\":1869,\"sha256\":\"8390416645ed999d535df0e623f3e89dad40a070bc6067a238a01c8fd0c0c746\"}},{\"path\":\"/home/ubuntu/otzaria-wave3-native116-stage-leaf-restore-proposal-20261128\",\"allocatedCap\":602112,\"lastObservedAllocated\":602112,\"sourceSeal\":{\"bytes\":3877,\"sha256\":\"f35f15423c1db350b26741131aa7c340cda2d5f58f994b9e31f39a71f114e817\"}},{\"path\":\"/home/ubuntu/otzaria-wave3-native116-stage-leaf-restore-readback-binding-proposal-20261128\",\"allocatedCap\":36864,\"lastObservedAllocated\":36864,\"sourceSeal\":{\"bytes\":1573,\"sha256\":\"11d28e6b1c20abee6cac8ffd273e2f15fa8ab9e83f0f68ed5456cfb37fc96ff0\"}}]")
ADMISSION=FAMILY/"admission"
RUN=FAMILY/"restore-once"
ROOT_FLOOR=1593835520
FAMILY_CAP=2097152
SOURCE_CAP=106496
ADMISSION_CAP=196608
RUNTIME_CAP=524288
NEW_FAMILY_CAP=827392
MAX_ENTRIES=256
MAX_DEPTH=3
OVERALL_SECONDS=2700
STREAM_SECONDS=1200
MAC_FLOOR=2415919104
MAC_METADATA_RESERVE=4194304
REPOSITORY="davidpovarsky/Maktabah-preserved-evidence"
REPOSITORY_ID=1474927804
RELEASE_ID=461304898
ASSET_ID=803618998
ASSET_NAME="native116-remaining-original-evidence-staged-20261128.tar.gz"
ARCHIVE_BYTES=1272863810
ARCHIVE_SHA="f427758916a543b58f230c87e3d5eff1067e7db47f79a46d984315f8e155b556"
SNAPSHOT_SHA="424c2e2f95b3616e39b51cbacc621678dc2899ceba857a2dd42b72b0a0597cc4"
MANIFEST_SHA="a8faa73411de67ead8f98856fe25cb3a368d5adb91f1d51f5e3103c9795299c0"
READBACK_SOURCE_SEAL="c37abe5dacd65b785c6d6fd0e0aded3d3eac3b5fff1a640691495bc3cb3776fc"
READBACK_RESULT_PATH="/home/ubuntu/otzaria-wave3-native116-readback-dependencies-20261128/readback/FINAL_RESULT.json"
COLLECTOR_FINAL_SHA="8d49d1a2497fdfd1a4fc4bfc1c0e680e7a70fe29b02c03915aafb0a0a833304a"
COLLECTOR_TRANSCRIPT_SHA="bfaaf15056bfc2af0b939437b985bd7fb9d67d2dd967124f6bae09968cadd118"
MAC_SHA256="e3c66535982b23080c4d10d89fb1a9f55f6c0b4ab786f47b5624d4af6bb452be"
MAC_BYTES=23551
EXPECTED=json.loads("{\"parent\":{\"acl\":null,\"allocatedBytes\":0,\"atimeNS\":\"1795845249365515805\",\"birthtimeNS\":\"1795845188978746795\",\"bytes\":128,\"ctimeNS\":\"1795845188979074585\",\"device\":16777232,\"flags\":0,\"gid\":20,\"inode\":80215398,\"kind\":\"directory\",\"mode\":16832,\"mtimeNS\":\"1795845188979074585\",\"nlink\":4,\"pathBase64\":\"\",\"rdev\":0,\"uid\":501,\"xattrs\":[]},\"terminal\":{\"acl\":null,\"allocatedBytes\":65536,\"atimeNS\":\"1795845386429359912\",\"birthtimeNS\":\"1795845188978882252\",\"bytes\":65536,\"ctimeNS\":\"1795845386291846079\",\"device\":16777232,\"flags\":0,\"gid\":20,\"inode\":80215399,\"kind\":\"file\",\"mode\":33152,\"mtimeNS\":\"1795845386291846079\",\"nlink\":1,\"pathBase64\":\"U1RBR0VfVEVSTUlOQUwuanNvbg==\",\"rdev\":0,\"uid\":501,\"xattrs\":[]},\"archive\":{\"acl\":null,\"allocatedBytes\":1272864768,\"atimeNS\":\"1795845385698193451\",\"birthtimeNS\":\"1795845188979067835\",\"bytes\":1272863810,\"ctimeNS\":\"1795845386291328289\",\"device\":16777232,\"flags\":0,\"gid\":20,\"inode\":80215400,\"kind\":\"file\",\"mode\":33024,\"mtimeNS\":\"1795845337662706536\",\"nlink\":1,\"pathBase64\":\"bmF0aXZlMTE2LXJlbWFpbmluZy1vcmlnaW5hbC1ldmlkZW5jZS50YXIuZ3o=\",\"rdev\":0,\"uid\":501,\"xattrs\":[]}}")
SLOTS={"FINAL_RESULT.json":32768,"SSH_ALIAS.json":4096,"ssh-alias.stderr":16384,"PROCESS_LEDGER.json":16384,"TERMINAL.json":16384,"receiver.stdout":32768,"receiver.stderr":65536,"getter.stderr":65536,"repository.stdout":16384,"repository.stderr":4096,"release.stdout":32768,"release.stderr":4096,"assets.stdout":32768,"assets.stderr":4096}
STARTED=time.monotonic()
DEADLINE=STARTED+OVERALL_SECONDS
ORIGINAL_PARENT=os.getppid()
PROCESS_LEDGER=[]
SOURCE_IDENTITIES={}
ADMISSION_IDENTITIES={}
SOURCE_SEAL_SHA=None
ADMISSION_SHA=None

def require(value,code):
    if not value:raise RuntimeError(code)

def canonical(value):
    return (json.dumps(value,sort_keys=True,indent=2,ensure_ascii=True)+"\n").encode("ascii")

def digest(raw):return hashlib.sha256(raw).hexdigest()

def utc():return datetime.datetime.now(datetime.timezone.utc).isoformat()

def stable(s):
    return (s.st_dev,s.st_ino,s.st_mode,s.st_uid,s.st_gid,s.st_nlink,
            s.st_size,s.st_mtime_ns,s.st_ctime_ns)

def error_record(error,stage):
    return {"stage":stage,"type":type(error).__name__,
            "errno":error.errno if isinstance(error,OSError) else None,
            "code":str(error)[:200] if type(error) is RuntimeError else None}

def free():
    v=os.statvfs("/")
    return v.f_bavail*v.f_frsize

def closed_inventory(root,maximum_entries=MAX_ENTRIES):
    require(root.resolve(strict=True)==root,"NO_SYMLINK_SCOPE")
    result={"files":{},"directories":{},"allocatedBytes":0}
    pending=[(root,"",0)]
    while pending:
        path,relative,depth=pending.pop()
        s=path.lstat()
        require(s.st_dev==os.stat("/").st_dev and s.st_uid==s.st_gid==1001,
                "OWNED_ROOTFS_SCOPE")
        require(depth<=MAX_DEPTH and len(result["files"])+len(result["directories"])<maximum_entries,
                "BOUNDED_METADATA_SCOPE")
        result["allocatedBytes"]+=s.st_blocks*512
        if stat.S_ISDIR(s.st_mode):
            result["directories"][relative]=stable(s)
            with os.scandir(path) as it:
                children=sorted(it,key=lambda item:item.name)
            for item in children:
                require(item.name not in ("",".","..") and "/" not in item.name,
                        "EXACT_CHILD_NAME")
                pending.append((Path(item.path),relative+"/"+item.name if relative else item.name,depth+1))
        else:
            require(stat.S_ISREG(s.st_mode) and s.st_nlink==1,"ONLY_REGULAR_SINGLE_LINK_METADATA")
            result["files"][relative]=stable(s)
    return result

def historical_allocation():
    total=0
    for row in HISTORICAL_FAMILIES:
        value=closed_inventory(Path(row["path"]))
        require(value["allocatedBytes"]<=row["allocatedCap"],"PRESERVED_HISTORICAL_FAMILY_CAP")
        total+=value["allocatedBytes"]
    return total

def verify_preserved_history():
    for row in HISTORICAL_FAMILIES:
        path=Path(row["path"]);before=closed_inventory(path);pin=row["sourceSeal"]
        require(before["allocatedBytes"]<=row["allocatedCap"],"PRESERVED_HISTORICAL_FAMILY_CAP")
        raw=read_source(path/"SOURCE_SEAL.json",pin["bytes"])
        require(len(raw)==pin["bytes"] and digest(raw)==pin["sha256"],"PRESERVED_HISTORY_SOURCE_SEAL")
        require(closed_inventory(path)==before,"PRESERVED_HISTORY_CHANGED_DURING_BINDING")
        for relative,identity in {**before["directories"],**before["files"]}.items():
            key=str(path/relative)
            if key in SOURCE_IDENTITIES:
                require(SOURCE_IDENTITIES[key]==identity,"PRESERVED_HISTORY_IDENTITY_CHANGED")
            else:SOURCE_IDENTITIES[key]=identity

def allocation():
    return historical_allocation()+closed_inventory(FAMILY)["allocatedBytes"]

def same_pins():
    for table in (SOURCE_IDENTITIES,ADMISSION_IDENTITIES):
        for path,expected in table.items():
            require(stable(os.stat(path,follow_symlinks=False))==expected,"PINNED_LOCAL_INPUT_CHANGED")

def guard(addition=0):
    require(time.monotonic()<DEADLINE,"ORIGINAL_OVERALL_2700_SECONDS")
    require(os.getppid()==ORIGINAL_PARENT,"ORIGINAL_PARENT_DETACHED")
    require(free()-addition>=ROOT_FLOOR,"ORIGINAL_ROOT_FLOOR")
    own=closed_inventory(FAMILY)
    require(own["allocatedBytes"]+addition<=NEW_FAMILY_CAP,"NEW_FAMILY_FINITE_SHARE")
    require(own["allocatedBytes"]+historical_allocation()+addition<=FAMILY_CAP,
            "COMBINED_STAGE_FAMILY_2MIB")
    if RUN.exists():
        require(closed_inventory(RUN)["allocatedBytes"]+addition<=RUNTIME_CAP,"RUNTIME_ALLOCATION_CAP")
    same_pins()

def read_source(path,maximum):
    require(path.is_absolute() and path.resolve(strict=True)==path,"NO_FOLLOW_INPUT")
    fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW|os.O_NOATIME)
    try:
        before=os.fstat(fd)
        require(stat.S_ISREG(before.st_mode) and before.st_nlink==1 and before.st_uid==1001
                and before.st_size<=maximum,"PRIVATE_BOUNDED_SOURCE")
        raw=bytearray()
        while True:
            part=os.read(fd,min(65536,maximum+1-len(raw)))
            if not part:break
            raw.extend(part);require(len(raw)<=maximum,"BOUNDED_INPUT")
        require(stable(os.fstat(fd))==stable(before) and stable(path.lstat())==stable(before),
                "INPUT_CHANGED_DURING_READ")
        return bytes(raw)
    finally:os.close(fd)

def checked_sha(value):
    require(type(value) is str and len(value)==64 and all(x in "0123456789abcdef" for x in value),
            "EXACT_SHA256")
    return value

def verify_seal(expected):
    global SOURCE_SEAL_SHA
    require(os.getuid()==os.geteuid()==1001 and os.getgid()==1001
            and sys.flags.isolated and sys.dont_write_bytecode,"UBUNTU_PYTHON_I_B_REQUIRED")
    require("GH_DEBUG" not in os.environ,"NO_AUTHENTICATED_DEBUG_ENVIRONMENT")
    require(Path(__file__).resolve()==FAMILY/"restore_stage_leaf.py","FIXED_ENTRYPOINT")
    raw=read_source(FAMILY/"SOURCE_SEAL.json",65536)
    require(digest(raw)==checked_sha(expected),"ROOT_REVIEWED_SOURCE_SEAL")
    seal=json.loads(raw)
    require(seal["schema"]=="otzaria.native116-stage-leaf-restorer-source/2"
            and seal["status"]=="SOURCE_ONLY_UNRUN" and seal["familyPath"]==str(FAMILY)
            and seal["combinedFamilyCap"]==FAMILY_CAP and seal["newFamilyCap"]==NEW_FAMILY_CAP
            and seal["sourceCap"]==SOURCE_CAP and seal["admissionCap"]==ADMISSION_CAP
            and seal["runtimeCap"]==RUNTIME_CAP and seal["historicalFamilies"]==HISTORICAL_FAMILIES,
            "CLOSED_RESTORER_SOURCE_SCHEMA")
    require(SOURCE_CAP+ADMISSION_CAP+RUNTIME_CAP==NEW_FAMILY_CAP
            and NEW_FAMILY_CAP+sum(x["allocatedCap"] for x in HISTORICAL_FAMILIES)==FAMILY_CAP,
            "EXACT_FOUR_FAMILY_RESOURCE_PARTITION")
    verify_preserved_history()
    source_files=set(seal["files"])|{"SOURCE_SEAL.json"}
    inv=closed_inventory(FAMILY)
    actual={n for n in inv["files"] if n.split("/",1)[0] not in ("admission","restore-once")}
    actual_dirs={n for n in inv["directories"] if n.split("/",1)[0] not in ("admission","restore-once")}
    require(actual==source_files and actual_dirs==set(seal["directories"]),
            "COMPLETE_RESTORER_SOURCE_MEMBERSHIP")
    source_alloc=FAMILY.lstat().st_blocks*512
    for name in source_files:
        require(not name.startswith("/") and "\\" not in name and all(x not in ("",".","..") for x in name.split("/")),
                "CLOSED_SOURCE_RELATIVE_PATH")
        source_alloc+=(FAMILY/name).lstat().st_blocks*512
    for name in inv["directories"]:
        if name and name.split("/",1)[0] not in ("admission","restore-once"):
            source_alloc+=(FAMILY/name).lstat().st_blocks*512
    require(source_alloc<=SOURCE_CAP,"SOURCE_ALLOCATED_CAP")
    for name,pin in seal["files"].items():
        body=read_source(FAMILY/name,pin["bytes"])
        require(len(body)==pin["bytes"] and digest(body)==pin["sha256"],"SOURCE_BYTE_PIN")
        SOURCE_IDENTITIES[str(FAMILY/name)]=stable((FAMILY/name).lstat())
    SOURCE_IDENTITIES[str(FAMILY/"SOURCE_SEAL.json")]=stable((FAMILY/"SOURCE_SEAL.json").lstat())
    require(seal["files"]["mac_restore_stage_leaf.py"]=={"bytes":MAC_BYTES,"sha256":MAC_SHA256},
            "EXACT_RECEIVER_SOURCE_PIN")
    SOURCE_SEAL_SHA=expected
    return seal

def evidence(name,admission):
    require(name in admission["files"] and name not in ("",".","..") and "/" not in name and "\\" not in name,
            "ONLY_FIXED_ADMISSION_LEAF")
    pin=admission["files"][name]
    raw=read_source(ADMISSION/name,pin["bytes"])
    require(len(raw)==pin["bytes"] and digest(raw)==checked_sha(pin["sha256"]),"ROOT_PINNED_ADMISSION_BYTES")
    ADMISSION_IDENTITIES[str(ADMISSION/name)]=stable((ADMISSION/name).lstat())
    return raw

def verify_full_qualification(admission):
    raw=evidence("FULL_READBACK_RESULT.json",admission)
    require(len(raw)==65536,"ORIGINAL_COMPLETE_RESULT_SLOT")
    outer=json.loads(raw)
    require(outer["requestedName"]=="VERIFIED_POST_TIMEOUT_READBACK","ACTUAL_READBACK_FINAL_MARKER")
    q=outer["value"]
    require(q["schema"]=="otzaria.native116-readback-1800/1"
            and q["status"]=="THREE_COMPLETE_PAYLOADS_FULLY_READ_BACK_AFTER_PRESERVED_TIMEOUT"
            and q["proposalSealSHA256"]==READBACK_SOURCE_SEAL
            and q["repository"]=={"id":REPOSITORY_ID,"full_name":REPOSITORY,"private":True}
            and q["release"]["id"]==RELEASE_ID and q["release"]["draft"] is True
            and q["allAssetIDs"]==[803254522,803254562,803257093,803618998]
            and q["completeAuthenticatedPayloadCount"]==3 and q["preservedIncompleteAssetCount"]==1
            and q["fullTarMemberVerification"] is True and q["originalSourceRetained"] is True
            and q["sourceModified"] is False and q["uploadAttempted"] is False
            and q["partialPrefixReused"] is False and q["postCalls"]==0
            and q["retirementAuthorized"] is False,"FULL_QUALIFICATION_BOUNDARY")
    expected={803254522:(7106913,SNAPSHOT_SHA),803254562:(160216,MANIFEST_SHA),
              ASSET_ID:(ARCHIVE_BYTES,ARCHIVE_SHA)}
    require(type(q["fullReadbacks"]) is list and len(q["fullReadbacks"])==3,"ALL_THREE_ACTUAL_READBACKS")
    seen=set()
    for proof in q["fullReadbacks"]:
        aid=proof["asset"]["id"];require(aid in expected and aid not in seen,"EXACT_DISTINCT_READBACK_ASSET")
        seen.add(aid);size,sha=expected[aid]
        require(proof["completeAuthenticatedReadback"]=={"bytes":size,"sha256":sha,"exit":0},
                "FULL_GET_SIZE_SHA_AND_CLEAN_EXIT")
        if aid==ASSET_ID:
            mv=proof["memberVerification"]
            require(mv["membersVerified"]==65011 and mv["uniquePayloadsVerified"]==65010
                    and mv["originalEntries"]==112092 and mv["snapshotSHA256"]==SNAPSHOT_SHA
                    and mv["everyOriginalRegularFileMapsToVerifiedPayload"] is True
                    and mv["fullTreeRestorePerformed"] is False and mv["selfContained"] is False,
                    "COMPLETE_ORIGINAL_MEMBER_VERIFICATION")
        else:require(proof["memberVerification"] is None,"SMALL_PAYLOAD_VERIFIED_AS_BYTES")
    for side,name in (("sourceBefore","SOURCE_BEFORE.json"),("sourceAfter","SOURCE_AFTER.json")):
        body=evidence(name,admission);pin=q[side]
        require(pin["bytes"]==len(body) and pin["sha256"]==digest(body),"ORIGINAL_SOURCE_RESULT_PIN")
        value=json.loads(body)
        require(value["mode"]=="reverify" and value["status"]=="SOURCE_VERIFIED_READ_ONLY"
                and value["snapshotSHA256"]==SNAPSHOT_SHA and value["fullCurrentSourceEqual"] is True
                and value["sourceModified"] is False,"ORIGINAL_FULL_SOURCE_BOUNDARY")
    jb=evidence("FULL_READBACK_JOB.json",admission);job=json.loads(jb)["job"]
    require(job["host"]=="host_299cf75f6b338ecd" and job["status"]=="succeeded" and job["exit_code"]==0
            and job["output_truncated"] is False,"ACTUAL_SUCCESSFUL_READBACK_JOB")
    require(job["id"]=="job_a02eee978d8f" and type(job["output"]) is str,
            "EXACT_COMPLETED_READBACK_JOB")
    output_raw=job["output"].encode("utf-8")
    require(len(output_raw)==571
            and digest(output_raw)=="de67fe8cf8fa16ae0fbd1d3f75d6888f7262fa35adbc5104012efdafb9fd2d00",
            "EXACT_TWO_LINE_ACTUAL_JOB_OUTPUT")
    lines=job["output"].split("\n")
    require(len(lines)==2,"EXACT_ADMISSION_AND_FINAL_LINES")
    require(json.loads(lines[0])=={
        "rootAdmission":"/home/ubuntu/otzaria-wave3-native116-readback-dependencies-root-admission-20261128/ADMISSION.json",
        "bytes":1650,"sha256":"3ad47febd3d652c8e8ff707b665ec5fe457e704800373fbaa06042622d6c6ac1",
        "runtimeOwnerUID":1001,"all14InverseAnd12DependenciesExact":True},
        "ACTUAL_READBACK_ROOT_ADMISSION_PREFIX")
    require(digest(raw)=="e9242bcf55ad96d02f5d5ad876dc65813a40699258406b360ead957cf5cda702",
            "EXACT_COMPLETED_FULL_READBACK_RESULT")
    output=json.loads(lines[1])
    require(output=={"status":q["status"],"receipt":{"path":READBACK_RESULT_PATH,
            "bytes":len(raw),"sha256":digest(raw)}},"ACTUAL_JOB_OUTPUT_JOINS_THE_FULL_RESULT")
    return q,digest(raw),job["id"]

def verify_admission(expected):
    global ADMISSION_SHA
    require(ADMISSION.resolve(strict=True)==ADMISSION,"FIXED_ADMISSION_NO_SYMLINK")
    raw=read_source(ADMISSION/"ADMISSION.json",65536)
    require(digest(raw)==checked_sha(expected),"EXPLICIT_ROOT_ADMISSION_SHA")
    a=json.loads(raw)
    require(a["schema"]=="otzaria.native116-stage-leaf-restore-root-admission/1"
            and a["status"]=="ROOT_APPROVED_EXACT_OPAQUE_STAGE_RESTORE"
            and a["sourceSealSHA256"]==SOURCE_SEAL_SHA and a["assetID"]==ASSET_ID
            and a["sourceTreeRestorationAuthorized"] is False and a["newUploadAuthorized"] is False,
            "EXPLICIT_ROOT_SINGLE_RESTORE_AUTHORITY")
    names={"RESTORATION_POINTER.json","FULL_READBACK_RESULT.json","FULL_READBACK_JOB.json",
           "SOURCE_BEFORE.json","SOURCE_AFTER.json","DURABLE_GIT_READBACK.json","RETIREMENT_RECEIPT.json"}
    require(set(a["files"])==names,"CLOSED_SEVEN_ADMISSION_EVIDENCE_LEAVES")
    inv=closed_inventory(ADMISSION)
    require(set(inv["files"])==names|{"ADMISSION.json"} and set(inv["directories"])=={""}
            and inv["allocatedBytes"]<=ADMISSION_CAP,"EXACT_BOUNDED_ADMISSION_MEMBERSHIP")
    ADMISSION_IDENTITIES[str(ADMISSION/"ADMISSION.json")]=stable((ADMISSION/"ADMISSION.json").lstat())
    q,qsha,qjob=verify_full_qualification(a)
    pointerraw=evidence("RESTORATION_POINTER.json",a);pointer=json.loads(pointerraw)
    require(pointer["schema"]=="otzaria.native116-stage-opaque-restoration-pointer/1"
            and pointer["sourceSealSHA256"]==SOURCE_SEAL_SHA
            and pointer["asset"]=={"repositoryID":REPOSITORY_ID,"repository":REPOSITORY,
                "releaseID":RELEASE_ID,"id":ASSET_ID,"name":ASSET_NAME,"bytes":ARCHIVE_BYTES,"sha256":ARCHIVE_SHA}
            and pointer["destination"]=="/Users/m1/otzaria-native116-staged-archive-20261128/native116-remaining-original-evidence.tar.gz"
            and pointer["originalMetadata"]==EXPECTED
            and pointer["collectorResultSHA256"]==COLLECTOR_FINAL_SHA
            and pointer["collectorTranscriptSHA256"]==COLLECTOR_TRANSCRIPT_SHA
            and pointer["fullReadbackResultSHA256"]==qsha
            and pointer["restoresOriginalInodeCtimeBirthtimeOrAllocation"] is False
            and pointer["extractsOriginalTree"] is False,"EXACT_OPAQUE_RESTORATION_POINTER")
    durable=json.loads(evidence("DURABLE_GIT_READBACK.json",a))
    require(durable["schema"]=="otzaria.native116-stage-restoration-durable-root-proof/1"
            and durable["status"]=="ROOT_REVIEWED_REMOTE_GIT_BYTES_EQUAL"
            and durable["pointerSHA256"]==digest(pointerraw)
            and durable["sourceSealSHA256"]==SOURCE_SEAL_SHA
            and durable["completeRemoteReadback"] is True,"ROOT_ADMITTED_DURABLE_POINTER_PROOF")
    require(type(durable["commit"]) is str and len(durable["commit"])==40
            and all(c in "0123456789abcdef" for c in durable["commit"]),"EXACT_DURABLE_GIT_COMMIT")
    retired=json.loads(evidence("RETIREMENT_RECEIPT.json",a))
    require(retired["schema"]=="otzaria.native116-exact-stage-retirement-root-proof/1"
            and retired["status"]=="ROOT_VERIFIED_EXACT_STAGE_LEAF_RETIRED"
            and retired["path"]==pointer["destination"] and retired["originalLeafMetadata"]==EXPECTED["archive"]
            and retired["pointerSHA256"]==digest(pointerraw) and retired["fullReadbackResultSHA256"]==qsha
            and retired["durableGitCommit"]==durable["commit"]
            and retired["removed"] is True and retired["otherSiblingContentsPreserved"] is True
            and retired["originalNativeTreeUnmodified"] is True,"ROOT_ADMITTED_EXACT_RETIREMENT_PROOF")
    checked_sha(retired["actualRetirementReceiptSHA256"]);checked_sha(retired["predeleteAcknowledgedSHA256"])
    # The pinned Root admission is the explicit approval trust boundary for the
    # future Git and retirement proof adapters. No absence-based approval is inferred.
    ADMISSION_SHA=expected
    return {"admission":a,"pointer":pointer,"pointerSHA256":digest(pointerraw),
            "qualificationSHA256":qsha,"qualificationJob":qjob,"qualifiedAssets":q["assets"],
            "durableGitCommit":durable["commit"],"retirement":retired}

def process_identity(pid):
    raw = Path('/proc/%d/stat' % pid).read_text()
    fields = raw[raw.rfind(')') + 2:].split()
    assert len(fields) >= 20
    return {'pid': pid, 'pgid': int(fields[2]), 'session': int(fields[3]),
            'startTicks': fields[19]}

def stop_owned(process, original):
    # Never poll/reap before a signal decision. An unreaped Popen leader cannot
    # have its PID reused. Every child was started in its own session/group.
    if process.returncode is not None:
        return
    current = process_identity(process.pid)
    assert current['pgid'] == current['session'] == process.pid
    assert original is None or current == original
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        current = process_identity(process.pid)
        assert current['pgid'] == current['session'] == process.pid
        assert original is None or current == original
        os.killpg(process.pid, signal.SIGKILL)
        process.wait(timeout=20)

class ReservedFiles:
    def __init__(self):
        self.fd = None
        self.files = {}
        self.closed = set()
        self.reserved = set()

    def create(self):
        require(not RUN.exists() and not RUN.is_symlink(), "EXCLUSIVE_ATTEMPT_MUST_BE_ABSENT")
        guard(sum(SLOTS.values()) + (len(SLOTS) + 4) * 4096)
        parent = os.open(FAMILY, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            os.mkdir(RUN.name, 0o700, dir_fd=parent)
            os.fsync(parent)
            self.fd = os.open(RUN.name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=parent)
        finally:
            os.close(parent)
        # FINAL_RESULT is allocated first. Every later failure can be recorded
        # using its already allocated bytes, without a new file after refusal.
        for name, size in SLOTS.items():
            guard(size + 4096)
            fd = os.open(name, os.O_RDWR | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                         0o600, dir_fd=self.fd)
            self.files[name] = fd
            remaining = size
            while remaining:
                raw = b"\0" * min(65536, remaining)
                n = os.write(fd, raw)
                require(n > 0, "REPORT_SLOT_SHORT_ALLOCATION")
                remaining -= n
            os.fsync(fd)
            require(os.fstat(fd).st_blocks * 512 >= size, "REPORT_SLOT_MUST_BE_ALLOCATED")
            self.reserved.add(name)
        os.fsync(self.fd)

    def write(self, name, raw, shrink=True):
        require(name in self.reserved and name not in self.closed and len(raw) <= SLOTS[name],
                "RESERVED_REPORT_BOUND")
        fd = self.files[name]
        s = os.fstat(fd)
        named = os.stat(name, dir_fd=self.fd, follow_symlinks=False)
        require(stable(named) == stable(s) and s.st_nlink == 1 and stat.S_ISREG(s.st_mode),
                "RESERVED_REPORT_FD_NAME")
        offset = 0
        while offset < len(raw):
            n = os.pwrite(fd, raw[offset:], offset)
            require(n > 0, "RESERVED_REPORT_SHORT_WRITE")
            offset += n
        if shrink:
            os.ftruncate(fd, len(raw))
            self.closed.add(name)
        os.fsync(fd)
        if shrink:
            actual = os.pread(fd, len(raw) + 1, 0)
            require(actual == raw, "RESERVED_REPORT_FULL_READBACK")
        os.fsync(self.fd)
        return {"path": str(RUN / name), "bytes": len(raw), "sha256": digest(raw)}

    def close(self):
        for fd in self.files.values():
            os.close(fd)
        if self.fd is not None:
            os.close(self.fd)

def save_process_ledger(slots):
    slots.write("PROCESS_LEDGER.json",canonical(PROCESS_LEDGER),shrink=False)

def run_owned(argv, label, input_body, stdout_cap, stderr_cap, seconds, slots, stdout_slot, stderr_slot):
    process = None
    identity_value = None
    selector = None
    out, err = bytearray(), bytearray()
    failure, cleanup_failure = None, None
    sent = 0
    code = None
    started = time.monotonic()
    guard()
    process = subprocess.Popen(argv, stdin=subprocess.PIPE if input_body is not None else subprocess.DEVNULL,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               close_fds=True, start_new_session=True)
    # Immediate protected lifetime after Popen; no fallible setup precedes it.
    try:
        identity_value = process_identity(process.pid)
        require(identity_value["pgid"] == identity_value["session"] == process.pid, "OWNED_SSH_SESSION")
        PROCESS_LEDGER.append({"label": label, "identity": identity_value, "argv": argv,
                               "inputBytes": len(input_body or b""),
                               "inputSHA256": digest(input_body) if input_body is not None else None,
                               "startedUTC": utc()})
        save_process_ledger(slots)
        selector = selectors.DefaultSelector()
        for channel, pipe in (("stdout", process.stdout), ("stderr", process.stderr)):
            os.set_blocking(pipe.fileno(), False)
            selector.register(pipe.fileno(), selectors.EVENT_READ, channel)
        if process.stdin is not None:
            os.set_blocking(process.stdin.fileno(), False)
            selector.register(process.stdin.fileno(), selectors.EVENT_WRITE, "stdin")
        until = min(DEADLINE, started + seconds)
        while selector.get_map():
            guard()
            require(time.monotonic() < until, "OWNED_SSH_OR_ALIAS_DEADLINE")
            for key, _ in selector.select(0.25):
                if key.data == "stdin":
                    try:
                        n = os.write(key.fd, input_body[sent:sent + 65536])
                    except BlockingIOError:
                        continue
                    require(n > 0, "SSH_SOURCE_STDIN_CLOSED")
                    sent += n
                    if sent == len(input_body):
                        selector.unregister(key.fd)
                        process.stdin.close()
                    continue
                try:
                    raw = os.read(key.fd, 16384)
                except BlockingIOError:
                    continue
                if not raw:
                    selector.unregister(key.fd)
                    continue
                buffer, cap = (out, stdout_cap) if key.data == "stdout" else (err, stderr_cap)
                remaining = cap - len(buffer)
                buffer.extend(raw[:remaining])
                # Persist bounded partial output into already allocated slots.
                target = stdout_slot if key.data == "stdout" else stderr_slot
                if target is not None:
                    slots.write(target, bytes(buffer), shrink=False)
                require(len(raw) <= remaining, "OWNED_SSH_OUTPUT_BOUND")
        code = process.wait(timeout=max(0.01, min(20, until - time.monotonic())))
        require(input_body is None or sent == len(input_body), "WHOLE_MAC_SOURCE_DELIVERED")
    except BaseException as error:
        failure = error_record(error, label)
    finally:
        try:
            stop_owned(process, identity_value)
        except BaseException as error:
            cleanup_failure = error_record(error, label + "-cleanup")
        finally:
            if selector is not None:
                selector.close()
            for stream in (process.stdin, process.stdout, process.stderr):
                if stream is not None and not stream.closed:
                    stream.close()
            if stdout_slot is not None:
                slots.write(stdout_slot, bytes(out))
            if stderr_slot is not None:
                slots.write(stderr_slot, bytes(err))
            terminal = {"label": label, "pid": process.pid, "identity": identity_value,
                        "returncode": process.returncode, "stdoutBytes": len(out),
                        "stdoutSHA256": digest(out), "stderrBytes": len(err),
                        "stderrSHA256": digest(err), "seconds": time.monotonic() - started,
                        "failure": failure, "cleanupFailure": cleanup_failure,
                        "ownedLeaderReaped": process.returncode is not None,
                        "descendantExtinctionClaimed": False, "automaticRetries": 0}
            PROCESS_LEDGER.append({"terminal": terminal})
            save_process_ledger(slots)
    require(cleanup_failure is None, "OWNED_SSH_CLEANUP_REFUSED")
    return terminal, bytes(out), bytes(err)

def pinned_alias(slots):
    argv = ["/usr/bin/ssh", "-G", "-o", "StrictHostKeyChecking=yes",
            "-o", "IdentitiesOnly=yes", "-o", "UpdateHostKeys=no",
            "-o", "ControlMaster=no", "-o", "ControlPath=none", "scaleway-mac"]
    terminal, raw, err = run_owned(argv, "existing-pinned-ssh-alias", None, 65536, 16384,
                                   15, slots, None, "ssh-alias.stderr")
    require(terminal["failure"] is None and terminal["returncode"] == 0, "SSH_ALIAS_COMMAND_FAILED")
    values = {}
    for line in raw.decode("utf-8", "strict").splitlines():
        key, _, value = line.partition(" ")
        if key in ("hostname", "user", "port", "stricthostkeychecking", "identitiesonly"):
            require(key not in values, "DUPLICATE_PINNED_SSH_OPTION")
            values[key] = value
    require(values.get("hostname") == "62.210.195.226" and values.get("user") == "m1"
            and values.get("port") == "22" and values.get("stricthostkeychecking") in ("true", "yes")
            and values.get("identitiesonly") == "yes", "EXISTING_PINNED_SSH_ALIAS_MISMATCH")
    return slots.write("SSH_ALIAS.json", canonical({"allowedFields": values,
                         "rawConfigurationSHA256": digest(raw), "rawConfigurationNotPersisted": True,
                         "stderrSHA256": digest(err), "terminal": terminal}))

def api_metadata(slots,endpoint,label,cap):
    allowed={"repos/"+REPOSITORY,
             "repos/%s/releases/%d"%(REPOSITORY,RELEASE_ID),
             "repos/%s/releases/%d/assets?per_page=100&page=1"%(REPOSITORY,RELEASE_ID)}
    require(endpoint in allowed,"ONLY_THREE_FIXED_PRIVATE_METADATA_GETS")
    argv=["sudo","-u","ubuntu","-H","gh","api","--hostname","github.com",endpoint]
    terminal,raw,err=run_owned(argv,label,None,cap,4096,60,slots,label+".stdout",label+".stderr")
    require(terminal["failure"] is None and terminal["cleanupFailure"] is None
            and terminal["returncode"]==0,"AUTHENTICATED_METADATA_GET_FAILED")
    return json.loads(raw)

def private_asset_state(slots,qualified):
    repo=api_metadata(slots,"repos/"+REPOSITORY,"repository",16384)
    require(type(repo["id"]) is int and repo["id"]==REPOSITORY_ID
            and repo["private"] is True and repo["full_name"]==REPOSITORY,
            "EXACT_EXISTING_PRIVATE_REPOSITORY")
    release=api_metadata(slots,"repos/%s/releases/%d"%(REPOSITORY,RELEASE_ID),"release",32768)
    require(type(release["id"]) is int and release["id"]==RELEASE_ID and release["draft"] is True
            and release["prerelease"] is False
            and release["tag_name"]=="native116-remaining-stream-20261127-wave3"
            and release["upload_url"]=="https://uploads.github.com/repos/%s/releases/%d/assets{?name,label}"%(REPOSITORY,RELEASE_ID),
            "EXACT_PRESERVED_PRIVATE_DRAFT")
    values=api_metadata(slots,"repos/%s/releases/%d/assets?per_page=100&page=1"%(REPOSITORY,RELEASE_ID),"assets",32768)
    require(type(values) is list and len(values)==4,"EXACT_COMPLETE_FOUR_ASSET_LIST")
    actual={x["name"]:x for x in values}
    require(len(actual)==4 and set(actual)==set(qualified),"FOUR_ORIGINAL_ASSET_NAMES")
    for name,old in qualified.items():
        new=actual[name]
        if old.get("historicalIncomplete") is True:
            require(new==old["completeCapturedMetadata"],"OLD_STARTER_PRESERVED_EXACTLY")
        else:
            require({k:new[k] for k in ("id","name","size","state","url","content_type")}==
                    {k:old[k] for k in ("id","name","size","state","url","content_type")},
                    "IMMUTABLE_UPLOADED_ASSET_METADATA")
            require(type(new["id"]) is int and new["state"]=="uploaded"
                    and new["url"]=="https://api.github.com/repos/%s/releases/assets/%d"%(REPOSITORY,new["id"]),
                    "EXACT_IMMUTABLE_GITHUB_ASSET_URL")
            require(new.get("digest") is None or new["digest"]=="sha256:"+old["sha256"],
                    "SERVER_DIGEST_IF_PRESENT")
    asset=actual[ASSET_NAME]
    require(asset["id"]==ASSET_ID and asset["size"]==ARCHIVE_BYTES,"ONLY_EXACT_OPAQUE_ARCHIVE_GET")
    return {"repositoryID":repo["id"],"private":True,"releaseID":release["id"],
            "draft":True,"assetID":asset["id"],"bytes":asset["size"],
            "allFourAssetsJoinedToQualifiedReadback":True}

def receiver_events(raw,request,require_final=False):
    require(len(raw)<=32768,"BOUNDED_RECEIVER_TRANSCRIPT")
    lines=raw.splitlines()
    complete=lines if raw.endswith(b"\n") else lines[:-1]
    events=[json.loads(x) for x in complete]
    require(len(events)<=2,"EXACT_FINITE_RECEIVER_EVENTS")
    ready=[x["value"] for x in events if x["event"]=="READY"]
    finals=[x["value"] for x in events if x["event"]=="FINAL_RESULT"]
    require(len(ready)<=1 and len(finals)<=1,"NO_DUPLICATE_RECEIVER_STATE")
    if ready:
        require(events[0]["event"]=="READY" and ready[0]["request"]==request
                and ready[0]["existingLeafOverwritten"] is False,"EXACT_RECEIVER_READY")
    if require_final:
        require(raw.endswith(b"\n") and len(events)==2 and len(ready)==len(finals)==1,
                "COMPLETE_READY_AND_FINAL_TRANSCRIPT")
        final=finals[0]
        require(final["status"]=="OPAQUE_STAGE_BYTES_RESTORED_WITH_SUPPORTED_METADATA"
                and final["request"]==request
                and final["storedFullHashBeforeMetadata"]=={"bytes":ARCHIVE_BYTES,"sha256":ARCHIVE_SHA}
                and final["incomingSHA256"]==ARCHIVE_SHA
                and final["originalLeafMetadata"]==EXPECTED["archive"]
                and final["temporaryNameRemoved"] is True and final["publishedWithoutReplacement"] is True
                and final["terminalSiblingUnchanged"] is True and final["closeErrors"]==[]
                and final["sourceNativeTreeTouched"] is False
                and final["inodeCtimeBirthtimeAllocationRestored"] is False
                and final["payloadReReadAfterFinalAtime"] is False,"ACTUAL_STORED_RESTORATION_COMPLETION")
        new=final["newLeafMetadata"]
        for key in ("mode","uid","gid","flags","xattrs","acl","atimeNS","mtimeNS","bytes"):
            require(new[key]==EXPECTED["archive"][key],"FINAL_SUPPORTED_METADATA_EXACT")
        require(new["nlink"]==1 and new["kind"]=="file","FINAL_SINGLE_LINK_REGULAR")
        return ready[0],final
    return ready[0] if ready else None,finals[0] if finals else None

def bootstrap_and_request(pointer_sha,admission_sha):
    source=read_source(FAMILY/"mac_restore_stage_leaf.py",MAC_BYTES)
    require(len(source)==MAC_BYTES and digest(source)==MAC_SHA256,"FRESH_RECEIVER_SOURCE_PIN")
    request={"schema":"otzaria.native116-stage-restore-request/1","attemptID":uuid.uuid4().hex,
             "pointerSHA256":pointer_sha,"authorizationSHA256":admission_sha,
             "sourceSealSHA256":SOURCE_SEAL_SHA,"assetID":ASSET_ID,"bytes":ARCHIVE_BYTES,"sha256":ARCHIVE_SHA}
    envelope=canonical({"sourceBase64":base64.b64encode(source).decode("ascii"),
                        "sourceSHA256":MAC_SHA256,"request":request})
    require(len(envelope)<=65536,"FINITE_IN_MEMORY_SOURCE_ENVELOPE")
    bootstrap="""if not __debug__: raise RuntimeError('OPTIMIZED_REFUSED')
import base64,hashlib,json,os,struct,sys
if not sys.flags.isolated or not sys.dont_write_bytecode: raise RuntimeError('ISOLATION_REQUIRED')
def exact(n):
 b=bytearray()
 while len(b)<n:
  x=os.read(0,n-len(b))
  if not x: raise RuntimeError('TRUNCATED_SOURCE_ENVELOPE')
  b.extend(x)
 return bytes(b)
n=struct.unpack('>I',exact(4))[0]
if not 0<n<=65536: raise RuntimeError('SOURCE_ENVELOPE_BOUND')
v=json.loads(exact(n))
if set(v)!={'sourceBase64','sourceSHA256','request'}: raise RuntimeError('SOURCE_FIELDS')
s=base64.b64decode(v['sourceBase64'],validate=True)
if hashlib.sha256(s).hexdigest()!=%r or v['sourceSHA256']!=%r: raise RuntimeError('SOURCE_HASH')
ns={'__name__':'__reviewed_stage_restorer__'}
exec(compile(s,'<reviewed-native116-stage-restorer>','exec'),ns)
sys.exit(ns['main'](v['request']))
"""%(MAC_SHA256,MAC_SHA256)
    require(len(bootstrap.encode())<=4096,"FIXED_SMALL_SSH_BOOTSTRAP")
    argv=["/usr/bin/ssh","-o","BatchMode=yes","-o","ConnectTimeout=8",
          "-o","StrictHostKeyChecking=yes","-o","IdentitiesOnly=yes","-o","UpdateHostKeys=no",
          "-o","ControlMaster=no","-o","ControlPath=none","-T","scaleway-mac",
          "/usr/bin/python3","-I","-B","-c",shlex.quote(bootstrap)]
    return argv,struct.pack(">I",len(envelope))+envelope,request

def stream_restore(slots,pointer_sha):
    argv,initial,request=bootstrap_and_request(pointer_sha,ADMISSION_SHA)
    ssh=None;getter=None;ssh_identity=None;getter_identity=None;selector=None
    receiver_out=bytearray();receiver_err=bytearray();getter_err=bytearray()
    count=0;sent=0;hasher=hashlib.sha256();pending=bytearray();tail=bytearray()
    complete_get=False;ssh_input_closed=False;failure=None;cleanup=[];result=None
    started=time.monotonic();until=min(DEADLINE,started+STREAM_SECONDS)
    channels=set()
    def add(pipe,label,mode=selectors.EVENT_READ):
        os.set_blocking(pipe.fileno(),False)
        selector.register(pipe.fileno(),mode,label);channels.add(label)
    def remove(key,label):
        selector.unregister(key);channels.discard(label)
    def checkpoint(slot,buffer):
        slots.write(slot,bytes(buffer),shrink=False)
    def bounded_append(buffer,raw,cap,slot):
        room=cap-len(buffer);buffer.extend(raw[:room]);checkpoint(slot,buffer)
        require(len(raw)<=room,"STREAM_DIAGNOSTIC_BOUND")
    guard()
    ssh=subprocess.Popen(argv,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,
                         close_fds=True,start_new_session=True)
    # The receiver leader is protected immediately, including source/bootstrap setup.
    try:
        ssh_identity=process_identity(ssh.pid)
        require(ssh_identity["pgid"]==ssh_identity["session"]==ssh.pid,"OWNED_RECEIVER_SESSION")
        PROCESS_LEDGER.append({"label":"opaque-stage-receiver","identity":ssh_identity,"argv":argv,
            "inputEnvelopeBytes":len(initial),"inputEnvelopeSHA256":digest(initial),"startedUTC":utc()})
        save_process_ledger(slots)
        selector=selectors.DefaultSelector()
        add(ssh.stdout,"receiver.stdout");add(ssh.stderr,"receiver.stderr")
        add(ssh.stdin,"receiver.stdin",selectors.EVENT_WRITE)
        position=0;ready=None;ready_until=min(until,time.monotonic()+60)
        while ready is None:
            guard();require(time.monotonic()<ready_until,"RECEIVER_READY_DEADLINE")
            require(channels,"RECEIVER_CLOSED_BEFORE_READY")
            for key,_ in selector.select(0.25):
                if key.data=="receiver.stdin":
                    try:n=os.write(key.fd,initial[position:position+65536])
                    except BlockingIOError:continue
                    require(n>0,"SOURCE_ENVELOPE_SHORT_WRITE");position+=n
                    if position==len(initial):remove(key.fd,key.data)
                else:
                    try:raw=os.read(key.fd,16384)
                    except BlockingIOError:continue
                    if not raw:remove(key.fd,key.data);continue
                    if key.data=="receiver.stdout":
                        bounded_append(receiver_out,raw,32768,"receiver.stdout")
                        ready,final=receiver_events(bytes(receiver_out),request)
                        require(final is None,"RECEIVER_REFUSED_BEFORE_GET")
                    else:bounded_append(receiver_err,raw,65536,"receiver.stderr")
            require("receiver.stdout" in channels or ready is not None,"RECEIVER_EOF_BEFORE_GET")
        require(position==len(initial),"FULL_SOURCE_SENT_BEFORE_GET")
        # Only after the actual Mac admits the absent leaf/exclusive temp and capacity.
        get_argv=["sudo","-u","ubuntu","-H","gh","api","--hostname","github.com",
                  "-H","Accept: application/octet-stream",
                  "repos/%s/releases/assets/%d"%(REPOSITORY,ASSET_ID)]
        guard()
        getter=subprocess.Popen(get_argv,stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.PIPE,
                                close_fds=True,start_new_session=True)
        # No fallible operation may precede the getter's cleanup scope.
        try:
            getter_identity=process_identity(getter.pid)
            require(getter_identity["pgid"]==getter_identity["session"]==getter.pid,"OWNED_AUTHENTICATED_GET_SESSION")
            PROCESS_LEDGER.append({"label":"exact-opaque-stage-authenticated-GET","identity":getter_identity,
                                   "argv":get_argv,"startedUTC":utc(),"automaticRetries":0})
            save_process_ledger(slots)
            add(getter.stdout,"getter.stdout");add(getter.stderr,"getter.stderr")
            getter_eof=False;getter_error_eof=False
            while channels or not ssh_input_closed:
                guard();require(time.monotonic()<until,"ONE_EXACT_GET_RECEIVER_STREAM_DEADLINE")
                # A finite memory queue plus pipe backpressure; no local payload file.
                if pending and "receiver.stdin" not in channels:
                    add(ssh.stdin,"receiver.stdin",selectors.EVENT_WRITE)
                if not pending and "receiver.stdin" in channels:
                    remove(ssh.stdin.fileno(),"receiver.stdin")
                if len(pending)<=65536 and not complete_get and "getter.stdout" not in channels and not getter.stdout.closed:
                    # Paused stdout is distinguished from EOF by a separate flag below.
                    if not getter_eof:add(getter.stdout,"getter.stdout")
                for key,_ in selector.select(0.25):
                    label=key.data
                    if label=="receiver.stdin":
                        try:n=os.write(key.fd,pending[:65536])
                        except BlockingIOError:continue
                        require(n>0,"RECEIVER_PAYLOAD_STDIN_CLOSED")
                        del pending[:n];sent+=n
                        require(sent<=ARCHIVE_BYTES,"SENT_PAYLOAD_BOUND")
                        if not pending:remove(key.fd,label)
                        continue
                    try:raw=os.read(key.fd,65536 if label=="getter.stdout" else 16384)
                    except BlockingIOError:continue
                    if not raw:
                        remove(key.fd,label)
                        if label=="getter.stdout":getter_eof=True
                        if label=="getter.stderr":getter_error_eof=True
                        continue
                    if label=="getter.stdout":
                        count+=len(raw);require(count<=ARCHIVE_BYTES,"GET_PAYLOAD_SIZE_BOUND")
                        hasher.update(raw);tail.extend(raw)
                        release=max(0,len(tail)-65536)
                        if release:
                            pending.extend(tail[:release]);del tail[:release]
                        require(len(pending)<=131072 and len(tail)<=65536,"FINITE_STREAM_BUFFER")
                        if len(pending)>65536:remove(key.fd,label)
                    elif label=="getter.stderr":bounded_append(getter_err,raw,65536,"getter.stderr")
                    elif label=="receiver.stdout":
                        bounded_append(receiver_out,raw,32768,"receiver.stdout")
                    else:bounded_append(receiver_err,raw,65536,"receiver.stderr")
                if getter_eof and getter_error_eof and not complete_get:
                    require(getter.wait(timeout=max(0.01,min(20,until-time.monotonic())))==0,
                            "AUTHENTICATED_GET_NOT_SUCCESSFUL")
                    require(count==ARCHIVE_BYTES and hasher.hexdigest()==ARCHIVE_SHA,
                            "FULL_AUTHENTICATED_GET_SIZE_SHA")
                    complete_get=True
                    require(len(tail)==65536,"EXACT_WITHHELD_FINAL_TAIL")
                    pending.extend(tail);tail.clear()
                    require(len(pending)<=196608,"FINITE_VERIFIED_TAIL_QUEUE")
                if complete_get and not pending and not ssh_input_closed:
                    if "receiver.stdin" in channels:remove(ssh.stdin.fileno(),"receiver.stdin")
                    require(sent==ARCHIVE_BYTES,"WHOLE_VERIFIED_PAYLOAD_SENT")
                    ssh.stdin.close();ssh_input_closed=True
                if "receiver.stdout" not in channels and not ssh_input_closed:
                    raise RuntimeError("RECEIVER_EOF_BEFORE_PAYLOAD_COMPLETION")
            require(complete_get and count==sent==ARCHIVE_BYTES and not pending and not tail,
                    "COMPLETE_GET_AND_PIPE_DELIVERY")
            require(ssh.wait(timeout=max(0.01,min(20,until-time.monotonic())))==0 and not receiver_err,
                    "RECEIVER_EXIT_AND_STDERR_REQUIRED")
            _,final=receiver_events(bytes(receiver_out),request,require_final=True)
            result={"request":request,"incomingOracleBytes":count,"oracleSHA256":hasher.hexdigest(),
                    "fullGetExit":getter.returncode,"receiverExit":ssh.returncode,
                    "receiver":final,"final64KiBWithheldUntilGetterSuccess":True,
                    "oneGET":True,"automaticRetries":0,"payloadStoredOnOracle":False}
        finally:
            try:stop_owned(getter,getter_identity)
            except BaseException as error:cleanup.append(error_record(error,"GETTER_CLEANUP"))
            finally:
                for stream in (getter.stdout,getter.stderr):
                    if stream is not None and not stream.closed:stream.close()
    except BaseException as error:
        failure=error_record(error,"STREAM_RESTORE")
    finally:
        try:stop_owned(ssh,ssh_identity)
        except BaseException as error:cleanup.append(error_record(error,"RECEIVER_CLEANUP"))
        finally:
            if selector is not None:selector.close()
            for stream in (ssh.stdin,ssh.stdout,ssh.stderr):
                if stream is not None and not stream.closed:stream.close()
            for slot,buffer in (("receiver.stdout",receiver_out),("receiver.stderr",receiver_err),("getter.stderr",getter_err)):
                slots.write(slot,bytes(buffer))
            PROCESS_LEDGER.append({"streamTerminal":{"receiverIdentity":ssh_identity,"receiverExit":ssh.returncode,
                "getterIdentity":getter_identity,"getterExit":getter.returncode if getter is not None else None,
                "receiverOwnedLeaderReaped":ssh.returncode is not None,
                "getterOwnedLeaderReaped":getter is None or getter.returncode is not None,
                "descendantExtinctionClaimed":False,"countedGetBytes":count,"writtenPipeBytes":sent,
                "countedGetSHA256":hasher.hexdigest(),"completeAuthenticatedGet":complete_get,
                "failure":failure,"cleanupErrors":cleanup,"seconds":time.monotonic()-started}})
            save_process_ledger(slots)
    require(failure is None and not cleanup and result is not None,"OPAQUE_STAGE_RESTORE_INCOMPLETE")
    return result

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--source-seal-sha256",required=True)
    parser.add_argument("--admission-sha256",required=True)
    parser.add_argument("phase",choices=("restore-once",))
    args=parser.parse_args()
    verify_seal(args.source_seal_sha256)
    admitted=verify_admission(args.admission_sha256)
    require(not RUN.exists() and not RUN.is_symlink(),"ONE_NEW_RESTORE_ATTEMPT_ONLY")
    require(free()>=ROOT_FLOOR+FAMILY_CAP,"ORIGINAL_ROOT_PLUS_COMBINED_METADATA_ADMISSION")
    guard()
    slots=ReservedFiles()
    outcome={"schema":"otzaria.native116-opaque-stage-restoration/1","status":"INCOMPLETE",
             "sourceSealSHA256":SOURCE_SEAL_SHA,"rootAdmissionSHA256":ADMISSION_SHA,
             "pointerSHA256":admitted["pointerSHA256"],"fullReadbackResultSHA256":admitted["qualificationSHA256"],
             "fullReadbackJobID":admitted["qualificationJob"],"durableGitCommit":admitted["durableGitCommit"],
             "assetID":ASSET_ID,"bytes":ARCHIVE_BYTES,"sha256":ARCHIVE_SHA,
             "originalTreeRestored":False,"newUpload":False,"automaticRetries":0}
    failure=None;report_errors=[]
    try:
        slots.create()
        outcome["sshAlias"]=pinned_alias(slots)
        outcome["privateStateBefore"]=private_asset_state(slots,admitted["qualifiedAssets"])
        outcome["restoration"]=stream_restore(slots,admitted["pointerSHA256"])
        same_pins();verify_seal(args.source_seal_sha256)
        verify_admission(args.admission_sha256);guard()
        outcome["status"]="OPAQUE_STAGE_BYTES_RESTORED_WITH_EXPLICIT_SUPPORTED_METADATA"
    except BaseException as error:
        failure=error_record(error,"RESTORE_DISPATCH")
        outcome["status"]="FAILED_PRESERVE_ALL_PARTIAL_STATES"
    finally:
        outcome.update(failure=failure,seconds=time.monotonic()-STARTED,
            fullNativeTreeNotReadOrModified=True,externalLinksAndGitWindowsDependenciesUntouched=True,
            originalInodeCtimeBirthtimeAllocationNeverClaimedRestored=True,
            rootFloor=ROOT_FLOOR,macLiveFloor=MAC_FLOOR,unchangedSDKAdmission=15032385536,
            combinedMetadataCap=FAMILY_CAP,newFamilyCap=NEW_FAMILY_CAP,
            actualNewStreamDeadline=STREAM_SECONDS,overallDeadline=OVERALL_SECONDS,
            noOtherSourceOrSiblingRemoved=True)
        try:
            if "PROCESS_LEDGER.json" in slots.reserved and "PROCESS_LEDGER.json" not in slots.closed:
                slots.write("PROCESS_LEDGER.json",canonical(PROCESS_LEDGER))
            if "TERMINAL.json" in slots.reserved:
                slots.write("TERMINAL.json",canonical({"utc":utc(),"status":outcome["status"],
                    "failure":failure,"rootFreeBytes":free(),"combinedFamilyAllocatedBytes":allocation(),
                    "ownedLeaderEvidence":PROCESS_LEDGER[-1] if PROCESS_LEDGER else None,
                    "automaticRetry":False}))
            if "FINAL_RESULT.json" in slots.reserved:
                outcome["report"]=slots.write("FINAL_RESULT.json",canonical(outcome))
            else:outcome["failureBeforeReservedFinalResult"]=True
        except BaseException as error:
            report_errors.append(error_record(error,"FINITE_FINAL_REPORT"))
            outcome["status"]="FAILED_PRESERVE_ALL_PARTIAL_STATES"
        finally:
            try:slots.close()
            except BaseException as error:
                report_errors.append(error_record(error,"REPORT_CLOSE"))
                outcome["status"]="FAILED_PRESERVE_ALL_PARTIAL_STATES"
        if report_errors:outcome["reportErrors"]=report_errors
        # Safe receipt/identity summary only. No API bodies, credentials or payload bytes.
        raw=canonical(outcome)
        require(len(raw)<=65536,"BOUNDED_FINAL_DISPATCH_STDOUT")
        sys.stdout.buffer.write(raw);sys.stdout.buffer.flush()
    return 0 if outcome["status"]=="OPAQUE_STAGE_BYTES_RESTORED_WITH_EXPLICIT_SUPPORTED_METADATA" else 2

if __name__=="__main__":
    sys.exit(main())
