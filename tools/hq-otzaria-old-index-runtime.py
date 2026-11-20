#!/usr/bin/env python3
"""Actual original265/d5 C consumers over authenticated, already-built indexes.

No application pin/policy is enabled. Inputs must have verified nonempty original
segments before either engine opens. Every published byte is hashed before/after.
The independent SQL oracle covers the explicitly listed complete source books;
legacy global results and full document/source coverage are separately checked.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import html
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import time

from otzaria_original_sql_oracle import ATTACHED, PRESENTATION, OriginalZstd, display_text, scan

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build/index-read-qualification-20261120"
PRODUCER = "265a14ea54f959a3e266d6e8acfa3a3b98101d68"
CONSUMER = "d5d59d1269bdf87fb0a6901cf31941726a0c699b"
BOOKS = [1, 28, 40, 103, 382, 3152, 3163, 3276, 3764, 3891]
QUERIES = ["תורה", "שלום", "אלהים", "ישראל", "רבי", "רמבם", 'רמב"ם', "אברהם"]
DATABASES = {
    "miniTest10-v6": (Path(r"C:\Users\DAVID\Code\Maktabah-actions-completion-20261120\build\actions-native-20261120\miniTest10\seforim.db"), "d3d9bfcc2320a987a0391ad23fa72abcf6fd1fa0f3cba95adc05096e05a9edef", 15470592),
    "full-v32": (Path(r"C:\Users\DAVID\Code\Maktabah-perf02-completion-20261120\build\perf02-20261120\full-v32\seforim.db"), "2f4dcd72e8bdb1fc5c0516ae9705e57759c017ec2981b49c35115625c3d3f765", 3821240320),
}
ZSTD_DLL = Path(r"C:\Users\DAVID\AppData\Local\Microsoft\WinGet\Packages\oschwartz10612.Poppler_Microsoft.Winget.Source_8wekyb3d8bbwe\poppler-25.07.0\Library\bin\libzstd.dll")
CLANG = Path(r"C:\Users\DAVID\AppData\Local\Programs\Swift\Toolchains\6.3.3+Asserts\usr\bin\clang.EXE")
WINDOWS_LIBS = Path(r"C:\Users\DAVID\.cargo\registry\src\index.crates.io-1949cf8c6b5b557f\windows_x86_64_msvc-0.52.6\lib")


def sha(path):
    result = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(4 * 1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def inventory(root):
    return {str(path.relative_to(root)).replace("\\", "/"):
            {"bytes": path.stat().st_size, "sha256": sha(path)}
            for path in sorted(root.rglob("*")) if path.is_file()}


def common_cases():
    result = []

    def case(name, query, operation="search", **kwargs):
        request = {"query": query, "mode": "exact", "limit": 25, "offset": 0,
                   "order": "catalogue", "grouping": "none"}
        request.update(kwargs)
        result.append((name, operation, request))

    case("phrase_catalogue", "בראשית ברא")
    case("phrase_relevance", "בראשית ברא", order="relevance")
    case("single_catalogue_page1", "תורה")
    case("single_catalogue_page2", "תורה", offset=25)
    case("single_relevance", "תורה", order="relevance")
    case("single_book_103", "תורה", bookIds=[103])
    case("single_books_union", "תורה", bookIds=[1, 28, 103])
    case("single_original_facet", "תורה", facets=["/book/103"])
    case("vocalized_original", "בְּרֵאשִׁית", matchNikud=True)
    case("quote_form", 'רמב"ם')
    case("quote_free_twin", "רמבם")
    case("fuzzy_global", "ירושלימ", mode="fuzzy", distance=1)
    case("fuzzy_book", "תורה", mode="fuzzy", distance=1, bookIds=[103])
    case("advanced_distance", "משה תורה", mode="advanced", distance=5)
    case("advanced_negative", "תורה", mode="advanced", negativeQuery="משה")
    case("advanced_paragraph", "בראשית ברא", mode="advanced", scope="sameParagraph")
    case("group_same_section", "תורה", grouping="sameSection")
    case("group_identical_text", "תורה", grouping="identicalText")
    case("absent", "otzariaqualificationmissingtermv20261120")
    case("book_counts", "תורה", operation="books")
    case("facet_counts", "תורה", operation="facets")
    return result


def occurrence_cases(profile):
    result = []
    scopes = [("books10", BOOKS), ("book103", [103]), ("book1", [1])]
    if profile == "miniTest10-v6":
        scopes.append(("global", None))
    for scope_name, books in scopes:
        for ordinal, query in enumerate(QUERIES):
            request = {"version": 1, "mode": "exact", "query": query, "timeoutMs": 60000}
            if books is not None:
                request["bookIds"] = books
            result.append((f"occ_{scope_name}_{ordinal}", "occurrences", request))
    result.append(("occ_empty_scope", "occurrences", {"version": 1, "mode": "exact", "query": "תורה", "bookIds": [900000000], "timeoutMs": 60000}))
    return result


def compile_consumer(engine):
    source = ROOT / "Tests/HQ/search/OriginalIndexReadConsumer.c"
    out = BUILD / "binaries" / engine
    out.mkdir(parents=True, exist_ok=True)
    if engine == "d5":
        library = out / "otzaria_search_engine_ios.lib"
        expected = "7f23e3e87aa604b410f9cd21f1b56aab2d30596c697d46c8fb19ad160e34c7a0"
        include = out
    else:
        library = BUILD / "producer-target/debug/otzaria_search_engine_ios.lib"
        expected = "16f6d54b9bacc49d708da4017051ebac0825c1f2adae163bf53a3908bb8b6cf7"
        include = ROOT / "Vendor/OtzariaSearchEngine/include"
    assert sha(library) == expected
    inputs = {"sourceSHA256": sha(source), "headerSHA256": sha(include / "otzaria_search_engine.h"),
              "librarySHA256": expected, "libraryBytes": library.stat().st_size}
    stamp = out / "READ_CONSUMER_BUILD.json"
    executable = out / "original-index-read.exe"
    if stamp.exists():
        prior = json.loads(stamp.read_text(encoding="utf-8"))
        assert prior["inputs"] == inputs and prior["exit"] == 0 and sha(executable) == prior["executableSHA256"]
        return executable, prior
    command = [str(CLANG), "-std=c11", "-Wall", "-Wextra", "-Werror", "-fms-runtime-lib=dll", "-Wno-deprecated-declarations"]
    if engine == "d5":
        command.append("-DHAS_OCCURRENCES=1")
    command += ["-I", str(include), str(source), str(library), "-o", str(executable),
                "-Xlinker", "/LIBPATH:" + str(WINDOWS_LIBS), "-Xlinker", "/NODEFAULTLIB:libcmt"]
    for library_name in ("windows.0.52.0.lib", "legacy_stdio_definitions.lib", "kernel32.lib", "ntdll.lib",
                         "userenv.lib", "ws2_32.lib", "dbghelp.lib", "/defaultlib:msvcrt"):
        command.extend(["-Xlinker", library_name])
    start = time.monotonic()
    done = subprocess.run(command, capture_output=True, timeout=180)
    (out / "read-consumer-build.log").write_bytes(done.stdout + done.stderr)
    report = {"inputs": inputs, "command": command, "exit": done.returncode, "seconds": round(time.monotonic() - start, 3)}
    if done.returncode == 0:
        report["executableSHA256"] = sha(executable)
    save(stamp, report)
    assert done.returncode == 0, done.stderr.decode("utf-8", "replace")
    return executable, report


def run_consumer(executable, index, cases, out, label):
    commands = out / (label + "-commands.tsv")
    commands.write_text("".join(name + "\t" + operation + "\t" + json.dumps(request, ensure_ascii=False, separators=(",", ":")) + "\n" for name, operation, request in cases), encoding="utf-8", newline="")
    log = out / (label + "-consumer.log")
    started = time.monotonic()
    with log.open("wb") as sink:
        process = subprocess.run([str(executable), str(index), str(commands)], stdout=sink, stderr=subprocess.STDOUT, timeout=1200)
    parsed = {}
    for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("OTZARIA_QUAL\t"):
            _, name, payload = line.split("\t", 2)
            assert name not in parsed
            parsed[name] = json.loads(payload)
    report = {"exit": process.returncode, "seconds": round(time.monotonic() - started, 3),
              "logSHA256": sha(log), "commandsSHA256": sha(commands), "executableSHA256": sha(executable), "responses": parsed}
    save(out / (label + "-result.json"), report)
    return report


def sql_locator_checks(connection, decoder, cases, responses):
    checks = []
    for name, operation, request in cases:
        response = responses.get(name, {})
        if operation != "search" or not response.get("ok"):
            continue
        for item in response["value"]["results"]:
            assert item["filePath"].startswith("otzaria-book:")
            book_id = int(item["filePath"].removeprefix("otzaria-book:"))
            segment, identifier = int(item["segment"]), int(item["id"])
            # Actual producer add_text_book uses ((catalogueOrder+1)<<32)
            # + ordinal+1, and stores the independent zero-based segment.
            # The app's original navigationItems uses segment, never packed ID.
            source = connection.execute("SELECT l.id,l.lineIndex,lc.content,b.title FROM line l JOIN line_content lc ON lc.id=l.id JOIN book b ON b.id=l.bookId WHERE l.bookId=? ORDER BY l.lineIndex LIMIT 1 OFFSET ?", (book_id, segment)).fetchone()
            packed_id_valid = (identifier >> 32) > 0 and (identifier & 0xffffffff) == segment + 1
            matched = False
            fragment_offset = None
            fragment = html.unescape(item["text"].replace("<font color=red>", "").replace("</font>", ""))
            fragment = " ".join("".join(c for char in fragment for c in PRESENTATION.get(char, char) if c not in ATTACHED).split())
            if source is not None:
                source_text = display_text(decoder.decode(source[2]), pdf=bool(item["isPdf"]))
                # Public search results are Tantivy snippets, not whole stored
                # lines: original producer lines8108..8126 select fragment()
                # and to_html(), which escapes data and can stop before final
                # punctuation. Bind that exact decoded fragment to the genuine
                # SQL row, retaining full original265/d5 result JSON parity.
                fragment_offset = source_text.find(fragment) if fragment else -1
                matched = source[1] == segment and source[3] == item["title"] and fragment_offset >= 0
            checks.append({"case": name, "bookId": book_id, "engineID": identifier, "engineSegment": segment,
                           "packedIDOrdinalValid": packed_id_valid,
                           "decodedSnippetCharacters": len(fragment), "sourceFragmentOffset": fragment_offset,
                           "sourceLineID": None if source is None else source[0],
                           "sourceLineIndex": None if source is None else source[1],
                           "passed": packed_id_valid and matched})
    return checks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", required=True, choices=DATABASES)
    parser.add_argument("--attempt", required=True)
    args = parser.parse_args()
    assert re_safe_name(args.attempt)
    out = BUILD / "runtime" / args.profile / args.attempt
    assert not out.exists(), "preserve previous actual attempt"
    out.mkdir(parents=True)
    inputs = BUILD / "artifacts" / args.profile
    receipt = json.loads((inputs / "INPUT_VERIFIED.json").read_text(encoding="utf-8"))
    published = receipt["published_files"]
    expected_docs = receipt["metadata_document_count_before_any_engine_open"]
    assert inventory(inputs / "pristine") == published
    assert receipt["producer"]["commit"] == PRODUCER and receipt["engine_opened"] is False
    copies = BUILD / "read-copies" / args.profile
    assert (copies / "COPY_VERIFIED.json").exists()
    before = {}
    for label in ("producer265", "consumerd5"):
        before[label] = inventory(copies / label)
        assert before[label] == published, "require pristine original payload immediately before engine open"
        meta = json.loads((copies / label / "meta.json").read_text(encoding="utf-8"))
        assert meta["segments"] == receipt["original_segments"] and expected_docs > 0
    database, database_sha, database_size = DATABASES[args.profile]
    assert database.stat().st_size == database_size and sha(database) == database_sha
    save(out / "PREOPEN.json", {"observedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(), "receiptSHA256": sha(inputs / "INPUT_VERIFIED.json"),
         "originalManifestSHA256": receipt["manifest_sha256"], "databasePath": str(database), "databaseSHA256": database_sha,
         "databaseBytes": database_size, "indexInventories": before, "originalSegments": receipt["original_segments"],
         "metadataDocumentCount": expected_docs, "indexAlreadyBuiltBeforeEitherEngineOpen": True, "databaseDownloaded": False})
    print(json.dumps({"phase": "preopen", "profile": args.profile, "originalDocuments": expected_docs}), flush=True)
    connection = sqlite3.connect(database.as_uri() + "?mode=ro&immutable=1", uri=True)
    decoder = OriginalZstd(connection, ZSTD_DLL)
    sql_docs = connection.execute("SELECT COUNT(*) FROM line").fetchone()[0]
    sql_sources = {f"otzaria-book:{r[0]}" for r in connection.execute("SELECT DISTINCT bookId FROM line")}
    oracle, oracle_rows = scan(connection, decoder, BOOKS, QUERIES)
    oracle.update({"databaseSHA256": database_sha, "allSQLDocuments": sql_docs, "allSQLSources": len(sql_sources),
                   "scope": "All original decoded rows of ten explicit books; full-v32 global occurrence scalar is not independently scanned."})
    save(out / "SQL_ORACLE.json", oracle)
    print(json.dumps({"phase": "oracle", "profile": args.profile, "sourceRows": oracle["rowsScanned"], "SQLDocuments": sql_docs}), flush=True)
    compiled = {label: compile_consumer(engine) for label, engine in (("producer265", "265"), ("consumerd5", "d5"))}
    common = common_cases()
    occurrences = occurrence_cases(args.profile)
    actual = {}
    after = {}
    for label in ("producer265", "consumerd5"):
        actual[label] = run_consumer(compiled[label][0], copies / label, common + (occurrences if label == "consumerd5" else []), out, label)
        after[label] = inventory(copies / label)
        save(out / (label + "-after-inventory.json"), after[label])
        print(json.dumps({"phase": "engine_complete", "profile": args.profile, "engine": label, "exit": actual[label]["exit"], "seconds": actual[label]["seconds"]}), flush=True)
    actual["producer265_reopen_after_d5"] = run_consumer(compiled["producer265"][0], copies / "consumerd5", common, out, "producer265_reopen_after_d5")
    after_rollback = inventory(copies / "consumerd5")
    save(out / "after-rollback-inventory.json", after_rollback)
    checks = []

    def check(name, passed, detail=None):
        item = {"name": name, "passed": bool(passed)}
        if detail is not None: item["detail"] = detail
        checks.append(item)

    check("original_sql_documents_match_published_metadata", sql_docs == expected_docs)
    values = {name: result["responses"] for name, result in actual.items()}
    for label in ("producer265", "consumerd5"):
        responses = values[label]
        check(label + "_process_completed", actual[label]["exit"] == 0 and responses.get("closed", {}).get("closed") is True)
        check(label + "_preexisting_payload_unchanged", all(after[label].get(name) == metadata for name, metadata in published.items()))
        check(label + "_all_expected_common_calls_present", all(name in responses for name, _, _ in common))
        for when in ("before", "after"):
            value = responses.get("document_count_" + when, {})
            check(label + "_actual_documents_" + when, value.get("ok") is True and value.get("value") == expected_docs, value)
        paths = responses.get("indexed_file_paths", {})
        check(label + "_actual_source_ids_match_original_sql", paths.get("ok") is True and set(paths.get("value") or []) == sql_sources)
        info = responses.get("build_info", {})
        check(label + "_actual_build_info_success", info.get("ok") is True, info)
        build = info.get("value") or {}
        expected_engine = ("Otzaria/otzaria_search_engine", "refactor", PRODUCER) if label == "producer265" else ("davidpovarsky/otzaria_search_engine", "codex/otzaria-exact-occurrences-20261120", CONSUMER)
        check(label + "_actual_engine_provenance", (build.get("upstreamRepository"), build.get("upstreamBranch"), build.get("upstreamCommit")) == expected_engine
              and build.get("engineVersion") == "0.1.0" and build.get("indexSchemaVersion") == 4
              and build.get("defaultGenerationOrder") == 5 and build.get("adapterVersion") == "0.1.0"
              and build.get("resourceHashes") == {
                  "Vendor/OtzariaSearchEngine/Resources/dictionary.json": "cc3d02655bd3f5a8f7581cf71623cf60b3cd6ee821686cebf149f755272e9a69",
                  "Vendor/OtzariaSearchEngine/Resources/Acronyms.json": "cb101c9feb87394b133098bf569bd9af167babce0f83ab3b151e2599c665389f"})
        compatibility = responses.get("compatibility", {})
        check(label + "_original_schema_compatibility", compatibility.get("ok") is True and (compatibility.get("value") or {}).get("compatible") is True, compatibility)
    for name, operation, request in common:
        left, right = values["producer265"].get(name), values["consumerd5"].get(name)
        check("legacy_parity_" + name, left == right and left is not None and left.get("ok") is True)
    fingerprints = values["producer265"].get("book_fingerprints", {})
    check("book_fingerprint_parity", fingerprints.get("ok") is True and fingerprints == values["consumerd5"].get("book_fingerprints"))
    rollback = actual["producer265_reopen_after_d5"]
    check("original265_cold_reopens_candidate_read_copy", rollback["exit"] == 0 and rollback["responses"].get("document_count_before", {}).get("value") == expected_docs
          and rollback["responses"].get("document_count_after", {}).get("value") == expected_docs
          and all(rollback["responses"].get(name) == values["producer265"].get(name) and name in values["producer265"] for name, _, _ in common))
    check("producer_rollback_keeps_every_original_payload_byte", all(after_rollback.get(name) == metadata for name, metadata in published.items()))
    locator_checks = sql_locator_checks(connection, decoder, common, values["consumerd5"])
    save(out / "SQL_LOCATORS.json", locator_checks)
    check("actual_ranked_page_locators_bind_original_sql_rows", bool(locator_checks) and all(x["passed"] for x in locator_checks), {"checked": len(locator_checks), "failed": [x for x in locator_checks if not x["passed"]][:30]})
    for name, operation, request in occurrences:
        response = values["consumerd5"].get(name, {})
        books = request.get("bookIds", BOOKS)
        expected = {"occurrences": 0, "matchingLiveDocuments": 0}
        for book in books:
            source = oracle["queries"][request["query"]]["books"].get(str(book), {})
            for key in expected:
                expected[key] += source.get(key, 0)
        value = response.get("value") or {}
        check("independent_sql_" + name, response.get("ok") is True and all(value.get(key) == n for key, n in expected.items()), {"query": request["query"], "bookIds": request.get("bookIds"), "expected": expected, "actual": response})
        proof = value.get("proof") or {}
        expected_facets = sorted({f"/book/{book}" for book in request["bookIds"]}) if "bookIds" in request else ["/"]
        expected_segments = sorted((segment["segment_id"].replace("-", ""), None if segment.get("deletes") is None else segment["deletes"]["opstamp"]) for segment in receipt["original_segments"])
        actual_segments = sorted((segment["segmentId"], segment["deleteOpstamp"]) for segment in proof.get("searcherGeneration", {}).get("segments", []))
        check("held_original_snapshot_proof_" + name,
              proof.get("exact") is True and proof.get("countKind") == "distinctTokenPositions"
              and proof.get("engineRepository") == "davidpovarsky/otzaria_search_engine"
              and proof.get("engineBranch") == "codex/otzaria-exact-occurrences-20261120"
              and proof.get("engineCommit") == CONSUMER and proof.get("originalUpstreamBase") == PRODUCER
              and proof.get("liveIndexDocuments") == expected_docs and proof.get("indexSchemaVersion") == 4
              and proof.get("requestedFacets") == expected_facets and proof.get("requestToken", 0) > 0
              and actual_segments == expected_segments)
    decoder.close(); connection.close()
    check("original_database_unchanged", sha(database) == database_sha)
    check("never_opened_pristine_payload_unchanged", inventory(inputs / "pristine") == published)
    result = {"profile": args.profile, "attempt": args.attempt, "finishedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "passed": all(x["passed"] for x in checks), "checks": checks,
              "counts": {"checks": len(checks), "passed": sum(x["passed"] for x in checks), "failed": sum(not x["passed"] for x in checks), "skipped": 0},
              "legacyCases": len(common), "occurrenceCases": len(occurrences), "SQLLocatorComparisons": len(locator_checks),
              "originalDocuments": expected_docs, "SQLOracleRows": oracle["rowsScanned"], "SQLOracleBookIds": BOOKS,
              "rawRunFiles": {label: {"logSHA256": actual[label]["logSHA256"], "commandsSHA256": actual[label]["commandsSHA256"], "executableSHA256": actual[label]["executableSHA256"]} for label in actual},
              "additionalEngineCreatedFiles": {label: {name: metadata for name, metadata in after[label].items() if name not in published} for label in after},
              "productionPolicyEnabled": False, "AppleSDK": "NOT_RUN", "Native": "NOT_RUN", "indexRebuilt": False,
              "diskFreeAfter": shutil.disk_usage(BUILD).free}
    save(out / "RESULT.json", result)
    print(json.dumps({"path": str(out / "RESULT.json"), "passed": result["passed"], "counts": result["counts"], "failures": [x["name"] for x in checks if not x["passed"]]}), flush=True)
    return 0 if result["passed"] else 1


def re_safe_name(value):
    return value and all(c in "abcdefghijklmnopqrstuvwxyz0123456789-_" for c in value)


if __name__ == "__main__":
    raise SystemExit(main())
