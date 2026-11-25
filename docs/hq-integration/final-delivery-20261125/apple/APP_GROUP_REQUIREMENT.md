# Exact shared App Group signing requirement

The production iOS entitlement source declares three actual groups:
- group.com.davidpovarsky.chavrusatext
- group.com.davidpovarsky.itorah
- group.com.itorah.shared

The common archive/export profile-and-app verifier previously required only the
first two. The single-line correction now requires the third in both inputs.
All other verifier bytes are unchanged. Actual project declarations pass this
group-only configuration check; deleting any one required group is rejected.

The retained authenticated portal receipt contains81 existing profiles for the
same bundle/team, and all lack group.com.itorah.shared. All81 are refused by the
corrected metadata guard. This is NOT a valid profile/signature/archive result;
qualified profile count remains zero. APP_GROUP_GUARD_REVIEW.json binds the
actual input receipt and every refusal. No Apple data was modified by this check.

Apple's current account instructions distinguish enabling App Groups from
assigning the actual groups to an App ID. The existing app identifier needs the
required real group association and a correctly regenerated distribution profile.
The authenticated capability read already shows APP_GROUPS enabled; this alone
does not prove the third association. The real Xcode provisioning or authenticated
Apple Developer account workflow must supply it. No duplicate app/bundle ID,
replacement certificate, removed entitlement or guessed credential is appropriate.

Primary reference, retrieved25November2026:
https://developer.apple.com/help/account/identifiers/enable-app-capabilities
Existing source and retained authenticated portal values are the project evidence.
