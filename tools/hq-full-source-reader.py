#!/usr/bin/env python3
"""Real original Swift Reader/SQLite/ZSTD over SHA-pinned full v32; no UIKit claim."""
from pathlib import Path
import argparse, ctypes, datetime, hashlib, json, os, platform, re, shutil, sqlite3, subprocess, sys, time, uuid
ROOT=Path(__file__).resolve().parents[1]
def sha(path):
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(8*1024*1024),b""):h.update(chunk)
    return h.hexdigest()
def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--database",required=True,type=Path)
    ap.add_argument("--artifacts-dir",required=True,type=Path)
    ap.add_argument("--optimization",choices=["none","speed"],default="none",help="Record the actual Swift compile mode; never compare unlike modes as a source speedup")
    ap.add_argument("--log-stages",action="store_true",help="Retain the original Reader stage timings; no production instrumentation change")
    ap.add_argument("--stress-only",action="store_true",help="Run bounded actual-source concurrency/cancellation/cache checks instead of repeating the 36 sequential content cases")
    args=ap.parse_args()
    artifacts=args.artifacts_dir.resolve();artifacts.mkdir(parents=True,exist_ok=True)
    database=args.database.resolve(strict=True)
    seed=ROOT/"Scripts/DataProfiles/miniTest10.seed.json"
    pin=json.loads(seed.read_text(encoding="utf-8"))["source"]
    assert pin["releaseTag"]=="v32-20261010190601"
    assert database.stat().st_size==pin["databaseBytes"]
    before=sha(database);assert before==pin["databaseSHA256"]
    owned=ROOT/"build"/("fr32-"+uuid.uuid4().hex[:12]);owned.mkdir()
    uri=database.as_uri()+"?mode=ro&immutable=1"
    connection=sqlite3.connect(uri,uri=True)
    top=[r[0] for r in connection.execute("SELECT bookId,COUNT(*) AS n FROM line GROUP BY bookId ORDER BY n DESC,bookId LIMIT 3")]
    books=[]
    for bid in dict.fromkeys([103,28,3152,*top]):
        title=connection.execute("SELECT title FROM book WHERE id=?",(bid,)).fetchone()[0]
        indices=[r[0] for r in connection.execute("SELECT lineIndex FROM line WHERE bookId=? ORDER BY lineIndex",(bid,))]
        assert indices and len(indices)==len(set(indices))
        positions=sorted(set([0,len(indices)//2,len(indices)-1]))
        books.append(dict(id=bid,title=title,lineCount=len(indices),first=indices[0],middle=indices[len(indices)//2],
            last=indices[-1],navigation=[dict(index=indices[i],previous=indices[i-1] if i else None,
                next=indices[i+1] if i+1<len(indices) else None) for i in positions]))
    input_data=dict(uri=uri,books=books)
    if args.stress_only:
        cache_books=[dict(id=r[0],first=r[1],middle=r[1]) for r in connection.execute(
            "SELECT bookId,MIN(lineIndex),COUNT(*) FROM line GROUP BY bookId HAVING COUNT(*) BETWEEN 8 AND 128 ORDER BY bookId LIMIT 60")]
        assert len(cache_books)==60,"The actual full-v32 cache stress catalog is required"
        input_data["cacheBooks"]=cache_books
    (owned/"input.json").write_bytes(json.dumps(input_data,ensure_ascii=False).encode("utf-8"))
    sources=[
        "Source/Core/Database/SQLiteDatabase.swift","Source/Core/Database/ZstdShim.swift",
        "Source/Otzaria/Core/OtzariaSQLiteError.swift","Source/Otzaria/Core/OtzariaSQLiteStatement.swift",
        "Source/Otzaria/Core/String+OtzariaText.swift","Source/Otzaria/Data/OtzariaSchema.swift",
        "Source/Otzaria/Data/OtzariaBookSchemaCompatibility.swift","Source/Otzaria/Reading/OtzariaReadingUnit.swift",
        "Source/Otzaria/Reading/OtzariaReadingUnitDescriptor.swift","Source/Otzaria/Reading/OtzariaLineAnchor.swift",
        "Source/Otzaria/Reading/OtzariaReadingUnitService.swift",
        "Tests/HQ/sqlite/UnusedZstdBoundary.swift",
        "Tests/HQ/reader/FullSourceReaderStress.swift" if args.stress_only else "Tests/HQ/reader/FullSourceReaderAcceptance.swift"
    ]
    generated_sources=[]
    extraction=None
    if args.stress_only:
        # Compile the complete ORIGINAL cache class without the unrelated app
        # bridge extension. Its bytes are copied verbatim, never reimplemented.
        side_path=ROOT/"Source/Otzaria/Reading/OtzariaMaktabahBridge+LineAnchors.swift"
        side=side_path.read_text(encoding="utf-8")
        marker="extension OtzariaMaktabahBridge {"
        assert side.count(marker)==1 and side.startswith("import Foundation\n")
        prefix=side.split(marker)[0]
        generated=owned/"OriginalReadingUnitSideCache.swift"
        generated.write_bytes(prefix.encode("utf-8"))
        generated_sources.append(generated)
        extraction=dict(source=str(side_path.relative_to(ROOT)),source_sha256=sha(side_path),
            extracted_sha256=sha(generated),boundary="Complete unchanged class before original app bridge extension; no bridge/UI compiled")
    command=[shutil.which("swiftc"),"-parse-as-library","-swift-version","6","-Xfrontend","-strict-concurrency=complete"]
    command.append("-O" if args.optimization=="speed" else "-Onone")
    if os.name!="nt": raise RuntimeError("This receipt currently targets the existing Windows host; Apple/UIKit evidence remains separate")
    dll=Path(os.environ.get("ProgramFiles",r"C:\Program Files"))/"Git/mingw64/bin/libzstd.dll"
    assert dll.is_file(),"An existing native ZSTD library is required; no install is performed"
    lib=ctypes.CDLL(str(dll));lib.ZSTD_versionString.restype=ctypes.c_char_p
    version=lib.ZSTD_versionString().decode("ascii")
    shutil.copyfile(dll,owned/"libzstd.dll")
    symbols=re.findall(r'@_silgen_name\("([^"]+)"\)',(ROOT/"Source/Core/Database/ZstdShim.swift").read_text(encoding="utf-8"))
    (owned/"zstd.def").write_bytes(("LIBRARY libzstd.dll\nEXPORTS\n"+"\n".join(symbols)+"\n").encode("ascii"))
    imp=owned/"zstd.lib"
    subprocess.run([shutil.which("llvm-dlltool"),"-m","i386:x86-64","-d",str(owned/"zstd.def"),"-l",str(imp)],check=True,capture_output=True)
    sdkroot=Path(os.environ.get("ProgramFiles(x86)",r"C:\Program Files (x86)"))/"Windows Kits/10"
    sdk=next(p for p in sorted((sdkroot/"Include").glob("*"),reverse=True) if (p/"um/winsqlite/winsqlite3.h").is_file())
    module=owned/"SQLite3";module.mkdir()
    (module/"module.modulemap").write_bytes(('module SQLite3 [system] { header "'+(sdk/"um/winsqlite/winsqlite3.h").as_posix()+'" link "winsqlite3" export * }\n').encode("utf-8"))
    command+=["-I",str(owned),"-L",str(sdkroot/"Lib"/sdk.name/"um/x64")]
    executable=owned/"full-reader.exe"
    command += [str(ROOT/p) for p in sources]+[str(p) for p in generated_sources]+[str(imp),"-o",str(executable)]
    report=dict(observed_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),source_sha=subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
        source_files={p:sha(ROOT/p) for p in sources},host=platform.platform(),swift=subprocess.check_output([command[0],"--version"],text=True).strip(),
        source_pin=pin,source_pin_file_sha256=sha(seed),database_sha256_before=before,books=books,
        zstd=dict(path=str(dll),sha256=sha(dll),version=version),owned_fixture=str(owned),
        boundaries=[("original Reader log strings printed; signpost boundary is a no-op" if args.log_stages else "logging/signpost no-ops only"),"unused legacy SQLite compressed-column API fails if called; original dictionary decoder is executed"],
        native_ui_executed=0,physical_device_executed=0,command=command,
        driver_sha256=sha(Path(__file__)),optimization=args.optimization,original_stage_logging=args.log_stages,
        timing_boundary="Service-cache cold/warm on Windows; OS/disk cache not flushed; no UI, p95 or device claim")
    if args.stress_only:
        report.update(scenario="stress-only",cache_class_extraction=extraction,cache_books=cache_books,
            timing_boundary="Instrumented Windows source stress; service/SQL cancellation latency and harness working set only; no MainActor/UIKit/p95/device acceptance")
    build=subprocess.run(command,capture_output=True,text=True,encoding="utf-8",timeout=150)
    (artifacts/"compile.log").write_bytes((build.stdout+build.stderr).encode("utf-8"));report["compile_exit"]=build.returncode
    if build.returncode:
        print(build.stderr[-12000:]);report["status"]="COMPILE_FAILED"
        (artifacts/"RESULT.json").write_bytes(json.dumps(report,ensure_ascii=False,indent=2).encode("utf-8"))
        return build.returncode
    output=owned/"output";output.mkdir()
    run_env={**os.environ,"OTZARIA_READER_STAGE_LOG":"1" if args.log_stages else "0"}
    if args.stress_only:
        # Observe this owned child only. The peak includes oracle-output and
        # harness allocations; it is not an application/device memory budget.
        from ctypes import wintypes
        class Counters(ctypes.Structure):
            _fields_=[("cb",wintypes.DWORD),("PageFaultCount",wintypes.DWORD)]+[(name,ctypes.c_size_t) for name in
                ["PeakWorkingSetSize","WorkingSetSize","QuotaPeakPagedPoolUsage","QuotaPagedPoolUsage",
                 "QuotaPeakNonPagedPoolUsage","QuotaNonPagedPoolUsage","PagefileUsage","PeakPagefileUsage"]]
        kernel=ctypes.WinDLL("kernel32",use_last_error=True)
        kernel.OpenProcess.argtypes=[wintypes.DWORD,wintypes.BOOL,wintypes.DWORD];kernel.OpenProcess.restype=wintypes.HANDLE
        kernel.CloseHandle.argtypes=[wintypes.HANDLE]
        psapi=ctypes.WinDLL("psapi",use_last_error=True)
        psapi.GetProcessMemoryInfo.argtypes=[wintypes.HANDLE,ctypes.POINTER(Counters),wintypes.DWORD]
        peak=0;samples=0;started=time.monotonic()
        with (artifacts/"tests.log").open("w",encoding="utf-8") as log:
            process=subprocess.Popen([str(executable),str(owned/"input.json"),str(output)],stdout=log,stderr=subprocess.STDOUT,env=run_env)
            handle=kernel.OpenProcess(0x0400|0x0010,False,process.pid)
            try:
                while process.poll() is None:
                    counters=Counters();counters.cb=ctypes.sizeof(counters)
                    if handle and psapi.GetProcessMemoryInfo(handle,ctypes.byref(counters),ctypes.sizeof(counters)):
                        peak=max(peak,counters.PeakWorkingSetSize);samples+=1
                    if time.monotonic()-started>420:
                        process.kill();process.wait();raise TimeoutError("owned source stress process exceeded 420s")
                    time.sleep(.025)
                run=subprocess.CompletedProcess(process.args,process.returncode)
            finally:
                if handle:kernel.CloseHandle(handle)
        report["harness_memory_observation"]=dict(peak_working_set_bytes=peak,samples=samples,
            elapsed_seconds=time.monotonic()-started,includes_test_and_output_allocations=True,application_memory_claim=False)
        print((artifacts/"tests.log").read_text(encoding="utf-8")[-8000:])
    else:
        run=subprocess.run([str(executable),str(owned/"input.json"),str(output)],capture_output=True,text=True,encoding="utf-8",timeout=420,env=run_env)
        (artifacts/"tests.log").write_bytes((run.stdout+run.stderr).encode("utf-8"));print(run.stdout);print(run.stderr[-6000:])
    report["execute_exit"]=run.returncode
    if (output/"RESULT.json").exists():report["swift_reader"]=json.loads((output/"RESULT.json").read_text(encoding="utf-8"))
    verified=[]
    if run.returncode==0:
        import zstandard
        dictionaries=[zstandard.ZstdCompressionDict(r[0]) for r in connection.execute("SELECT dict FROM zstd_dict")]
        decoders={d.dict_id():zstandard.ZstdDecompressor(dict_data=d) for d in dictionaries}
        for record in sorted(output.glob("*.json")):
            if record.name=="RESULT.json":continue
            result=json.loads(record.read_text(encoding="utf-8"));indices=result["source_indices"]
            rows=[]
            for offset in range(0,len(indices),900):
                chunk=indices[offset:offset+900]
                query="SELECT l.id,l.lineIndex,l.heRef,lc.content FROM line l LEFT JOIN line_content lc ON lc.id=l.id WHERE l.bookId=? AND l.lineIndex IN ("+",".join("?" for _ in chunk)+") ORDER BY l.lineIndex"
                rows.extend(connection.execute(query,[result["book_id"],*chunk]).fetchall())
            assert [r[1] for r in rows]==indices
            texts=[]
            for row,anchor in zip(rows,result["anchors"],strict=True):
                assert (row[0],row[1],row[2])==(anchor["id"],anchor["index"],anchor["he_ref"])
                content=row[3];assert content is not None
                if isinstance(content,bytes):
                    frame=zstandard.get_frame_parameters(content)
                    assert frame.content_size<=16*1024*1024
                    content=decoders[frame.dict_id].decompress(content).decode("utf-8")
                assert isinstance(content,str);texts.append(content)
            expected="\n".join(texts).encode("utf-8")
            actual=record.with_suffix(".html").read_bytes()
            assert expected==actual,record.name
            verified.append(dict(case=record.stem,verified_rows=len(rows),decoded_source_bytes=len(actual),sha256=hashlib.sha256(actual).hexdigest()))
    connection.close()
    after=sha(database);assert after==before
    report["database_sha256_after"]=after;report["independent_python_sqlite_zstd_oracles"]=verified
    report["status"]=("ACTUAL_FULL_V32_STRESS_PASS_NOT_UI" if args.stress_only else "ACTUAL_FULL_V32_SWIFT_READER_PASS_NOT_UI") if run.returncode==0 else "FAILED"
    (artifacts/"RESULT.json").write_bytes((json.dumps(report,ensure_ascii=False,indent=2)+"\n").encode("utf-8"))
    print(json.dumps({"status":report["status"],"reader_cases":len(verified),"verified_source_rows":sum(v["verified_rows"] for v in verified),"owned_fixture":str(owned)},ensure_ascii=False))
    return run.returncode
if __name__=="__main__":raise SystemExit(main())
