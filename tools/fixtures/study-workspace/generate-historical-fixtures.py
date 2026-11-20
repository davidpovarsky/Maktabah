#!/usr/bin/env python3
"""Reproduce test JSON with the unmodified historical Codable declarations."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
DEST = Path(__file__).resolve().parent
SESSION_REV = "f092f3996927251d105dfb9243dfac487b196534"
WORKSPACE_REV = "bfc7f5a6aa849ab7e9a892cf63c693a8f49ac8a1"
SOURCES = [
    (SESSION_REV, "Source/LibraryBackend/LibraryBackendModels.swift", "/// A canonical reader destination:"),
    (SESSION_REV, "Source/ChavrusaText/Navigation/BackendSessionIntegrityRepair.swift", "// MARK: - Backend Session Integrity Repair"),
    (WORKSPACE_REV, "Source/ChavrusaText/StudyWorkspace/StudyWorkspaceModels.swift", None),
]
GENERATOR = r"""
import Foundation

@main
struct HistoricalSessionFixture {
    static func main() throws {
        let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let tabs: [iOSReaderTabSession] = (0..<10).map { index in
            let book = 17 + index % 3
            let locator = TextLocator(backend: .otzaria, workKey: "book:\(book)", position: .legacyLine(100 + index * 7))
            return iOSReaderTabSession(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!,
                bookId: book, bookTitle: "נתוני בדיקת מיגרציה \(book)",
                backendLocator: locator, contentId: 100 + index * 7, locator: locator,
                page: index + 1, part: index % 2 + 1,
                scrollPosition: CGPoint(x: 0, y: 120.5 + Double(index) * 50),
                selectedRange: NSRange(location: index * 3, length: index + 1),
                expandedNodeIDs: [1000 + index, 2000 + index],
                sidebarScrollPosition: CGPoint(x: 0, y: Double(index) * 10.25),
                isSidebarCollapsed: index.isMultiple(of: 2),
                searchText: "מילת בדיקה \(index)", searchModeRaw: index % 4,
                nearDistance: index + 2, highlightTerms: ["מילת", "בדיקה"])
        }
        let session = iOSReaderSession(
            savedAt: Date(timeIntervalSinceReferenceDate: 123456), activeTabId: tabs[6].id,
            selectedTabModeRaw: 0, tabs: tabs, backend: "otzaria")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(session).write(
            to: destination.appendingPathComponent("legacy-reader-session-v1.json"), options: .atomic)

        let personal = StudyProfile(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            name: "אישי", symbol: "person.crop.circle", order: 0)
        let other = StudyProfile(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            name: "פרופיל בדיקה נוסף", symbol: "star", order: 1)
        let group = StudyTabGroup(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
            profileID: personal.id, name: "כל הכרטיסיות", order: 0,
            tabs: tabs.map { ReaderDocumentTab(backend: .otzaria, session: $0) },
            activeTabID: tabs[6].id)
        let empty = StudyTabGroup(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
            profileID: other.id, name: "קבוצה ריקה", order: 0, tabs: [], activeTabID: nil)
        var workspace = StudyWorkspaceSnapshot()
        workspace.migratedLegacySession = true
        workspace.profiles = [personal, other]
        workspace.groups = [group, empty]
        workspace.scenes = [
            "fixture-window-a": .init(profileID: personal.id, groupID: group.id),
            "fixture-window-b": .init(profileID: other.id, groupID: empty.id)
        ]
        workspace.lastActiveSceneID = "fixture-window-a"
        try workspace.validate()
        try encoder.encode(workspace).write(
            to: destination.appendingPathComponent("legacy-study-workspace-v1.json"), options: .atomic)
    }
}
"""

def sha(value):
    return hashlib.sha256(value).hexdigest()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true", help="Explicitly replace only the two generated test fixtures and provenance.")
    args = parser.parse_args()
    evidence = {
        "schema_version": 1,
        "scope": "Constructed test identities encoded by exact historical production Codable declarations; not a user session, source existence proof, or native migration result.",
        "session_revision_before_study_workspace": SESSION_REV,
        "workspace_revision_before_optional_color": WORKSPACE_REV,
        "generator_sha256": sha(GENERATOR.encode("utf-8")),
        "sources": [],
        "fixtures": []
    }
    with tempfile.TemporaryDirectory(prefix="otzaria-historical-session-") as name:
        work = Path(name)
        source_paths = []
        for index, (revision, path, stop_marker) in enumerate(SOURCES):
            raw = subprocess.check_output(["git", "show", f"{revision}:{path}"], cwd=ROOT)
            source = raw.decode("utf-8")
            if stop_marker:
                assert source.count(stop_marker) == 1
                source = source.split(stop_marker, 1)[0]
            if path.endswith("StudyWorkspaceModels.swift"):
                assert "StudyProfileColor" not in source
            target = work / f"historical-{index}.swift"
            target.write_bytes(source.encode("utf-8"))
            source_paths.append(str(target))
            evidence["sources"].append({
                "revision": revision, "path": path,
                "git_blob": subprocess.check_output(["git", "rev-parse", f"{revision}:{path}"], cwd=ROOT, text=True).strip(),
                "full_git_bytes_sha256": sha(raw),
                "compiled_exact_prefix_sha256": sha(source.encode("utf-8")),
                "prefix_ends_before": stop_marker,
                "rewritten_declarations": False
            })
        main_file = work / "FixtureMain.swift"
        main_file.write_bytes(GENERATOR.encode("utf-8"))
        executable = work / "historical-fixture.exe"
        compile_result = subprocess.run(
            ["swiftc", "-parse-as-library", *source_paths, str(main_file), "-o", str(executable)],
            cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if compile_result.returncode:
            raise RuntimeError(compile_result.stdout.decode("utf-8", "replace"))
        subprocess.run([str(executable), str(work)], cwd=ROOT, check=True)
        for filename in ["legacy-reader-session-v1.json", "legacy-study-workspace-v1.json"]:
            generated = (work / filename).read_bytes()
            if args.write:
                (DEST / filename).write_bytes(generated)
            else:
                assert (DEST / filename).read_bytes() == generated, f"Historical fixture differs: {filename}"
            evidence["fixtures"].append({"path": filename, "bytes": len(generated), "sha256": sha(generated)})
        evidence["compiler"] = subprocess.check_output(["swiftc", "--version"], cwd=ROOT, text=True).strip()
        evidence["result"] = "PASS"
        evidence["mode"] = "write" if args.write else "verify_existing_bytes"
        if args.write:
            (DEST / "provenance.json").write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(evidence, ensure_ascii=True))

if __name__ == "__main__":
    main()
