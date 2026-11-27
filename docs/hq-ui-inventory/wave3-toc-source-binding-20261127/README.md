# TOC and Library source invalidation follow-up

Base: 1557749e0587b7e895e7d22c7c43486a9f44bd28.
The published initial 94e5b08c delivery and its evidence remain unchanged.

This narrow follow-up changes only the two downstream component adapters.
It creates one MaktabahNativeComponentSourceObservation before scalar/graph
snapshot reads. The retained validator checks that one-shot latch first, then
performs every previous exact original owner, backend, graph and filter check.
An observed change permanently invalidates the capture even after A-to-B-to-A.
There is no Task, refreshed source, new grant, rearm, setter or feature action.

The shared app-layer wrapper belongs to ui_acceptance. It owns the actual
BackendCoordinator.objectWillChange subscription, retained lifetime and
coordinator identity/backend/generation/transition validation. This source
depends on that same init(read:)/validate() API; it does not implement a duplicate.

SOURCE_READ_SET.json records each read and hashes the original declarations.
Manager and all three relevant models use Observation; their MainActor
isolation is direct or inherited from ViewModelBase. BackendCoordinator uses
Combine, not Observation. TOCNode's mutable children/locator/end fields and
ReaderViewModel's ignored lazy TOC slot are not falsely described as observed:
the existing exact model and full TOC node snapshots remain necessary.

The original TOC/Library views, shared registry/Session, catalogs, project,
owner signatures and native test selectors are unchanged by this follow-up.
Current-selected-row reveal remains a separate bounded layout implementation.

## Verification scope

The receipt records actual portable Swift syntax parsing and exact preservation
of the previous capture body outside these additions. It is not Apple typecheck,
native UI, source replacement acceptance, VoiceOver, HID or physical acceptance.
The shared helper's portable behavior tests belong to its own exact source and
receipt; the integrated original app must exercise these adapters before
source-bound native acceptance can be claimed.
