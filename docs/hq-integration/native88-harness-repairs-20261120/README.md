# Native88: demonstrated harness inputs, Profile selector and outer UI budget

## Actual failure provenance

Native88 run 44657116407 checked out fe4df7c39aec242d00046bc454c81963ba4285a0, application 7e777509d486a17bec5b4bd437a9ac7f51d3a43a. Its preserved evidence is in commit 982793cbdc14aa910a8b164ab1a4956b7d8e775f, docs/hq-integration/native88-44657116407-20261120. No result below changes that failed run.

## Core Search environment

The original native matrix enabled the authenticated search-query oracle only when selecting GlobalSearchNativeAcceptanceTests. The real Core Search Pad and Phone cases belong to different execution groups; both actually failed while unwrapping GLOBAL_SEARCH_TEST_QUERY, before application launch. The correction includes only the two exact Core Search case families in the existing include_search condition. The oracle implementation, candidate source file, native fixture contract, engine behavior and every XCTest assertion remain unchanged.

Tests/HQ/native88/verify-core-query-environment.py executes the actual matrix AST environment statement and actual original oracle, against the original authenticated miniTest10 SQLite database (15,470,592 bytes, SHA256 d3d9bfcc2320a987a0391ad23fa72abcf6fd1fa0f3cba95adc05096e05a9edef). It uses an explicitly synthetic installation receipt and an owned simulator-shaped temporary directory. It does not install or run a simulator, execute an engine, grant a Core permission, or constitute Native acceptance.

Actual baseline: 2 PASS / 2 FAIL; only groups 11 and phone lack the required source-authenticated queries. Actual corrected candidate: 4 PASS / 0 FAIL, including unchanged positive 11-search and negative 11-reader controls. Both original and temporary database hashes remain unchanged. All seven original fixture-oracle tests also passed.

The first driver attempt failed while deleting its own current temporary working directory on Windows; no completed RESULT was produced and that attempt is not counted as the baseline. Its raw traceback is retained. Restoring the previous working directory before temporary cleanup corrected only the driver; subsequent baseline and candidate reports are complete.

## Profile Color menu

The actual failing AX exposes two buttons labeled עריכה: the navigation-bar reordering EditButton and the selected profile's original menu action under CollectionView/Cell, with identifier pencil. The selector now requires that original menu hierarchy, identifier and label, waits for its existence, and requires exactly one match before using the existing native tap helper. Static review of the actual AX yields old 2 / new 1 matches; it is not an executed tap result. Every Save/Cancel/color/UUID/other-profile/group/scene/cold-launch/default-field assertion is byte-preserved. An exact inverse restores the original source.

Windows Swift frontend syntax parse completed exit 0, with the two Windows SDK mismatch warnings retained. This is not an Apple typecheck or Native run.

## UI orchestration budget

Native88 was actually interrupted by its outer 12,600-second matrix wrapper; 18 final iPhone results were left unverified. The UI wrapper now allows 16,200 seconds and its hosted job 360 minutes instead of 300. Every individual XCTest retains its existing 600-second default/maximum, with no retries, selector removals, oracle relaxations or result substitution. Probe remains 300 minutes. Existing process-group cleanup remains unchanged.

Release remains 360 minutes and its current wrapper is unchanged in this commit: its UI and production stages need a separate orchestration change because xcode-27 is GitHub-hosted. No Release completion is claimed here.

## Integration boundary

Base f064b5517f560e2b52838bf321214baa3fb09e2c. These changes require combined-source manifest/hash freezing together with the compact-window, Commentary, Notes diagnostics and package-floor fixes before dispatch. No Native results on this source yet. GlobalHistory and Notes remain separately unresolved.

Raw evidence is gzip-preserved with hashes in RAW_MANIFEST.json. No original database, SDK, index, engine or production UI was modified by this commit.
