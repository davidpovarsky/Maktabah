# Synchronized test-target membership correction

This docs-only follow-up corrects an integration instruction in historical
be3ed07f476de5127bab2a70da5d32086d9a30d2. That packet incorrectly requested a
manual Sources-phase entry for NativeReaderTabAcceptanceTests.swift.

The actual aa5092cd and da1dccc6 project files already attach the
Maktabah-iOSUITests PBXFileSystemSynchronizedRootGroup to the existing UI-test
target through fileSystemSynchronizedGroups. The group has no explicit children
or exception field. Its Sources phase is intentionally empty, and the original
NativeRouting/NativeHistory files likewise have no manual project entries.

The new Swift file inherits synchronized inclusion from its existing directory.
**No PBX change or duplicate manual membership is required.** Actual Apple
source discovery, compilation and native execution remain NOT_RUN.

PROJECT_MEMBERSHIP_PROOF.json records exact source commits, complete project
file hashes, object IDs and original block bytes. MEMBERSHIP.json and README
are corrected accordingly. The original be3 documentation remains preserved
in Git; both native test files remain byte-exact at source f5428b47. No
validation result has been rerun, relabelled or upgraded by this correction.
