# Tapout: build plan and launch checklist

Source: `tapout-design-handoff/` (design system, 17 screen specs, CLAUDE.md). Written 2026-10-23.

## What the app is, technically

A **native SwiftUI iPhone app**, not React Native/Expo. You tap a paired NFC tag to block a chosen set of apps; tap again to unblock. Five emergency passes, ever. Everything the designs show runs **on the device**:

| Feature in the designs | Apple framework | Needs a server? |
| --- | --- | --- |
| Block apps, Shield ("Sealed") screen | FamilyControls, ManagedSettings, ManagedSettingsUI | No |
| Pick apps (onboarding step 3) | `FamilyActivityPicker` | No (Apple forbids sending the selection off-device anyway) |
| Pair and read tags ("Places") | Core NFC | No |
| Modes with schedules (9–5 weekdays) | DeviceActivity + a DeviceActivityMonitor extension | No |
| Emergency pass: open 5 min, then relock | DeviceActivityMonitor extension | No |
| Insights, milestones, NFL-game comparisons | Your own lock-session log + a bundled comparisons table | No |
| Weekly recap story image | `ImageRenderer` + share sheet | No |
| Live Activity / Dynamic Island timer | ActivityKit (`Text(timerInterval:)` ticks locally) | No push server needed |
| Home-screen widgets | WidgetKit | No |

**There are no account, login, paywall, friends or sync screens in the design.** So v1 does **not** need Supabase (or any backend). Shared state lives in an **App Group** container so the app and its extensions can all read it (SwiftData or a small JSON/UserDefaults store).

### Targets in the Xcode project

