# Build11201 integration evidence

Current stage: five repair lanes composed; the real unsigned arm64 Maktabah-iOS app build passed at exact checkout `3918864d9e4d963fa8686aab48e53c34a933c771`. See [STAGE2_FINAL_REPORT.md](STAGE2_FINAL_REPORT.md) for executed source, generated dependency context, results and remaining runtime/device gates. Application source is `07d1cafa6c6bc27aaf299aa826d28a4c02090cb5`; subsequent validator/documentation commits must not be mistaken for the executed checkout.

The original registration-only handoff below is historical and superseded by the owner-authorized stage2 composition and actual Apple execution.

## Historical registration-only handoff

[תומר | INT] [MAIN_SESSION] — 2026-11-15

This branch supplies only the minimal Xcode membership patch for Source/ChavrusaText/BookUpdates/MaktabahBookUpdateSafety.swift in Maktabah, Maktabah-Direct and Maktabah-iOS. It does not contain the source file or other writers' repairs. Integrate only with Dana's corresponding Updates source/callers in an authorized coherent batch; do not build this branch alone as a repaired candidate.

Baseline: df2a21941afa46da716387fce9de620865d2a151. Pinned actual upstream: d46af139b3a265399c16d87f5923acd8e3444024. Exactly 8 project lines added; no existing project configuration changed. Search/Reader/Inspector/Sidebar confirmed no new application sources. All Tests/HQ fixture files stay outside app targets; UI tests remain prepared NOT_RUN.

See HOOK_AUDIT_20261115.md for necessity, exact objects, source path contract, provenance, tests, preserved legacy debt and rollback. project-registration.diff is the exact protected hook. source-registration-check.json is a read-only graph check against the separately delivered Updates tree; it explicitly records present_in_integration_tree=false. This is not a compiler or functional pass.

Executed focused checks:

- `py -3 docs/hq-integration/verify_source_registration.py --source Source/ChavrusaText/BookUpdates/MaktabahBookUpdateSafety.swift --source-root C:/Users/DAVID/Code/Maktabah-hq-updates-20261115`
- `py -3 Scripts/CI/verify-otzaria-xcode-project.py`
- `git diff --check`

No build, CI, merge, cherry-pick, push, workflows, lockfiles, signatures, release, TestFlight or user-data operations. Lead owns coherent integration authorization; Roni owns final acceptance review. Physical acceptance remains OPEN.
