"""Seal original Native88 evidence; never launch tests or infer new-source PASS."""
from pathlib import Path
import argparse, datetime, gzip, hashlib, json, re, shutil, subprocess, zipfile


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes((json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    src, out = args.input.resolve(), args.output.resolve()
    assert not out.exists(), "preserve existing evidence; inspect before repeating"
    out.mkdir(parents=True)
    (out / "package-native88-evidence.py").write_bytes(Path(__file__).read_bytes())
    review = json.loads((src / "VERIFIED_CASES.json").read_bytes())
    assert review["counts"] == dict(passed=46, failed=24, skipped=0, not_run=18, recorded=70)
    assert review["provenance_or_count_errors"] == []
    assert review["checkout_sha"] == "fe4df7c39aec242d00046bc454c81963ba4285a0"
    assert review["application_sha"] == "7e777509d486a17bec5b4bd437a9ac7f51d3a43a"
    archive = src / "runtime27-evidence.zip"
    verified = json.loads((src / "ARTIFACT_VERIFIED.json").read_bytes())
    assert verified["actualSHA256"] == "ced48935baf6c27a7df229b1e438ae30113fcad7939ccfa5783ad4262723872c"
    assert verified["verified"] is True and archive.stat().st_size == verified["bytes"]
    phone = json.loads((src / "PHONE_PARTIAL_LOG_OBSERVATION.json").read_bytes())
    assert len(phone["starts"]) == 16 and len(phone["terminalLogObservations"]) == 15
    assert sum(x["result"] == "passed" for x in phone["terminalLogObservations"]) == 7
    assert sum(x["result"] == "failed" for x in phone["terminalLogObservations"]) == 8
    assert phone["xcresultExportPresent"] is False
    expected_phone = {x["case_id"] for x in review["cases"] if x["group"] == "phone"}
    phone["noStartObserved"] = sorted(expected_phone - set(phone["starts"]))
    phone["startedWithoutTerminalLog"] = sorted(set(phone["starts"]) - {x["case_id"] for x in phone["terminalLogObservations"]})
    assert len(phone["noStartObserved"]) == 2 and len(phone["startedWithoutTerminalLog"]) == 1
    write_json(out / "VERIFIED_CASES.json", review)
    write_json(out / "PHONE_PARTIAL_LOG_OBSERVATION.json", phone)
    write_json(out / "ARTIFACT_VERIFIED.json", verified)
    for name in ["FINAL_RUN.json", "ARTIFACTS.json", "WATCH_0554_STARTED.json", "WATCH_0554_RESULT.json", "TAKEOVER_OBSERVATION.json", "DISPATCH_PROVENANCE.json", "HISTORICAL_NATIVE78.json", "SELECTED_CAPTURE_REQUEST.json"]:
        if (src / name).exists():
            write_json(out / name, json.loads((src / name).read_bytes()))
    for name in ["original-R27_CASES.json", "original-SOURCE_FREEZE.json", "original-prepared-xctest-declarations.json", "CURRENT_92_CASE_MANIFEST.json", "review-native-evidence.py", "native88-http206-reader.py"]:
        (out / name).write_bytes((src / name).read_bytes())

    ledger, timelines = [], []
    with zipfile.ZipFile(archive) as z:
        keep_names = []
        for name in z.namelist():
            keep = (
                name.startswith("artifacts/runtime27/verified-") and name.endswith(".json")
                or name.startswith("artifacts/test-simulator-") and name.endswith(".log")
                or name.startswith("artifacts/test-case-execution-") and name.endswith(".json")
                or name.startswith("artifacts/runtime27/fixture-oracle-") and name.endswith(".json")
                or name.startswith("artifacts/runtime27/url-delivery-") and name.endswith(".jsonl")
                or name.startswith("artifacts/native-routing-logs-") and name.endswith((".log", ".json"))
                or name in {"artifacts/runtime27/result.json", "hq-stage2/result.json", "artifacts/runtime27/native-matrix-driver.log", "artifacts/runtime27/hid-11-window.jsonl", "artifacts/runtime27/palette-input-11-window.json", "artifacts/runtime27/palette-input-11-window-stream.json"}
            )
            if keep:
                keep_names.append(name)
        for name in keep_names:
            raw = z.read(name)
            packed = gzip.compress(raw, mtime=0)
            rel = "original/" + name.replace("/", "__") + ".gz"
            target = out / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(packed)
            assert gzip.decompress(packed) == raw
            ledger.append(dict(zipEntry=name, bytes=len(raw), sha256=sha(raw), savedAs=rel, gzipBytes=len(packed), gzipSHA256=sha(packed)))
        for case in review["cases"]:
            if case["result"] != "Failed":
                continue
            suite, method = case["case_id"].split("/")
            entry = "artifacts/test-simulator-" + case["group"] + ".log"
            raw = z.read(entry)
            marker = f"Test Case '-[Maktabah_iOSUITests.{suite} {method}]' started.".encode()
            assert raw.count(marker) == 1, case["case_id"]
            start = raw.index(marker)
            remaining = raw[start + len(marker):]
            nxt = re.search(rb"Test Case '-\[[^\r\n]+\]' started\.", remaining)
            end = start + len(marker) + nxt.start() if nxt else len(raw)
            span = raw[start:end]
            rel = "failure-timelines/" + method + ".log.gz"
            target = out / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(gzip.compress(span, mtime=0))
            lines = span.decode().splitlines()
            excerpts = []
            for i, line in enumerate(lines):
                if " error: " in line or "Test exceeded execution time allowance" in line:
                    excerpts.append("\n".join(lines[max(0, i-15):i+3]))
            timelines.append(dict(case_id=case["case_id"], originalEntry=entry, originalEntrySHA256=sha(raw), originalActivityBytes=len(span), originalActivitySHA256=sha(span), savedAs=rel, failureExcerpts=excerpts, tailIfNoExplicitError=None if excerpts else "\n".join(lines[-40:])))
        runtime = json.loads(z.read("artifacts/runtime27/result.json"))
        build = json.loads(z.read("hq-stage2/result.json"))

    assert len(timelines) == 24
    write_json(out / "FAILURE_TIMELINES.json", timelines)
    historical = json.loads((src / "HISTORICAL_NATIVE78.json").read_bytes())
    current = {x["case_id"]: x for x in review["cases"]}
    comparison = []
    for old in historical["cases"]:
        if old["result"] != "Failed":
            continue
        now = current[old["case_id"]]
        raw_phone = next((x for x in phone["terminalLogObservations"] if x["case_id"] == old["case_id"]), None)
        comparison.append(dict(case_id=old["case_id"], native78="Failed", native88VerifiedLeaf=now["result"], native88Failure=now["failures"], native88PartialPhoneLog=raw_phone))
    write_json(out / "NATIVE78_COMPARISON.json", comparison)

    captures = src / "selected-captures"
    assert (captures / "RANGE_EVIDENCE.json").exists(), "selected captures must finish first"
    selection = json.loads((src / "SELECTED_CAPTURE_REQUEST.json").read_bytes())
    range_proof = json.loads((captures / "RANGE_EVIDENCE.json").read_bytes())
    assert range_proof["artifactID"] == 14605489369 and range_proof["fullArchiveHashVerified"] is False
    requested = {x["zipEntry"] for x in selection}
    assert requested == {x["zipEntry"] for x in range_proof["selected"]}
    for name in ["ARTIFACT_METADATA.json", "RANGE_EVIDENCE.json"]:
        write_json(out / "captures" / name, json.loads((captures / name).read_bytes()))
    # Preserve the exact central directory and returned range bytes. These small
    # pieces are reviewable proof, never a claim that the entire 2.17GB was read.
    for rel in ["CENTRAL_DIRECTORY_INDEX.json"]:
        raw = (captures / rel).read_bytes()
        target = out / "captures" / (rel + ".gz")
        target.write_bytes(gzip.compress(raw, mtime=0))
    for item in range_proof["ranges"]:
        raw = (captures / item["file"]).read_bytes()
        assert sha(raw) == item["sha256"] and len(raw) == item["bytes"]
        target = out / "captures" / item["file"]
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)
    for item in range_proof["selected"]:
        raw = (captures / "entries" / item["zipEntry"]).read_bytes()
        assert sha(raw) == item["sha256"] and len(raw) == item["bytes"]
        # JSON/AX bytes are retained losslessly; PNG bytes remain available in
        # the already-retained validated compressed ranges and original artifact.
        if not item["zipEntry"].endswith(".png"):
            target = out / "captures" / "entries" / (item["zipEntry"] + ".gz")
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(gzip.compress(raw, mtime=0))
    for group in ["11", "11-search", "11-window"]:
        rel = "visual-" + group + "/manifest.json"
        raw = (src / "captures-manifests" / "entries" / rel).read_bytes()
        target = out / "captures" / "manifests" / (rel.replace("/", "__") + ".gz")
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(gzip.compress(raw, mtime=0))
    write_json(out / "captures" / "MANIFEST_RANGE_EVIDENCE.json", json.loads((src / "captures-manifests" / "RANGE_EVIDENCE.json").read_bytes()))

    data = dict(runID=44657116407, runURL="https://github.com/davidpovarsky/Maktabah/actions/runs/44657116407", jobID=136025963076, checkoutSHA=review["checkout_sha"], applicationSHA=review["application_sha"], testSourceSHA=runtime["test_source_commit"], testTree=runtime["test_tree"], applicationTrees=build["application_trees"], originalArtifact=verified, capturesArtifactID=14605489369, capturesFullArchiveHashVerified=False, originalEntries=ledger, verifiedLeafCounts=review["counts"], phonePartialLogObservations=phone, newTestExecutionsByReview=0, generatedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat())
    write_json(out / "EVIDENCE_LEDGER.json", data)
    groups = "\n".join(f"| {g['label']} | {g['expected']} | {g['passed']} | {g['failed']} | {g['skipped']} | {g['not_run']} |" for g in review["groups"])
    failures = "\n".join(f"| `{c['case_id']}` | {str(c['failures'][0].get('text', ''))[:210].replace(chr(10), ' ').replace('|', '/')} |" for c in review["cases"] if c["result"] == "Failed")
    readme = f'''# Native88 — original run 44657116407

**The workflow failed. There are 70 finalized, independently reconciled iPad Test Case leaves: 46 passed, 24 failed, zero skipped. Eighteen selected phone cases have no finalized xcresult export.** The driver labels these eighteen `NOT_RUN`; that label must not be interpreted as proof they never executed. The original phone log records sixteen starts and fifteen terminal outcomes (seven `passed`, eight `failed`), one interrupted case, and two selected cases without a start. Those partial log observations are retained separately and are not promoted to verified leaf results.

Run: https://github.com/davidpovarsky/Maktabah/actions/runs/44657116407

| Provenance | Exact source |
|---|---|
| Workflow checkout | `{review['checkout_sha']}` |
| Application and test source | `{review['application_sha']}` |
| Original selected manifest | 88 cases: 70 iPad and 18 iPhone |
| Manifest SHA-256 | `{review['manifest_sha256']}` |
| Complete evidence artifact | 14606041723; {verified['bytes']:,} bytes |
| Verified complete artifact SHA-256 | `{verified['actualSHA256']}` |
| Separate captures artifact | 14605489369; 2,169,151,077 bytes; selected HTTP206 ranges only |

The original runtime report records an outer `run-faithful-ipad-matrix.py` timeout after **12,600 seconds**. The final phone log stops while `testNormalBootstrapGlobalHistoryUsesActualSubmit` is relaunching. The two no-start observations are `testNormalBootstrapLegacyGenesisAndRotation` and `testNormalBootstrapOtzariaBackgroundAndColdRestoration`. This is not an eighteen-case phone setup failure. The workflow Native step failed at06:01:29UTC; artifact retention completed and the workflow concluded failure at06:06:18UTC. The sole finite watcher ended naturally at06:06:41UTC. No GitHub workflow was cancelled by this review.

## Finalized leaf reconciliation

| Original group | Selected | Passed | Failed | Skipped | No finalized leaves |
|---|---:|---:|---:|---:|---:|
{groups}

`VERIFIED_CASES.json` compares each named Test Case leaf with its original group summary, the original requested88 manifest, and the driver's named outcomes. There are **zero provenance or count discrepancies**. Its `not_run:18` field is preserved exactly as the existing evidence verifier classifies missing exports; `PHONE_PARTIAL_LOG_OBSERVATION.json` supplies the necessary actual execution distinction. No per-assertion counter exists. No source test was executed by this review.

## Concrete new failures and source boundaries

- Core search.openResults fails before app launch because `GLOBAL_SEARCH_TEST_QUERY` is absent. The original group11 oracle explicitly records `search_query_source_evidence:null`; the partial phone log shows the same missing variable. The Core/engine action was not reached in either case.
- Profile color fails because the unspecific Hebrew Edit selector matches both the profile navigation bar and the profile action menu. The original AX tree and screenshot are retained. This does not prove a color transaction or persistence failure.
- Notes reaches the production Core outcome and reports `cancelled`, not `completed`. The actual outcome JSON and final AX are retained; the success/draft/cancel/store assertions after that failing point were not reached.
- Commentary fails the independent TextKit/source-locator precondition after opening its public source URL, before triggering Core.openCommentary. It is not evidence that the commentary action ran and failed.
- The restored original global-history-submit case fails to find exactly one submitted history row. The original query and UI evidence remain intact; the oracle was not loosened.
- The two real window/HID cases again fail to find `reader-study-toggle` after the actual compact-window and palette/HID interactions. Currentb07 still contains that exact test selector; diagnosis and any repair are separate work.

## Comparison with Native78 and current source

Of the prior thirteen failures, the iPad History URL after background case now has an actual passing leaf on7e. Ten prior iPad failures recur. The two prior phone failures have no finalized88 leaves; both have failing terminal observations in the partial phone log. The full per-case comparison is `NATIVE78_COMPARISON.json`.

Later sourceb07 includes Inspector witness8457e48f, background intent metadata39ba01a0, Library/TOC polling46c702b9, current book-search/header4fee5615, native wait/tab-returnf94e830d/9642de60 and ACK diagnosticsce39223a. These source changes are potential resolutions for their scoped failures, **not Native PASS**. The separate92-case run must establish its own outcome. The source defects newly demonstrated here are assigned separately; no source, oracle, runtime timeout, manifest or capability was changed by this evidence package.

## All24 finalized failures

| Original case | Original failing assertion/message (short excerpt) |
|---|---|
{failures}

## Evidence reproduction and preservation

Run `review-native-evidence.py` with the original ZIP and `original-R27_CASES.json`, supplying the exact source/digest above. It reads original results only. `EVIDENCE_LEDGER.json` records raw entry lengths and SHA-256; each retained original entry is a deterministic gzip whose decompressed bytes must match those values. The complete phone log and matrix driver are included losslessly. All24 failing activity spans are retained in `failure-timelines/`.

The separate captures ZIP was not fully downloaded or hash-verified. `captures/RANGE_EVIDENCE.json` records its GitHub-advertised digest, exact validated HTTP206 ranges, and selected-entry CRC/SHA values. Original compressed ranges are retained so selected PNG data can be reconstructed without claiming a full-archive digest. Selected original AX/result JSON and manifests are preserved losslessly as gzip. Signed artifact URLs and GitHub credentials are never stored in this package.

The earlier watcher finite timeout is a watcher observation, not a failed workflow result. Native92 and later repaired sources remain distinct; no prior-source success is transferred to them. Physical-device acceptance, Release acceptance, the new d5 occurrence feature and current source readiness are not established by this old265-engine Native88 run.
'''
    (out / "README.md").write_bytes(readme.encode())
    manifest = []
    for p in sorted(out.rglob("*")):
        if p.is_file():
            b = p.read_bytes()
            manifest.append(dict(path=p.relative_to(out).as_posix(), bytes=len(b), sha256=sha(b)))
    write_json(out / "PACKAGE_MANIFEST.json", dict(files=manifest, count=len(manifest), totalBytes=sum(x["bytes"] for x in manifest)))
    print(json.dumps(dict(output=str(out), files=len(manifest)+1, bytes=sum(x["bytes"] for x in manifest), originalEntries=len(ledger), failedTimelines=len(timelines), packageManifestSHA256=sha((out / "PACKAGE_MANIFEST.json").read_bytes()))))


if __name__ == "__main__":
    main()
