# Release Library admission: original overflow and safe Otzaria actions

## Candidate change

Base app/tests: 0f5111e8f8e379e17da558ddbe2aab5214ac0315. Only FaithfulReaderUIAcceptanceTests/testOriginalLibraryMenusSelectionSettingsAndBookInfoRemainUsable changes. Product, engines, provider safety, original data, workflows, manifests and frozen diagnostic branches are untouched.

The test explicitly names its existing Otzaria backend. It opens the original direct Library Options button when present; otherwise it requires the unique original TopOverflowBarButtonItem inside the same Library navigation bar and uses the existing strict tap helper. That native overflow may expose the original actions directly or the exact original Library Options submenu. A bounded 15-second preparation wait observes one of those actual native representations; a submenu is used only when needed and must be unique. The original final 15-second Select-menu wait remains unchanged.

The final menu must contain exactly two buttons with the exact labels Select… and Import Book, and no Books Updates action, including any count suffix. Every later assertion remains: actual selection mode, Done and disabled unselected Delete, original Settings and Book Info, and preserved original Reader title and locator. No case is removed or replaced.

## Exact failure and source evidence

The original Release run [44665679661](https://github.com/davidpovarsky/Maktabah/actions/runs/44665679661) used checkout 9cc346601bdb3fdda34c2c6ac59894f71dc9ea49 and app/test source 7e777509d486a17bec5b4bd437a9ac7f51d3a43a. The 11-inch test first failed at the missing direct Library Options button, after actual Category → Author → Category actions. Its preserved AX attachment shows a 1210×834 actual app window and a 320-point Library navigation bar containing Group By and the original native More/TopOverflowBarButtonItem. The direct Library Options label is absent. The 13-inch test failed earlier at its sidebar selector; it did not reach this menu assertion.

The relevant original iOSLibraryView.swift and MaktabahBookUpdateSafety.swift are byte-identical between the failed app source and this candidate base. The original Menu always offers Select and Import. It offers legacy Book Updates only when the safety owner authorizes a genuine Maktabah backend. Every actual current BackendID deliberately rejects that foreign updater.

The old count-three assertion therefore contradicted both current original source and the explicit [Books Updates acceptance task](https://app.asana.com/1/1219597879016953/task/1220539610434045): Otzaria must not offer an action that attempts Maktabah SQL updates. ASANA_PROVENANCE.json preserves the freshly read exact acceptance and current provider-decision excerpts. This correction verifies safe Otzaria menu admission only. The broader compatible-provider update, native migration/recovery and physical-device task remains OPEN/BLOCKED_PROVIDER.

Source construction does not prove how iPadOS presents the opened overflow. The candidate accepts only the two original representations and still requires the real menu and its exact actions. No post-tap Native success is claimed.

## Validation and limits

The whole-file inverse restores the exact base Git blob. All other test methods and test declarations are unchanged. Every original timeout remains unchanged; only the documented bounded overflow-presentation preparation wait is added. Windows Swift 6.3.3 frontend syntax parsing passed with zero warnings. Apple SDK typecheck and Native candidate execution are NOT_RUN.

The method remains part of the original Release configurations and is not selected in diagnostic38. Original full Release acceptance remains 96 UI cases plus two oracles across all five configurations. No manifest or frozen CI branch changes are made here.

## Remaining original failures

OUTSIDE38_FIRST_FAILURES.json deliberately separates method-only overlap from device-specific coverage. Of the original 61 failed leaves, 39 have method IDs absent from diagnostic38 (28 unique methods). By exact method and device, 46 are unselected: 16 on 11-inch, all 28 on 13-inch, and two on iPhone. Only 15 original failed leaves match both selected method and device. A method rerun on 11-inch does not provide 13-inch acceptance.

All 37 iPad leaves in the method-only remainder occurred after the old failed window case; this ordering is not proof of a cascade. Reduce Motion is independently blocked before app launch: the selected original recording still shows its actual Settings switch OFF after the tap. Root owns that investigation. B independently reviewed the Escape failure, unchanged source and exact frames and found no deterministic product cause; its evidence and limits are included without a speculative fix.

## Authentic artifacts

The original full Release evidence ZIP was authenticated in the earlier sealed evidence tranche. This investigation reused its original gzipped activity logs. The separate 3.11 GB capture archive was not downloaded or whole-hash verified. RANGE_EVIDENCE.json records authenticated GitHub metadata, exact HTTP206 ranges, selected-entry CRC validation and SHA256 values for the Library AX and selected Motion/Escape recordings. Raw differing JSON byte streams are retained in deterministic gzip records; readable JSON copies use canonical LF. The videos and extracted frames remain in the recorded owned build directories. No user index, installed database or source dataset was read or modified.