1. `Tapout` (app)
2. `ShieldConfiguration` extension (block screen look)
3. `ShieldAction` extension (what the Shield's button does)
4. `DeviceActivityMonitor` extension (schedules, emergency relock)
5. `TapoutWidgets` extension (widgets + Live Activity)

Each extension is its own bundle ID, and **each one needs the Family Controls entitlement** (targets 2–4).

## Build phases

Follows the handoff's build order, with the platform risks pulled forward.

**Phase 0: accounts and paperwork (start today, runs in the background)**
- Enroll in the Apple Developer Program.
- Register bundle IDs for all 5 targets, an App Group, and enable NFC Tag Reading.
- Submit the **Family Controls (Distribution)** request for the app and each extension bundle ID. Development builds work without approval; TestFlight/App Store do not. Recent forum reports range from 1 day to several weeks.
- Trademark check on "Tapout" (see Risks).

**Phase 1: tokens, orb, tab bar, Home (handoff steps 1–3)**
- Asset-catalog colours per token (light + dark), `Font`, `Space`, `Radius`, `Motion`, `Haptics`, `Accent`.
- `OrbView` (layered radial gradients + trimmed ring), floating tab bar.
- Home in unlocked / locked / emergency states on a mock `LockState`, plus the lock-moment animation and haptics.

**Phase 2: real-device spike (do this early, before all the screens)**
Prove the risky parts on your iPhone before polishing UI:
- Request FamilyControls authorization, pick apps, shield them, unshield them.
- Read an NFC tag's identifier, reject an unknown tag.
- Emergency pass relock after 5 minutes from the DeviceActivityMonitor extension. Note: Apple's minimum DeviceActivity interval is **15 minutes**, so a 5-minute relock needs a workaround (e.g. a 15-min interval with `warningTime` = 10 min). Developers report `intervalDidEnd` can be unreliable, so test this hard.

**Phase 3: remaining screens (handoff step 4)**
Onboarding (4 steps, interests), Modes list/edit, Places list/pair sheet, Insights week/milestone, Settings (read-only while locked), Emergency pass (hold 10 s), Rejected tag.

**Phase 4: wire the real frameworks (handoff step 5)**
Replace mocks with Core NFC, ManagedSettings shields, ShieldConfiguration ("Sealed / Tap a tag to open this app."), DeviceActivity schedules for Modes.

**Phase 5: system surfaces (handoff step 6)**
Live Activity + Dynamic Island, small/medium widgets, weekly recap image export and share.

**Phase 6: hardening and launch**
Crash reporting, privacy policy, App Store listing, TestFlight beta, review submission.

**Later (not in v1):** Buddy character (concept not chosen yet), 3D-printed Buddy enclosure.

## Design decisions to make before or during the build

1. **How you make money.** The designs have no paywall. Options: free; one-time or subscription unlock (StoreKit 2, optionally RevenueCat); or sell the tags/Buddy as hardware like Brick does (physical goods can be sold on your own store, no Apple cut).
2. **Lost tag + no passes left.** Right now the only escape is deleting the app (which removes all shields). Decide whether that's acceptable or whether you want a "pair a replacement tag" path.
3. **Emergency pass link on locked Home.** SCREENS.md says the owner may remove it; decide before shipping.
4. **How a tag is recognized.** Reading the tag's hardware UID is simplest. Writing your own secret NDEF record is harder to spoof. Writing a URL record would also let users tap the tag from the Lock Screen to open Tapout (needs a domain, below).
5. **Pass counting across reinstalls.** Store the used-pass count in the Keychain (survives app deletion on the same device) and optionally iCloud Keychain/CloudKit (survives a new phone).
6. **Shield button.** Designs show no button; iOS may require one. Check `ShieldConfiguration` when you get there.

## Risks

- **Family Controls approval delay** is the single biggest schedule risk. Submit first.
- **Name:** TAPOUT is an established MMA/fitness brand (Tapout, LLC) with registered marks, and a Canadian TAPOUT registration covers game software. Search USPTO (Class 9 and 42) and the App Store before spending on branding. Have a backup name ready.
- **Screen Time APIs are finicky**: extensions have tight memory limits, schedules have a 15-min floor, and callbacks are sometimes late. Budget real-device test time.
- **Simulator can't do NFC or Screen Time.** Nearly all testing is on a physical iPhone.

## What you need to buy and set up

Prices are approximate as of late 2026; check before paying.

### Must have

| Item | Cost | Why |
| --- | --- | --- |
| Apple Developer Program | $99/yr | TestFlight, App Store, entitlements |
| Family Controls (Distribution) entitlement | Free, but needs Apple approval | Blocking apps outside dev builds. One request per bundle ID (app + 3 extensions) |
| A Mac with current Xcode | (you have one) | Native SwiftUI build |
| A physical iPhone with NFC, on a recent iOS | (you have one) | Simulator can't do NFC or Screen Time |
| NFC tags: NTAG213/215/216 stickers or discs | ~$10–15 for a pack of 10–50 | Your "places". Get a few shapes; test reads through phone cases |
| Domain name | ~$10–15/yr | Privacy policy, support URL, App Store listing |
| Simple website (privacy, support, terms) | Free (Vercel/GitHub Pages, like comly-legal) | App Store requires a privacy policy URL and support URL |

### Strongly recommended (free tiers are enough to launch)

| Item | Cost | Why |
| --- | --- | --- |
| Crash reporting: Sentry (Cocoa SDK) or Firebase Crashlytics | Free tier | Crashes in the main app. Keep it **out of the extensions** (tight memory limits); use Xcode Organizer + MetricKit there |
| Xcode Organizer / App Store Connect crash and hang reports | Free | Built in, covers extensions too |
| Analytics: TelemetryDeck (privacy-first) or PostHog | Free tier | Onboarding drop-off, locks per week. Don't send app-selection data; Apple forbids it |
| TestFlight beta testers | Free | Screen Time edge cases need real users on different iPhones |
| USPTO trademark search | Free (filing is ~$350/class if you go ahead) | "Tapout" name risk |

### Only if you choose them

| Item | Cost | When |
| --- | --- | --- |
| RevenueCat | Free up to ~$2.5k/mo revenue | If you add a subscription or paid unlock |
| Paid Apps Agreement + tax/banking in App Store Connect | Free | If you charge anything in the app |
| Shopify or Stripe store | Monthly fee or per-transaction | If you sell tags/Buddy hardware |
| 3D printer or a print service | Varies | Buddy enclosure (later) |
| Meta developer app ID | Free | Only if you share straight into Instagram Stories instead of the system share sheet |
| CloudKit | Free (included) | Backup/sync across a user's devices |

### What you do **not** need (unlike Comly)

- **Supabase / any backend**: no accounts, no shared data, nothing server-side in the designs.
- **Auth provider**: no login.
- **Push notification server**: Live Activity timer and schedules run on-device.
- **OpenAI or other AI APIs**: nothing in the designs uses them.
- **Custom fonts**: SF Pro and SF Pro Rounded ship with iOS.
