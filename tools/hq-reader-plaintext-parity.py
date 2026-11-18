#!/usr/bin/env python3
"""Compare unchanged baseline normalization with current source on real v32 rows/TOC."""
from pathlib import Path
import argparse,datetime,hashlib,json,sqlite3,subprocess,uuid
ROOT=Path(__file__).resolve().parents[1]
def sha(path):
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(8*1024*1024),b""):h.update(chunk)
    return h.hexdigest()
def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--database",type=Path,required=True)
    ap.add_argument("--reader-baseline-report",type=Path,required=True)
    ap.add_argument("--baseline-source",required=True)
    ap.add_argument("--artifacts-dir",type=Path,required=True)
    args=ap.parse_args();artifacts=args.artifacts_dir.resolve();artifacts.mkdir(parents=True,exist_ok=True)
    base=json.loads(args.reader_baseline_report.read_text(encoding="utf-8"))
    assert base["status"]=="ACTUAL_FULL_V32_SWIFT_READER_PASS_NOT_UI"
    database=args.database.resolve(strict=True);before=sha(database)
    assert before==base["database_sha256_after"]==base["source_pin"]["databaseSHA256"]
    owned=ROOT/"build"/("ptp-"+uuid.uuid4().hex[:12]);owned.mkdir()
    connection=sqlite3.connect(database.as_uri()+"?mode=ro&immutable=1",uri=True)
    import zstandard
    dictionaries=[zstandard.ZstdCompressionDict(r[0]) for r in connection.execute("SELECT dict FROM zstd_dict")]
    decoders={d.dict_id():zstandard.ZstdDecompressor(dict_data=d) for d in dictionaries}
    indices={}
    for p in (Path(base["owned_fixture"])/"output").glob("*.json"):
        if p.name=="RESULT.json":continue
        row=json.loads(p.read_text(encoding="utf-8"))
        indices.setdefault(row["book_id"],set()).update(row["source_indices"])
    sources=[]
    for book_id,selected in sorted(indices.items()):
        for id,text in connection.execute("SELECT DISTINCT tt.id,tt.text FROM tocEntry te JOIN tocText tt ON tt.id=te.textId WHERE te.bookId=? ORDER BY tt.id",(book_id,)):
            sources.append(dict(id=f"toc:{book_id}:{id}",text=text))
        selected=sorted(selected)
        for off in range(0,len(selected),900):
            chunk=selected[off:off+900]
            query="SELECT l.id,lc.content FROM line l JOIN line_content lc ON lc.id=l.id WHERE l.bookId=? AND l.lineIndex IN ("+",".join("?" for _ in chunk)+") ORDER BY l.lineIndex"
            for id,content in connection.execute(query,[book_id,*chunk]):
                if isinstance(content,bytes):
                    frame=zstandard.get_frame_parameters(content)
                    assert frame.content_size<=16*1024*1024
                    content=decoders[frame.dict_id].decompress(content).decode("utf-8")
                assert isinstance(content,str)
                sources.append(dict(id=f"line:{book_id}:{id}",text=content))
    connection.close()
    input=owned/"input.json";input.write_bytes(json.dumps(sources,ensure_ascii=False).encode("utf-8"))
    source="Source/Otzaria/Core/String+OtzariaText.swift"
    raw=subprocess.check_output(["git","show",args.baseline_source+":"+source],cwd=ROOT)
    original=raw.decode("utf-8")
    a=original.index("    var otsariaPlainText: String {");b=original.index("    var otsariaLooksLikeHTMLHeading",a)
    method=original[a:b];baseline=owned/"Baseline.swift"
    baseline.write_bytes(("import Foundation\nextension String {\n"+method.replace("var otsariaPlainText:","var baselineOtzariaPlainText:",1)+"}\n").encode("utf-8"))
    fixture=ROOT/"Tests/HQ/reader/PlainTextParity.swift";executable=owned/"parity.exe"
    command=["swiftc","-parse-as-library","-swift-version","6","-Xfrontend","-strict-concurrency=complete",str(ROOT/source),str(baseline),str(fixture),"-o",str(executable)]
    compile=subprocess.run(command,capture_output=True,text=True,encoding="utf-8",timeout=90)
    (artifacts/"compile.log").write_bytes((compile.stdout+compile.stderr).encode("utf-8"))
    report=dict(observed_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),baseline_ref=args.baseline_source,
        original_file_sha256=hashlib.sha256(raw).hexdigest(),original_method_sha256=hashlib.sha256(method.encode("utf-8")).hexdigest(),
        optimized_file_sha256=sha(ROOT/source),fixture_sha256=sha(fixture),input_sha256=sha(input),
        input_bytes=input.stat().st_size,actual_source_strings=len(sources),owned_fixture=str(owned),
        compile_exit=compile.returncode,database_sha256_before=before,native_ui_executed=0,physical_device_executed=0)
    result=compile.returncode
    if result:
        print(compile.stderr)
    else:
        try:
            run=subprocess.run([str(executable),str(input),str(owned)],capture_output=True,text=True,encoding="utf-8",timeout=300)
        except subprocess.TimeoutExpired:
            report["status"]="INCOMPLETE_TIMEOUT_NO_PASS";report["execute_timeout_seconds"]=300
            (artifacts/"RESULT.json").write_bytes((json.dumps(report,ensure_ascii=False,indent=2)+"\n").encode("utf-8"))
            raise
        (artifacts/"tests.log").write_bytes((run.stdout+run.stderr).encode("utf-8"));print(run.stdout);print(run.stderr[-4000:])
        result=run.returncode;report["execute_exit"]=result
        if (owned/"RESULT.json").exists():report["parity"]=json.loads((owned/"RESULT.json").read_text(encoding="utf-8"))
        if result==0:
            report["baseline_output_sha256"]=sha(owned/"baseline.json")
            report["optimized_output_sha256"]=sha(owned/"optimized.json")
            assert report["baseline_output_sha256"]==report["optimized_output_sha256"]
    after=sha(database);assert after==before;report["database_sha256_after"]=after
    report["status"]="EXACT_REAL_SOURCE_NORMALIZATION_PARITY_PASS" if result==0 else "FAILED"
    (artifacts/"RESULT.json").write_bytes((json.dumps(report,ensure_ascii=False,indent=2)+"\n").encode("utf-8"))
    print(json.dumps(report,ensure_ascii=False))
    return result
if __name__=="__main__":raise SystemExit(main())
