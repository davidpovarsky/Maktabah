# Explicit preservation of historical focused-control sources

Fourteen historical source and proof files are preserved byte-for-byte in HISTORICAL_SOURCES.zip with complete original metadata. The eight current revision-3 source/proof files, original dispatcher, all test methods, protocol sources, output limits and the 4 MiB guard remain unchanged.

The preparation step only adds a verified archive, a strict source-storage resolver and receipts. Original raw files remain until a separate Root operation verifies a durable Git copy, rechecks exact bytes and identities, and records the precise retirement. The resolver refuses to operate while any of the fourteen raw paths still exists. It substitutes archive-backed reads only for these fourteen exact absolute paths; every other read delegates to the unchanged dispatcher. The original source seal and all SEALED rechecks still verify the same source bytes.

This storage change is necessary because three completed phases occupy 4,009,984 bytes and the final Mac phase plus its unchanged allocation guard would exceed 4 MiB by 32,768 bytes. Existing output is preserved. No test, guard or output allowance is weakened. The earlier measurement's reporting-only base64 return refusal was not a test or protocol failure; its corrected numeric measurement produced an in-memory 87,711-byte ZIP. This preparation captures fresh metadata and binds its own archive hash.

Mac baseline: two intended defects reproduced, with one assertion failure and one NameError. Oracle candidate: 11 PASS. Omission counterfactual: one intended 57 != 70 failure. Candidate17, closure, real Native116 and release qualification remain pending at preparation time.
