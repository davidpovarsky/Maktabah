# Original SQLite complete-note preservation gate

Status: **NOT RUN**. The reviewed product is `ce0f62baba7360514e7fa8cad21f0caaf2d0ab8f`.
This new focused component gate supplements the unchanged original 43 Save tests and
unchanged 36 conditional-revision assertions, which must execute separately against
the same expanded original product closure. Historical passed and storage-blocked
receipts retain their actual original inputs and scope.

The driver compiles the complete original 25-file closure (except its old executable)
and the complete original Actions package. It extracts the byte-identical original
LocalFixture prefix and adds this new executable. It never substitutes product
implementations. Catalog/UI/CloudKit callback doubles remain explicitly those of the
original fixture. The rich-body fixture is opaque component data, not Anytype output.

The 23 declared cases verify exact UTF-8 retention beyond 8192 bytes; original metadata,
tags and CloudKit identity; bounded preview/body/source/queue atomicity; short-note
identity, malformed previews, existing rich-body refusal, concurrent note/tag/deletion,
forged captured text, policy substitution and cross-policy replay, an actual SQLite
UPDATE followed by denied version INSERT and rollback, idempotency, retirement,
reconnection, normal Save behavior after conversion, and cancellation with no writes.

Two distinct executable processes additionally commit and cold-reopen one long mixed
Hebrew/English/emoji note. An independent read-only Python SQLite verifier checks
integrity, the full raw UTF-8 note bytes and hash, timestamp, exact immutable payload,
preview, body, head, tags, original pending upload/unrelated delete, and zero remote
outbox/ACK. The iOS closed SDK capture, actual native Backfill, app relaunch and UI
remain separate acceptance obligations; none is represented by these component cases.

Use the owner's existing Apple arm64 runner only, a fresh evidence directory and the
storage owner's current remaining-growth/OS plan. The driver admits at most 1 GiB of
new compile output, then 128 MiB of remaining fixtures; it can stop only its own
process group if the recorded reserve is consumed. Preserve all raw attempts.

```sh
python3 tools/hq-annotation-long-note-acceptance.py \\
  --artifacts-dir /Users/m1/builds/OWNED-EXACT-ATTEMPT \\
  --anticipated-concurrent-growth-gib CURRENT_APPROVED_GROWTH \\
  --os-margin-gib CURRENT_APPROVED_OS_MARGIN
```
