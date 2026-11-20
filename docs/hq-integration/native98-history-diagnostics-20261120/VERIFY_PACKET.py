#!/usr/bin/env python3
"""Verify source preservation only; never a Swift/Apple/Native execution claim."""
from pathlib import Path
import gzip
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parent

def blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()

def unpack(name):
    return gzip.decompress((ROOT / "raw" / (name + ".gz")).read_bytes())

comparison = json.loads((ROOT / "SOURCE_COMPARISON.json").read_text())
checks = []
sources = {}
for name, path, changes_file in [
    ("Faithful", "Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift", "CHANGE_MAP.json"),
    ("R27", "Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift", "R27_CHANGE_MAP.json"),
]:
    before = unpack(name + ".baseline.swift")
    after = unpack(name + ".candidate.swift")
    proof = comparison["files"][path]
    for label, data in [("base", before), ("candidate", after)]:
        assert len(data) == proof[label + "Bytes"]
        assert blob(data) == proof[label + "GitBlob"]
        assert hashlib.sha256(data).hexdigest() == proof[label + "SHA256"]
    changes = json.loads((ROOT / changes_file).read_text())
    rebuilt = before.decode()
    for change in changes:
        assert rebuilt.count(change["old"]) == 1, change["name"]
        rebuilt = rebuilt.replace(change["old"], change["new"])
    assert rebuilt.encode() == after
    for change in reversed(changes):
        assert rebuilt.count(change["new"]) == 1, change["name"]
        rebuilt = rebuilt.replace(change["new"], change["old"])
    assert rebuilt.encode() == before
    assert re.findall(r"\bfunc (test[A-Za-z0-9_]+)\s*\(", before.decode()) == re.findall(
        r"\bfunc (test[A-Za-z0-9_]+)\s*\(", after.decode())
    sources[name] = (before.decode(), after.decode())
    checks.append(name + ": hashes, exact forward/inverse and existing case declarations")

before, after = sources["Faithful"]
def block(source, begin, end):
    assert source.count(begin) == 1 and source.count(end) == 1
    return source.split(begin, 1)[1].split(end, 1)[0]

history_before = block(before, "    func exerciseGlobalHistorySubmission(enabled: Bool) -> String {", "\nfinal class FaithfulReaderVisualBaselineTests:")
history_after = block(after, "    func exerciseGlobalHistorySubmission(enabled: Bool) -> String {", "\nfinal class FaithfulReaderVisualBaselineTests:")
assert block(history_before, "        let settled = XCTNSPredicateExpectation", "        let beforeTermination = historyObservation()") == block(
    history_after, "        let settled = XCTNSPredicateExpectation", "        let beforeTermination = historyObservation()")
assert block(history_before, "        let historyNamespace = workspaceNamespace", "        let settled = XCTNSPredicateExpectation") == block(
    history_after, "        let historyNamespace = workspaceNamespace", "        let settled = XCTNSPredicateExpectation")
assert block(history_before, "        XCTAssertEqual(settledResult, .completed,", "        return query\n    }\n}") == block(
    history_after, "        XCTAssertEqual(settledResult, .completed,", "        return query\n    }\n}")
assert "forKeys: [.isRegularFileKey, .isSymbolicLinkKey]" in after
assert ".fileSizeKey" not in block(after, "private func observeNativeGlobalHistoryFile", "/// Existing DEBUG provider/publication")
assert "while bytes.count <= maximum" in after
assert "read(upToCount: min(65536, maximum + 1 - bytes.count))" in after
assert after.count("recordsGlobalHistoryTrace = true") == 1
assert after.count("recordsGlobalHistoryTrace = false") == 1
assert after.count("defer { recordsGlobalHistoryTrace = previousTrace }") == 1
assert after.count("originalPassiveSearchTrace") == 1
assert "digest.utf8.count == 64" in after
assert "historyWriterOwnerObservation\": \"NOT_EXPOSED_BY_EXISTING_PASSIVE_CHANNEL" in after
checks.append("Unchanged namespace/Return, 90s settlement, persistence, cold relaunch and final UI oracles")
checks.append("Original bounded regular/non-symlink file admission; trace opt-in and metadata-only attachment scope")

rbefore, rafter = sources["R27"]
assert rbefore.count("readerAdditionalLaunchArguments") == 0
assert rafter.count("readerAdditionalLaunchArguments") == 1
assert rafter.replace(" + readerAdditionalLaunchArguments,", ",") == rbefore
checks.append("R27 single argument append; empty default preserves existing arguments and ordering")

bound = json.loads((ROOT / "READ_ONLY_INPUTS.json").read_text())
for entry in bound:
    data = unpack(entry["name"])
    assert blob(data) == entry["gitBlob"]
    assert len(data) == entry["bytes"]
    assert hashlib.sha256(data).hexdigest() == entry["sha256"]
trace = unpack("UnifiedSearchSessionController.swift").decode()
assert 'UserDefaults.standard.bool(forKey: "GlobalSearchNativeTraceEnabled")' in trace
assert 'OtzariaDataProfileRegistry.activeProfileID == "miniTest10"' in trace
assert 'UUID(uuidString: value) != nil' in trace
assert 'record["sessionID"] = nativeSearchObservationID.uuidString' in trace
checks.append("Exact existing DEBUG trace and original SDK route input blobs")

index = ROOT / "PACKET_INDEX.json"
if index.is_file():
    for entry in json.loads(index.read_text())["files"]:
        data = (ROOT / entry["path"]).read_bytes()
        assert len(data) == entry["bytes"]
        assert hashlib.sha256(data).hexdigest() == entry["sha256"]
        assert blob(data) == entry["gitBlob"]

print(json.dumps({"status": "SOURCE_PRESERVATION_VERIFIED", "checks": checks,
    "SwiftParse": "NOT_RUN", "AppleTypecheck": "NOT_RUN", "Native": "NOT_RUN",
    "testCasesExecuted": 0}, indent=2))
