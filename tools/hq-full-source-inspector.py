#!/usr/bin/env python3
"""Real original Inspector relationship/SQLite/ZSTD services over pinned full v32.
No UIKit/real device claim. The host bridge, two data-only DTOs and telemetry are
explicit boundaries. SQL, decoder, models, classification and grouping are source.
"""
from pathlib import Path
import argparse,ctypes,datetime,hashlib,json,os,platform,re,shutil,sqlite3,subprocess,uuid
ROOT=Path(__file__).resolve().parents[1]
REFERENCES={"REFERENCE","QUOTATION","MESORAT_HASHAS","EIN_MISHPAT","MISHNAH_IN_TALMUD",
            "RELATED","OTHER","SIFREI_MITZVOT","ESSAY","ALLUSION","LITURGY","LAW","SUMMARY"}
DEPENDENT={"COMMENTARY","SUPER_COMMENTARY","TARGUM","MIDRASH","PARSHANUT","DIBUR_HAMATCHIL",
           "ELUCIDATION","EXPLICATION","FOOTNOTES"}
def sha(path):
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(8*1024*1024),b""):h.update(chunk)
    return h.hexdigest()
def chunks(values,size=900):
    values=list(values)
    for at in range(0,len(values),size):yield values[at:at+size]
def independent_relationships(db,book,indices):
    # Set-based Python oracle. Never reuses the service's resolved/matched CTE.
    line_ids={r[0] for chunk in chunks(indices)
        for r in db.execute("SELECT id FROM line WHERE bookId=? AND lineIndex IN ("+
                            ",".join("?" for _ in chunk)+")",[book,*chunk])}
    kinds=dict(db.execute("SELECT id,name FROM connection_type"))
    links=db.execute("SELECT id,sourceBookId,targetBookId,sourceLineId,targetLineId,connectionTypeId "
                     "FROM link WHERE sourceBookId=? OR targetBookId=?",(book,book)).fetchall()
    hidden=set(db.execute("SELECT h.linkId,h.side FROM link_suppressed_side h JOIN link l ON l.id=h.linkId "
                          "WHERE l.sourceBookId=? OR l.targetBookId=?",(book,book)))
    coverage={}
    for chunk in chunks(line_ids):
        for line,link,side in db.execute("SELECT lineId,linkId,side FROM link_coverage WHERE lineId IN ("+
                                        ",".join("?" for _ in chunk)+")",chunk):
            coverage.setdefault((link,side),set()).add(line)
    expected={}
    for key,source,target,source_line,target_line,kind in links:
        raw=kinds.get(kind,"OTHER")
        forward=({source_line}|coverage.get((key,0),set())) & line_ids
        inverse=({target_line}|coverage.get((key,1),set())) & line_ids
        eligible=[]
        if source==book and forward and (key,0) not in hidden:
            eligible.append((0,target,target_line))
        same_work=raw in REFERENCES and ((key,0) in hidden or
            any(anchor!=source_line and anchor not in coverage.get((key,0),set()) for anchor in inverse))
        if target==book and inverse and (key,1) not in hidden and raw in REFERENCES|DEPENDENT and (source!=target or same_work):
            eligible.append((1,source,source_line))
        for side,linked_book,linked_line in eligible:
            item=expected.setdefault((key,linked_book,linked_line),
                dict(sides=set(),raw=raw,source=source,target=target))
            item["sides"].add(side)
    return expected
