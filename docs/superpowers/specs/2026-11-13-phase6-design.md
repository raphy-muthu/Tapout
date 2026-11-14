# Phase 6: release prep

The build order in `CLAUDE.md` is complete. Phase 6 gets Tapout ready to upload to App Store Connect. It adds what a submission needs (the app icon, privacy manifests, export compliance, the listing, screenshots and a privacy policy) and fixes the small items left over from Phase 5. The owner's iPhone run happens separately, using the combined checklist this phase writes.

## Decisions (2026-11-13)

The owner asked for Phase 6 to proceed without stopping for approval, so these calls are mine. Each can be changed later.

| | |
| --- | --- |
| App icon | As `design/screens/AppIcon.dc.html`: near-black `bg`, an 800 px `surface1` disc, and the ember orb at 720 px with a full seal ring, on a 1024 px square. It is rendered from `OrbView` with `ImageRenderer`, so it matches the app exactly. It is opaque, a single universal size, and has no dark or tinted variants (iOS derives those). |
| Privacy manifests | Each of the four bundles gets a `PrivacyInfo.xcprivacy`. No tracking, no data collected. Required-reason API: UserDefaults, `CA92.1` (the app's own defaults, app only) and `1C8F.1` (App Group defaults: app, monitor and widgets). The shield uses no required-reason APIs and gets an empty manifest. |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO`. Tapout uses no encryption of its own; the Keychain is exempt. |
| Keychain read every second | `LockEngine.tick` stops re-reading the pass vault. The count only changes through the engine itself. Engine properties are only assigned when their value changes, so a tick that changes nothing redraws nothing. |
| Recap image | The full 1080 × 1920 image is rendered when Share is tapped, through a `Transferable`. The share sheet's thumbnail is a 1× render (360 × 640), refreshed as before. |
| Tinted Home Screen widgets | In the tinted and clear modes (`widgetRenderingMode != .fullColor`), the small and medium faces draw a flat orb, a soft disc with an accentable ring, in place of the glass orb, and today's bar is accentable. Full colour is unchanged. Lock Screen widgets are already tinted by iOS. |
| A swiped-away Live Activity | **Unchanged: it comes back the next time Tapout opens.** ActivityKit can't reliably tell a swipe from iOS ending an activity at its 8-hour limit (both end up dismissed, and dismissed activities drop out of the list). Respecting the swipe would risk never restarting after the 8-hour limit. Settings → Live Activity turns it off for good. |
| App Review | Reviewers have no NFC tag. The review notes explain this and ask for a screen recording of the full flow to be attached. The owner records it on their iPhone. The DEBUG Lab is not in Release builds. |
| Listing copy | Follows the app's voice: few words, no guilt, no emoji. Category Productivity. App Privacy: Data Not Collected. |

## Not in Phase 6

- Uploading or signing anything. That needs the owner's Apple account: profiles for TapoutShield and TapoutWidgets, the Family Controls distribution entitlement request, and creating the App Store Connect record.
- Hosting the privacy policy. The owner needs a URL for it.
- The iPhone run.
- Localisation.
- The Buddy character.
