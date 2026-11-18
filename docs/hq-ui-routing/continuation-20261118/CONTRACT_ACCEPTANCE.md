# UI02 — current G1 source contract acceptance

Decision: COMPLETE_G1_SOURCE_CONTRACT. This closes the versioned contract, codec, registry and port milestone described by UI02. UI03–06, the ActionCore product task and Native/device/release acceptance remain open.

Source: 37c0cd00dfadfdbf2e390a0fd0b3498fda138398. Sole developer self-review under the owner's current solo instruction; no independent review or resumed earlier agent is claimed.

## Evidence

- Actual current UIRouting package:85 unique XCTest methods,0 failures, Swift6 strict-concurrency complete on Windows.
- Actual current ActionCore package:61 unique XCTest methods,0 failures. The counts describe different packages and are not Native UI counts.
- All67 tracked package inputs were hashed before/after execution and matched the same Git objects recorded by successful full Apple app run44219501471 (eed8a2b6 / app source d2bc52b9). The package source also has an empty diff from SDK run44214655208 at8001f9ee. These Apple compile results retain their exact checkout attribution.
- Complete named methods, source/Git/log hashes and golden fixture identities are in CONTRACT_ACCEPTANCE.json. Original raw outputs remain in the canonical continuation evidence folder.

## Contract and acceptance map

1. Versioned Codable/Sendable IDs, route, state, focus, presentation, scene and exact Core refs.

   Sources: Contracts/RouteSpec.swift, Contracts/PublicNavigationV2.swift, Codec/UIRouteSchemas.swift. Tested by GoldenAPITests.testGoldenPrivateAndPublicDTOs, GoldenAPITests.testIDsAndSendableContracts, RegistryTests.testCompleteStateAndBoundedSelection.

2. Stable goldens, explicit migration, removed/renamed route and unknown-version rejection.

   Sources: Codec/UIRouteCodec.swift, Codec/PublicNavigationV2Codec.swift. Tested by CodecTests.testPrivateAndPublicGoldenCodecs, CodecTests.testRenameRemovedUnknownAndFutureVersion, PublicNavigationV2Tests.testV1IsFrozenAndMigrationIsExplicitOptInWithoutImportedCorrelation, PublicNavigationV2Tests.testNewGoldensAndAllBackendPresentationRoundTrips.

3. Closed bounded ingress; no arbitrary selector/path/RPC/authority or private public payload.

   Sources: Codec/UIRouteCodec.swift, Codec/PublicNavigationV2Codec.swift, Codec/UIRouteSchemas.swift. Tested by CodecTests.testNoArbitrarySelectorsPathsAuthorityOrUnknownKeys, CodecTests.testDuplicateExactNumberAndBoundedIngress, PublicNavigationV2Tests.testStrictClosedSchemaRejectsPrivateAuthorityAndMutationPayloads, PublicNavigationV2Tests.testSingleParserRejectsDuplicatesFractionsUnknownVersionsAndOversize.

4. Shared canonical action policy, resolver and parser with exact backend/scene/variant discovery.

   Sources: Registry/UIDestinationRegistry.swift, Registry/UIDestinationPublicNavigationV2.swift. Tested by DiscoveryTests.testActualCorePolicyDiscoverySixOriginsAllBackends, DiscoveryTests.testFixturesInventoryAndEmptyNeverAdvertiseAsLive, DiscoveryReviewRegressionTests.testMissingExactSceneNeverFallsBackToOtherScene, PublicNavigationV2Tests.testDiscoveryReportsOnlyExactVerifiedVariantsAndNoGenericPolicyAdvertisement.

5. Missing/ambiguous/stale identity, local ownership ABA and cancellation/deadlines fail closed.

   Sources: Ports/PublicNavigationLocalBinding.swift, Registry/UIDiscoveryCancellationScope.swift. Tested by PublicNavigationV2Tests.testLocalBindingMissingStaleAndExplicitObservedAbsence, PublicNavigationV2Tests.testLocalMappingAndNativeLifetimeRevocationAcrossEveryBinderAwait, PublicNavigationV2Tests.testLocalBindingCompletionRejectsABAAfterActualEffect, PublicNavigationV2Tests.testLocalBindingDeadlineAndCancellationCleanAllBinderAwaits.

6. Core-issued final guard and exact observed receipt; content never uses a surface-only grant.

   Sources: Ports/SceneNavigationPort.swift, Ports/PublicNavigationLocalBinding.swift. Tested by NavigationAuthorizationTests.testReaderStillUsesResolverSinkGuardAndExactReceiptAllBackends, NavigationAuthorizationTests.testRevocationDuringFinalBackendAwaitPreventsReaderCompletion, NavigationAuthorizationTests.testCompletionRequiresGuardAndExactObservedReceiptWithoutRegrant, PublicNavigationV2Tests.testReaderPlanUsesFreshCoreSinkInvocationAndCannotBypassSemanticExecution.

7. Swift6 strict concurrency and existing actual Apple consumer compile.

   Sources: Package.swift. Tested by GoldenAPITests.testIDsAndSendableContracts.

## Current consumer boundary

The original app composition uses the same Core, Registry, resolver, strict public codec and retained native guard. Actual installed roots are History, Settings, Search and Annotations; current Reader content uses the original canonical reader.open path. Generic contract support for newTab, components, state or draft parameters does not advertise an installed implementation. In particular, current cross-book/new-tab and richer component bindings remain unfinished product work. Any future reservation must come from the actual scene/workspace owner and preserve the canonical final guard; no caller may invent a tab UUID, substitute a source, re-admit stale rights or use synthetic receipt success.

The original thin Hanlin adapter is a separate source-only consumer. Its14 tests compiled against original HostIntegration contracts, but the accepted full SDK/UI graph and real host journeys are still unavailable. That upstream condition does not change the canonical UI contract or permit a substitute agent, chat, parser, scope authority or numeric coercion.

## Freeze and maintenance

Private RouteSpec/UIState version1 and public-v1 behavior remain frozen. PublicNavigationSpecV2 is an explicit separate version with a finite registration allowlist and original local binding guard. Preserve all existing golden inputs; migration must be explicit and reject removed or unknown identities. Future shared contract changes must update version/schema, golden and negative fixtures, original Core/UI/host consumers and the acceptance record in one reviewed change. Actual native ownership/presentation additions must receive their own Apple compilation and exact-candidate Native execution before product acceptance.

This document supersedes historical pending G1 source-review prose only for the exact verified inputs above. It does not convert the old27 result, ongoing41 run, pending48-case matrix, upstream Hanlin state or any source test into a current Native PASS.
