# Authenticated Apple preflight — 2026-11-25

These are read-only authenticated Apple API observations, not a signing/upload qualification.

- Existing app:6809559414, ChavrusaText, bundle com.davidpovarsky.chavrusatext.
- Existing Apple Team:NA6HPWARQ2.
- Live portal/profiles read:job_0ac62946fab9; receipt SHA256 e17448d8c982b35524106d0674b9ab4c589b8aeef0751d18f68f76420f589bad.
- Follow-up encryption/current builds read:job_b80feb0ec1a0, exit0; receipt SHA256 0e24b1cee384229c59a5def962109e292bf10083a91040c8fcd6da6bed3b4e50.
- Latest upload:1.0.0/11201, VALID, not expired, build resource78f4cf1f-d84a-4a57-aa1d-de472790916c. Its historical usesNonExemptEncryption=false is recorded exactly, not reused as classification of changed native code.
- App encryption declarations endpoint returned zero records. AppStore version1.0 remains PREPARE_FOR_SUBMISSION.
- App Store profiles:81 examined, all retain only group.com.davidpovarsky.chavrusatext and group.com.davidpovarsky.itorah; none authorizes group.com.itorah.shared, which the actual MiniApps integration requires. Do not remove that entitlement to make signing appear successful.
- Capability App Groups is enabled, as are iCloud and push. An enabled capability alone does not prove membership in the third group.
- Existing distribution identity has already passed a genuine codesign/verify probe via the pinned m1 SSH session. That probe is not an app Archive.
- No Apple app, identifier, certificate or compliance declaration was created or modified by these readbacks. No build was uploaded.

Original receipts also remain at /Users/m1/builds/_preflight. Private authentication key material and JWTs are absent from these retained results. The exact final product must be classified, signed, validated, uploaded and observed as processed/available before TestFlight can be accepted.
