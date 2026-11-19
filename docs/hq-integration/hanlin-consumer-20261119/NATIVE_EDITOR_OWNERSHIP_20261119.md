# Original native editor ownership in the Otzaria consumer

## Source and composition

This continuation advances the original Hanlin gitlink from
873607e45e021b40fe5b940c836d398c329f95c8 to
6d62957852ffcb428810b065b4252e5384f1374b. The latter is the immutable original
editor ownership correction, not a copied consumer patch. Its three consumed
package trees are identical to the independently observed published Hanlin
ab581ece28f7ec8120019e4c926d67cd99dfcff6 trees. All three Package.swift blobs
and the consumer's 17 resolved package pins are unchanged.

Only the existing OtzariaHanlinChatSession and OtzariaHanlinChatView composition
changes. The original native editor receives the current original session UUID,
an ephemeral draft-write revision, and the current exact draft through the
SDK's TextState callback. A render-time binding snapshot cannot stand in for
the current owner. Each original draft assignment advances the revision,
including a same-string clear and canonically equivalent but byte-distinct
Unicode text.

The native binding setter remains on the existing MainActor session. It checks
the same current scene/presentation owner before changing that session. Retained
callbacks from a closed or foreign presentation cannot update or checkpoint
another conversation. The callback has no suspension between validation and
mutation.

The existing draft observer still calls the same historyChanged method. There
is no new persistence writer, storage schema, history migration, parallel
composer, model, action engine, credential store, or source-content grant.
Existing send/clear, rollback, restore, revocation, IME/focus and native layout
paths remain unchanged. The history error-state correction from 2597de5c is
also retained.

## Source validation and limits

The original SDK editor file SHA-256 is
712ec4feed1d36ee8c2305f6562d74bad8d86c31abe67424dc44f5ad46e9f2d2.
The applied consumer integration proposal SHA-256 is
452e69dcf4f25c991c868aa38857805f44c454c30e3f4b20596078f76829440d.

Actual Swift 6.3.3 Observation macro inspection of the original proposed
property shows that its equal-value setter branch still assigns the backing
property; its didSet therefore advances the revision for equal String values
as well. This portable compiler inspection and source parsing are not Apple
application typechecking or execution.

The original complete Apple app/test build-for-testing gate must pass, then
both original UI cases must execute: durable draft/history across native close
and process restart, and reader-context chat close returning to the same
original reader and scene. Test bodies, identifiers, assertions, fixture
lineage and the broader original runtime27 catalog are unchanged. The source
pin alone does not establish UI acceptance.

The authenticated run 44474935357 at 373c9dbf / application 3609903e / SDK 873607
remains a full-build FAILURE with both UI cases NOT_RUN; see the adjacent
NATIVE_CONSUMER_COMPILE_20261119.md. No result from that run or from older
component runs is attributed to this corrected consumer source.

Anytype uses the original HanlinScriptUI TextField composer, so this
NativeMultilineTextEditor integration is specific to the actual Otzaria
consumer call site.
