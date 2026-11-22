# Current dev history integration

True two-parent merge: 031e3cfde4bd072c7e6f6a8ecc6d0a364b4af219. Parent1 is 9ced75da7726b55668f1341a1ff5a241a65abc4a; parent2 is current dev 9859c754545aed8c34b311b63490778a51db5d7e.

The sole effective change is the original 54-line Live Activity Bridge workflow. All 18 existing dev-touched files retain their exact completion bytes. Existing current notifications and actions:read already include dev's intended additions. The removed old inline release upload is not restored. The current independent deployment path and real UI/owner-signature gates are unchanged. Source, Vendor, project and XCTest trees remain exactly application385ee84a.

The merge was reviewed against the actual common base, not resolved by importing obsolete build commands. Eleven conflicted paths were resolved to the independently reviewed current bytes. INTEGRATION.json records their Git identities, both actual parents and the new workflow identity. No component, resolver or Native test was rerun for this CI/history-only integration; it provides no new Native, release, device, signing or framework acceptance.