def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--database",type=Path,required=True)
    ap.add_argument("--artifacts-dir",type=Path,required=True)
    args=ap.parse_args()
    artifacts=args.artifacts_dir.resolve();artifacts.mkdir(parents=True,exist_ok=True)
    database=args.database.resolve(strict=True)
    seed=ROOT/"Scripts/DataProfiles/miniTest10.seed.json"
    pin=json.loads(seed.read_text(encoding="utf-8"))["source"]
    assert pin["releaseTag"]=="v32-20261010190601"
    assert database.stat().st_size==pin["databaseBytes"]
    before=sha(database);assert before==pin["databaseSHA256"]
    owned=ROOT/"build"/("fi32-"+uuid.uuid4().hex[:12]);owned.mkdir()
    uri=database.as_uri()+"?mode=ro&immutable=1"
    db=sqlite3.connect(uri,uri=True)
    book_indices={bid:[r[0] for r in db.execute("SELECT lineIndex FROM line WHERE bookId=? ORDER BY lineIndex",(bid,))]
                  for bid in [103,28]}
    windows=[
        dict(name="berakhot-500-lines",bookID=103,indices=book_indices[103][:500]),
        dict(name="berakhot-401-sparse-lines",bookID=103,indices=book_indices[103][1000:1802:2]),
        dict(name="tehillim-100-lines",bookID=28,indices=book_indices[28][:100])
    ]
    assert [len(w["indices"]) for w in windows]==[500,401,100]
    expected={w["name"]:independent_relationships(db,w["bookID"],w["indices"]) for w in windows}
    assert all(len(rows)>=2000 for rows in expected.values()),{k:len(v) for k,v in expected.items()}
    (owned/"input.json").write_bytes(json.dumps(dict(uri=uri,windows=windows)).encode("utf-8"))
    production=[
        "Source/Core/Database/SQLiteDatabase.swift","Source/Core/Database/ZstdShim.swift",
        "Source/Otzaria/Core/OtzariaSQLiteError.swift","Source/Otzaria/Core/OtzariaSQLiteStatement.swift",
        "Source/Otzaria/Core/String+OtzariaText.swift","Source/Otzaria/Data/OtzariaSchema.swift",
        "Source/Otzaria/Data/OtzariaBookSchemaCompatibility.swift",
        "Source/Otzaria/Reading/OtzariaReadingUnit.swift",
        "Source/Otzaria/Reading/OtzariaReadingUnitDescriptor.swift",
        "Source/Otzaria/Reading/OtzariaLineAnchor.swift",
        "Source/Otzaria/Reading/OtzariaCategoryPathResolver.swift",
        "Source/Otzaria/Reading/OtzariaRelationshipClassifier.swift",
        "Source/Otzaria/Reading/OtzariaLinkedSourceGrouping.swift"
    ]
    model_name="Source/Otzaria/Domain/OtzariaModels.swift";models=(ROOT/model_name).read_text(encoding="utf-8")
    a=models.index("struct OtzariaLinkedSource:");b=models.index("struct OtzariaSourceSection:",a)
    selected=models[a:b]
    (owned/"LinkedSource.swift").write_bytes(("import Foundation\n"+selected).encode("utf-8"))
    service_name="Source/Otzaria/Reading/OtzariaLineSourcesService.swift"
    service=(ROOT/service_name).read_text(encoding="utf-8")
    assert service.count("import TorahInspectorCore")==1
    (owned/"LineSources.swift").write_bytes(service.replace("import TorahInspectorCore","").encode("utf-8"))
    if os.name!="nt":raise RuntimeError("Existing Windows host only; Apple/device evidence is separate.")
    dll=Path(os.environ.get("ProgramFiles",r"C:\Program Files"))/"Git/mingw64/bin/libzstd.dll"
    assert dll.is_file()
    lib=ctypes.CDLL(str(dll));lib.ZSTD_versionString.restype=ctypes.c_char_p
    zstd_version=lib.ZSTD_versionString().decode("ascii")
    shutil.copyfile(dll,owned/"libzstd.dll")
    symbols=re.findall(r'@_silgen_name\("([^"]+)"\)',(ROOT/"Source/Core/Database/ZstdShim.swift").read_text(encoding="utf-8"))
    (owned/"zstd.def").write_bytes(("LIBRARY libzstd.dll\nEXPORTS\n"+"\n".join(symbols)+"\n").encode("ascii"))
    imp=owned/"zstd.lib"
    subprocess.run([shutil.which("llvm-dlltool"),"-m","i386:x86-64","-d",str(owned/"zstd.def"),"-l",str(imp)],check=True,capture_output=True)
    sdkroot=Path(os.environ.get("ProgramFiles(x86)",r"C:\Program Files (x86)"))/"Windows Kits/10"
    sdk=next(p for p in sorted((sdkroot/"Include").glob("*"),reverse=True) if (p/"um/winsqlite/winsqlite3.h").is_file())
    module=owned/"SQLite3";module.mkdir()
    (module/"module.modulemap").write_bytes(('module SQLite3 [system] { header "'+(sdk/"um/winsqlite/winsqlite3.h").as_posix()+
        '" link "winsqlite3" export * }\n').encode("utf-8"))
    fixtures=["Tests/HQ/sqlite/UnusedZstdBoundary.swift","Tests/HQ/inspector/FullSourceInspectorAcceptance.swift"]
    exe=owned/"full-inspector.exe"
    command=[shutil.which("swiftc"),"-parse-as-library","-swift-version","6","-Xfrontend","-strict-concurrency=complete",
        "-I",str(owned),"-L",str(sdkroot/"Lib"/sdk.name/"um/x64"),
        *[str(ROOT/p) for p in production+fixtures],str(owned/"LinkedSource.swift"),
        str(owned/"LineSources.swift"),str(imp),"-o",str(exe)]
    report=dict(observed_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        source_sha=subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
        source_files={p:sha(ROOT/p) for p in production+fixtures+[model_name,service_name]},
        generated_model_sha256=sha(owned/"LinkedSource.swift"),
        generated_service_sha256=sha(owned/"LineSources.swift"),
        host=platform.platform(),swift=subprocess.check_output([command[0],"--version"],text=True).strip(),
        database_sha256_before=before,source_pin=pin,owned_fixture=str(owned),
        expected_relationships={k:len(v) for k,v in expected.items()},
        zstd=dict(path=str(dll),version=zstd_version,sha256=sha(dll)),
        boundaries=["host bridge supplies actual readonly SQLiteDatabase (does not test app connection ownership)",
            "CategoryData and TorahLinkedSource data-only DTOs; no TorahInspectorCore/UI module",
            "telemetry/logging no-ops; unused legacy compressed-column API fails if called"],
        native_ui_executed=0,physical_device_executed=0,command=command)
    def save():
        (artifacts/"RESULT.json").write_bytes((json.dumps(report,ensure_ascii=False,indent=2)+"\n").encode("utf-8"))
    build=subprocess.run(command,capture_output=True,text=True,encoding="utf-8",timeout=150)
    (artifacts/"compile.log").write_bytes((build.stdout+build.stderr).encode("utf-8"))
    report["compile_exit"]=build.returncode
    if build.returncode:
        print(build.stderr[-10000:]);report["status"]="COMPILE_FAILED";save();return build.returncode
    output=owned/"output";output.mkdir()
    try:run=subprocess.run([str(exe),str(owned/"input.json"),str(output)],capture_output=True,text=True,encoding="utf-8",timeout=300)
    except subprocess.TimeoutExpired:
        report["status"]="INCOMPLETE_TIMEOUT_NO_PASS";save();raise
    (artifacts/"tests.log").write_bytes((run.stdout+run.stderr).encode("utf-8"))
    print(run.stdout);print(run.stderr[-4000:]);report["execute_exit"]=run.returncode
    if (output/"RESULT.json").exists():report["swift_inspector"]=json.loads((output/"RESULT.json").read_text(encoding="utf-8"))
    report["status"]="FAILED"
    if run.returncode:save();return run.returncode
    import zstandard
    dictionaries=[zstandard.ZstdCompressionDict(r[0]) for r in db.execute("SELECT dict FROM zstd_dict")]
    decoders={d.dict_id():zstandard.ZstdDecompressor(dict_data=d) for d in dictionaries}
    books={r[0]:r[1:] for r in db.execute("SELECT id,title,categoryId,orderIndex FROM book")}
    cats={r[0]:r[1:] for r in db.execute("SELECT id,title,parentId FROM category")}
    def category_path(id):
        path=[];seen=set()
        while id is not None and id not in seen and id in cats:
            seen.add(id);name,id=cats[id];path.append(name)
        return list(reversed(path))
    verified=[]
    try:
        for window in windows:
            name=window["name"];oracle=expected[name]
            rows=json.loads((output/(name+".json")).read_text(encoding="utf-8"))
            actual={(r["id"],r["linked_book"],r["linked_line"]) for r in rows}
            assert len(rows)==len(actual) and actual==set(oracle),(name,len(actual),len(oracle))
            source={}
            for chunk in chunks(sorted({key[2] for key in oracle})):
                query="SELECT l.id,l.bookId,l.lineIndex,l.heRef,lc.content FROM line l LEFT JOIN line_content lc ON lc.id=l.id WHERE l.id IN ("+",".join("?" for _ in chunk)+")"
                for id,bid,index,ref,content in db.execute(query,chunk):
                    if isinstance(content,bytes):
                        frame=zstandard.get_frame_parameters(content)
                        assert frame.content_size<=16*1024*1024
                        content=decoders[frame.dict_id].decompress(content).decode("utf-8")
                    assert isinstance(content,str)
                    source[id]=(bid,index,ref,content)
            for row in rows:
                key=(row["id"],row["linked_book"],row["linked_line"]);expected_row=oracle[key]
                title,category,order=books[row["linked_book"]]
                assert (row["linked_book"],row["line_index"],row["he_ref"],row["content"])==source[row["linked_line"]]
                assert (row["book_title"],row["category_id"],row["book_order"])==(title,category,order)
                assert row["category_path"]==category_path(category)
                assert row["matched_side"] in expected_row["sides"]
                assert (row["raw_type"],row["source_book"],row["target_book"])==(expected_row["raw"],expected_row["source"],expected_row["target"])
            ordering=[(row["book_order"],row["line_index"],row["id"]) for row in rows]
            assert ordering==sorted(ordering)
            verified.append(dict(case=name,relationships=len(rows),
                unique_decoded_lines=len(source),metadata_and_original_html_exact=True,
                raw_owned_output_sha256=sha(output/(name+".json")),
                identity_set_sha256=hashlib.sha256(json.dumps(sorted(actual)).encode("utf-8")).hexdigest()))
        report["independent_python_sqlite_zstd_oracles"]=verified
        report["database_sha256_after"]=sha(database)
        assert report["database_sha256_after"]==before
        report["status"]="ACTUAL_FULL_V32_INSPECTOR_PASS_NOT_UI"
    finally:
        db.close();save()
    print(json.dumps({"status":report["status"],"windows":len(verified),
        "verified_relationship_appearances":sum(v["relationships"] for v in verified),
        "owned_fixture":str(owned)},ensure_ascii=False))
    return 0
if __name__=="__main__":raise SystemExit(main())
