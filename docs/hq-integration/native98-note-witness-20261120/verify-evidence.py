#!/usr/bin/env python3
"""Verify sealed evidence and exact candidate source. No Swift/Native execution."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import subprocess

def digest(data):
    return hashlib.sha256(data).hexdigest()

def once(text, old, new):
    assert text.count(old) == 1, "inverse anchor missing or ambiguous"
    return text.replace(old, new, 1)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[3])
    args = parser.parse_args()
    directory = Path(__file__).resolve().parent
    manifest = json.loads((directory / "ARTIFACTS.json").read_text(encoding="utf-8"))
    review = json.loads((directory / "REVIEW.json").read_text(encoding="utf-8"))
    for entry in manifest["files"]:
        path = directory / entry["path"]
        data = path.read_bytes()
        if entry.get("canonicalLF"):
            data = data.replace(b"\r\n", b"\n")
        assert len(data) == entry["bytes"] and digest(data) == entry["sha256"], entry["path"]
        if "uncompressedSHA256" in entry:
            raw = gzip.decompress(data)
            assert len(raw) == entry["uncompressedBytes"]
            assert digest(raw) == entry["uncompressedSHA256"]
    current = {}
    for item in review["sourceInputs"]:
        path = item["path"]
        value = (args.repo / path).read_bytes().replace(b"\r\n", b"\n")
        assert digest(value) == item["candidateSHA256"], path
        base = subprocess.check_output(["git", "show", review["baseCommit"] + ":" + path], cwd=args.repo)
        assert digest(base) == item["baseSHA256"], path
        current[Path(path).name] = (value.decode(), base.decode())
    text, original = current["iOSAnnotationEditorSheet.swift"]
    text = once(text, """    // Host-owned visibility observation mounts on the actual editor Form.
    // The editor's default presentation, editing and persistence remain unchanged.
    var nativeSurface: (@MainActor () -> AnyView)? = nil
""", "")
    text = once(text, "            .background { nativeSurface?() }\n", "")
    assert text == original
    text, original = current["iOSReaderWorkspaceView.swift"]
    text = once(text, """                },
                nativeSurface: {
                    AnyView(Color.clear.modifier(MaktabahNativeRoutingSurface(kind: .noteDraft,
                        noteReader: viewModel, noteDraft: editingAnnotation)))
                }
            )
""", """                }
            )
            .modifier(MaktabahNativeRoutingSurface(kind: .noteDraft,
                noteReader: viewModel, noteDraft: editingAnnotation))
""")
    assert text == original
    text, original = current["NativeSurfaceWitness.swift"]
    text = once(text, """    public func makeUIViewController(context: Context) -> MarkerController {
        #if DEBUG
        diagnose("lifecycle=make")
        #endif
        return MarkerController()
    }
""", "    public func makeUIViewController(context: Context) -> MarkerController { MarkerController() }\n")
    text = once(text, """        #if DEBUG
        diagnose("lifecycle=update registered=1")
        #endif
""", "")
    assert text == original
    validation = json.loads(gzip.decompress((directory / "raw/NOTE_PLACEMENT_SOURCE_VALIDATION.json.gz").read_bytes()))
    assert validation["runtimeTestsExecuted"] == 0
    assert validation["AppleTypecheck"] == validation["Native"] == "NOT_RUN"
    assert len(validation["syntaxParses"]) == 3
    for item in validation["syntaxParses"]:
        assert item["returncode"] == 0
        assert "-parse" in item["command"] and "-D" in item["command"] and "DEBUG" in item["command"]
        assert item["diagnostics"].count("warning:") == 2
        assert digest((args.repo / item["path"]).read_bytes().replace(b"\r\n", b"\n")) == item["sourceSHA256"]
    result = json.loads(gzip.decompress((directory / "raw/C8D50A54-15CE-47C2-A308-A5DFC50C1A59.json.gz").read_bytes()))
    assert result["coreResult"]["status"] == "cancelled"
    assert result["coreResult"]["error"]["code"] == "deadline_exceeded"
    assert result["originalUnsavedEditor"] and result["originalEditorOwnsProposal"] and result["originalStoreUnchanged"]
    print(json.dumps({"status": "PASS_SOURCE_EVIDENCE_ONLY", "artifactFiles": len(manifest["files"]),
        "sourceInputs": len(current), "exactSourceInverses": 3, "retainedSyntaxParses": 3,
        "runtimeTestsExecuted": 0, "AppleTypecheck": "NOT_RUN", "Native": "NOT_RUN"}, sort_keys=True))

if __name__ == "__main__":
    main()
