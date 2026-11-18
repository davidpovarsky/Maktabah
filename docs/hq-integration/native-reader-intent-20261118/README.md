# Original source sections and system Reader intent — 2026-11-18

Status: SOURCE_WIRED; actual Apple SDK and Native acceptance pending for this source.
Solo owner-authorized continuation. No original task is completed by this report.

## Original Core and source TOC
The existing ActionBackendCoordinatorFacade previously accepted only explicit
numerical Otzaria section inputs. It now obtains the selected catalog work's actual
BackendCoordinator.tableOfContents and sends the original locators/titles to the
same CatalogActionResolver. Matching uses the existing NFC/whitespace/quote
normalization. It does not convert chapter numbers, manufacture locators or pick
the first duplicate title. Unknown names stay not-found; multiple actual locators
stay ambiguous. The enclosing resolver still proves each locator against the
original source. Work/backend/revision mismatches, oversized input, cancellation
and stale generation are refused. Matching runs outside MainActor.

The original numerical-line contract is retained. On the independently read-only
miniTest10 v6 DB, TOC entry2 is book1 / title פרק א / source line2 / lineIndex1.
The sealed original Reader oracle already contains that exact source line.

## System integration
NativeBookEntity and NativeBookLocationEntity use versioned, canonical,
backend-qualified source identifiers. They contain no scene/permission/grant.
Their queries call the existing ActionExecutor catalog actions. All returned
ambiguity remains a list of system entities. Stored IDs are resolved again before
navigation; absent source, wrong book, backend change and stale metadata fail.

OpenBookAtLocationIntent asks for a book, source chapter/passage, existing Library
window and new-tab choice. The location query depends on the selected book through
Apple IntentParameterDependency. The existing app process installs its dependency.
The host rechecks the exact source snapshot (including RPC epoch), resolves R's
original bounded section/focus, then uses the original public-v2 binder,
SceneNavigationOrchestrator, Core reader.open and original retained Reader owner.
It never selects the first available window or creates a new permission mechanism.

The original root intent/shortcut and WidgetKit code are retained. The curated
book shortcut points to this actual source-wired intent. Unknown readiness is
reported as unavailable rather than zero entities.

## Verification and boundaries
- Core: 67 Swift6 strict-concurrency XCTest methods PASS, 0 failures.
  Includes 6 new conservative TOC/source matching regressions.
- Native host package: 110 Swift6 strict-concurrency XCTest methods PASS, 0 failures.
  Includes 10 new entity identity/Core projection/stale source/cancellation tests.
- Actual app BackendCoordinator, models, protocols, facade, RPC bridge and runtime
  integration harness: 106 assertions PASS with explicit provider/transport doubles.
  This is not an installed DB, Hermes or Native UI execution.
- The first cold Windows Core build exceeded its 240-second wrapper limit; no
  compiler error was observed. The incremental build finished and all67 tests ran.
- The first integration compile caught a duplicate local fixture variable; renamed
  only the new local variable and reran successfully. No assertion was removed.
- Five new actual Apple system UI cases are selected, all NOT_RUN: named chapter;
  cached source/background; wrong-book refusal; nonexistent-source refusal; phone.
  Positive cases require independent source text/locator, exact original tab,
  canonical native receipt and return to the preserved original Reader.
- Matrix65 retains all27 original cases unchanged, 54iPad +11iPhone.
- Native60 run44335820129 is pinned to prior07b/8e35. It cannot accept this change.
- Full corpus, voice Siri/Spotlight, physical device, source commentary/notes/search
  workflows, Hanlin acceptance and release gates remain open. No TestFlight upload.

Apple API references reviewed:
https://developer.apple.com/documentation/appintents/intentparameterdependency
https://developer.apple.com/documentation/appintents/entitystringquery
https://developer.apple.com/documentation/appintentstesting/testing-your-app-intents-code
https://developer.apple.com/documentation/appintentstesting/appentitydefinition/entities(matching:)
