# Original Native116 source selection restored

The exact 116 original case rows, selection, seven group lists and HID choice are restored from 08f50a5646b7669d15f8c53cb13c84ac504a02bd. The current product checkpoint is 75058d1c1abbfb0fb37fc819dcece47b853eb4da. Final source/SDK admission remains UNFINALIZED; no native tests ran for this change.

The prior MiniApps one-case manifest is retained byte-for-byte. MiniApps remains a separate required two-app journey through the existing otzaria-miniapps-native.py prepare, real app build/product export, restore-producer, run and collect operations. That controller generates its own selection.json without changing this full-phase source catalog. Its assertions/producer checks are unchanged.

The full-phase runtime is the existing trusted whole driver plus only its previously reviewed original-SDK build argument and exact current R27 test digest. Its inverse is original Git blob 41268a7e701d9962c6e4ea3cf54764bb9213c3f4. The temporary MiniApps auto-router was incompatible with the existing exact driver guard and has been removed here; the separate MiniApps controller remains callable. No comparator or source guard was relaxed.

The original declaration verifier found all 116 actual Swift declarations. Release114+2 is unchanged. These source inspections are not build, UI, release or TestFlight evidence.
