# Direct Darwin Notify module import

Run45143450850 failed its actual Apple UI compilation before app build or tests:
notify_post and NOTIFY_STATUS_OK were not in scope despite import Darwin.
All10 selected native cases remain NOT_RUN; the three source admission steps
and original SDK selection passed. The authentic failure and artifact hashes
are retained here. No runtime result is inferred from source preparation.

Apple official module metadata identifies DarwinNotify, available on iOS/iPadOS
since9.3. The two affected files now import that module directly while retaining
Darwin for existing POSIX APIs. The existing Inspector DEBUG observer uses the
same notify_register_dispatch/notify_cancel API, so its direct import is included
before the first app build. There is no method, assertion, timing, source mapping
or notification behavior change. Removing exactly those two lines restores both
complete original files byte-for-byte. No redundant Linux parse or synthetic
native test was run; real Apple compilation remains required.

Base88977a1 is the published CI-only child of d6f3 with identical product trees.
This preserves the isolated original Groups1/Library7/full-v32two lineage and
excludes the later Host annotation budget composition. Existing CI/config pins
are unchanged in this source commit and will be rebound only after review.
