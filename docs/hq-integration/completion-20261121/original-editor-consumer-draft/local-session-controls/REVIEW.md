# Local editor source retirement controls

Six controls passed with the exact changed `AnnotationLocalEditorSession.swift`
and the exact original `AnnotationLocalEditorLifetime` implementation. The
production session file, including its original store factory and publication
extension, was compiled unchanged with Swift 6.3.3, `-swift-version 6 -j 1`.
The source manifest records all exact SHA256 inputs. Sentinel job
`job_0a06f3662766` compiled and executed successfully in 48.45 seconds.

The six cases exercise retirement before worker admission, retirement while a
worker is held before its currentness check, retirement after a committed result
exists but before its delivery, the original store extension's own
`treeInvalidated` publication, unchanged default current-session delivery, and
same-identity replacement failing to revive a previously retired owner.
The nonisolated `retire()` call was actually compiled and executed from
`Task.detached`, and both held cases use the actual session's detached save
worker and completion logic.

Persistence, repository, store-event delivery, payload types, and CloudKit are
explicit portable probes in `probes.swift`. The after-commit probe deliberately
returns its existing receipt after retirement. This establishes the session's
receipt/delivery behavior; it does not establish a real SQLite commit, rollback,
CloudKit delivery, Combine subscription, UIKit behavior, or Native acceptance.
The unchanged optional owned-cloud methods were compiled against probe types
but not executed. No Core194 or broad product test suite was rerun.

The source observation's new subscriptions and its exact bind-before-await
call sites were reviewed separately. The held-worker controls do not substitute
for their Apple/Combine compilation and Native qualification.
