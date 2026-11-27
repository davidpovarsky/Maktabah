# F07 — actual AnnotationStore / Repository / SQLite controls

## Observed result

Scaleway Apple run on 2026-11-27 00:24:34–00:25:00 UTC: **9 PASS, 0 FAIL, 0 SKIP**, 30 actual add/edit/delete/tag cycles and 30 persisted rows verified in two separate cold processes. Compiler and all three executable invocations exited 0. This checkpoint adds acceptance controls and evidence; it changes no application product source.

Original application source checkout: `fc782370dcf33d92f4ccf2585a39c86be560898b`. The two new controls were uncommitted during execution and are identified by exact SHA in `SOURCE_BINDING.json`; the final commit preserves those bytes. The complete original compilation closure and action package were transferred with exact before/after hashes, not rewritten implementations.

- Original Mac root: `/Users/m1/builds/otzaria-wave2-f07-20261127/attempt-1`.
- RESULT SHA256: `79e2c2abd6a498fdee7edbd5659175a9c6547a6d4cadcbaa88b199772924ac37`.
- Source archive SHA256: `6fd9df14e71370fe1c085ce75007f4fa8463458cfa2ee89fbdc21e66d3955258`.
- Swift control SHA256: `baf936cc52a4a3438e18e2e526afbab693431f439fa7187f6c590ac0a5f6752f`.
- Python controller SHA256: `cc8688092c0d217211b04dc4dc5b1dd8676d0827bf738ceafc663010dc0cbaf8`.
- Apple Swift 6.4 / Xcode 27.0 / arm64 macOS, strict Swift 6 concurrency.

## What actually executed

| Control | Observed requirement |
| --- | --- |
| 30 original Store CRUD/tag cycles | SQL body/tags, Store cache, atomic upload/delete queue and unused-tag cleanup |
| Nested savepoint rollback | Two outer records/queues retained; failed inner record absent |
| Outer rollback after nested commit | Notes, tags, relations and pending queue exactly equal their initial snapshot |
| Throwing real row mapper | Original cached statement resets and subsequent original Store update commits |
| Queue failure during add | Actual owned SQLite trigger raises an error; every persistent table/cache remains unchanged |
| Queue failure during edit | Same actual failure and complete rollback |
| Queue failure during delete | Same actual failure and complete rollback |
| WAL reader held across Store update | Existing read snapshot remains stable; next snapshot sees the committed value |
| Save with independent relationship cursor | Original Store commits while a real, independently connected owned 2,000-row SQLite cursor remains open |

Cold writer PID48587 exited; cold reader PID48588 reopened the same actual SQLite files. Independent read-only Python SQLite verification found 30 annotations, 60 tag relations, 30 pending uploads and `quick_check=ok`. It checked exact note bodies, record IDs and stored backend values, not only row counts.

The original `AnnotationStore`, repository, SQLite transaction/cache and pending queue implementations are compiled whole. Existing explicit local test boundaries cover CloudKit scheduling, backend locator types and unused compression. Backend identities in this fixture are test values, not proof of actual canonical library references. The relationship cursor is an owned SQLite fixture, not the production relationships provider.

## Evidence boundaries and remaining acceptance

`native_ui_executed=0`, `app_relaunch_executed=0`, `cloudkit_transport_executed=0`, `full_production_relationship_provider_executed=false`. These results do not close the original F07 Sefaria/Otzaria native Notes workflows, real app cold restoration, CloudKit-disabled application acceptance, or saving during full-corpus Inspector loading. Those gates remain separate and open.

Historical simulated statement-lifecycle controls and earlier SQLite integration receipts remain unchanged and retain their original scope. This evidence does not upgrade them to UI acceptance.

The original JSON files are copied byte-for-byte. Logs are losslessly gzip-compressed; `attempt-1/TRANSFER.json` records original and stored hashes. The original Mac fixture files and executable remain retained. No other agent's files, simulators, caches or products were removed.

## Reproduction

Run the checked-in `tools/hq-f07-annotation-cycles.py` with a new owned `--artifacts-dir` on the Apple host and an exact `SOURCE_BINDING.json` produced from the stated original source closure. The controller refuses a pre-existing result directory, checks source bytes before/after, verifies every expected case and distinct cold process identity, and does not invoke an app or Simulator.
