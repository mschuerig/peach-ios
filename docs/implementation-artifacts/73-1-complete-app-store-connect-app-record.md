# Story 73.1: Complete App Store Connect App Record

Status: done

## Story

As a **developer submitting for the first time**,
I want the App Store Connect app record fully configured,
so that all required metadata is in place for submission.

## Acceptance Criteria

1. **Given** App Store Connect **When** the app record is opened **Then** the following are set: app name ("Peach"), primary language (English), primary category (Music or Education), secondary category.
2. **Given** the age rating questionnaire **When** completed **Then** the result is 4+ (all answers "None"/"No").
3. **Given** the pricing section **When** configured **Then** the app is set to Free with availability in all territories.
4. **Given** the app information section **When** reviewed **Then** copyright is set to "2026 Michael Schürig".
5. **Given** the app record pricing and availability section **When** "Universal Purchase" (or "Distribute as a universal purchase") is reviewed **Then** it is enabled, so the app appears as a single listing across iPhone, iPad, and Mac.

## Tasks / Subtasks

- [x] Verify app record exists in App Store Connect (AC: #1)
  - [x] Confirm bundle ID `de.schuerig.peach` is registered and linked
  - [x] Confirm App Store name is set to "Peach Ear Trainer" (bare "Peach" was taken — see story 72.1)
  - [x] Confirm primary language is English (U.S.)
  - [x] Set primary category: Music
  - [x] Set secondary category: Education
  - [x] Enter localized name + subtitle in "Übersetzbare Informationen" (EN: `Peach Ear Trainer` / `Ear Training for Musicians`; DE: `Peach Gehörtrainer` / `Gehörbildung für Musiker:innen`)
- [x] Complete age rating questionnaire (AC: #2)
  - [x] Answer all content description questions with "None" or "No"
  - [x] Verify resulting age rating shows 4+
- [x] Configure pricing and availability (AC: #3)
  - [x] Set price to Free (Tier 0 / 0.0 in all currencies)
  - [x] Verify availability is set to all territories
  - [x] Confirm no in-app purchases are listed
- [x] Set copyright information (AC: #4)
  - [x] Enter "2026 Michael Schürig" in the copyright field (on the version page, "Allgemeine App-Informationen" section — not the App Information page in current App Store Connect UI)
- [ ] Enable Universal Purchase (AC: #5) — **Deferred to story 74.1.** In modern App Store Connect, Universal Purchase is not a toggle on an existing iOS-only record; it requires the macOS platform to be added to the same app record (or a separate Mac record linked at creation time). The 72.1 app record is iOS-only. Bundle ID `de.schuerig.peach` is already consistent across iOS/Mac builds, so the prerequisite is met. To be completed when the Mac build is submitted in 74.1.
  - [ ] (Deferred) Add macOS platform to existing app record OR create linked Mac record during 74.1
  - [ ] (Deferred) Verify all three platforms (iPhone, iPad, Mac) show under a single App Store listing

## Dev Notes

This is a manual story performed entirely in App Store Connect. No code changes are involved.

### Prerequisites

- **Epic 72 (TestFlight):** A minimal app record was likely created during TestFlight setup. Review what is already configured before starting — some fields may already be filled in.
- **Apple Developer account** must be active with an enrolled membership.

### Step-by-Step Guidance

1. Log in to [App Store Connect](https://appstoreconnect.apple.com/).
2. Navigate to "My Apps" and open the Peach app record.
3. Under "App Information":
   - Verify app name is "Peach" and primary language is English (U.S.).
   - Select primary category. Music fits if App Store reviewers see it as a music utility; Education fits if positioned as a learning tool. Music is likely the better primary choice.
   - Optionally set a secondary category (Education if Music is primary, or vice versa).
   - Set copyright to "2026 Michael Schürig".
4. Under "Pricing and Availability":
   - Set price schedule to Free.
   - Under availability, confirm all territories are selected.
   - Enable "Universal Purchase" (may also appear as "Distribute as a universal purchase"). This ensures the app is a single listing across iPhone, iPad, and Mac — users see one entry in search, not separate per-platform listings. This requires the same bundle ID across all platforms, which Peach already uses (`de.schuerig.peach`).
5. Under "Age Rating" (or within the app version page):
   - Complete the questionnaire. All answers should be "None" or "No" — Peach has no violent content, no mature themes, no gambling, no user-generated content, no unrestricted web access.
   - Confirm the resulting rating is 4+.

### Common First-Time Pitfalls

- **App name conflicts:** If "Peach" is taken or flagged, App Store Connect will reject it during submission. Have a backup name in mind (e.g., "Peach — Ear Training").
- **Category selection:** Changing the category after launch is possible but can affect search ranking. Choose carefully.
- **Age rating questionnaire:** Even answering one question incorrectly (e.g., saying the app accesses the unrestricted web) can raise the rating. Peach has no web views or web access, so all answers should be "None"/"No".

### Project Structure Notes

No code changes. This story is fully manual in App Store Connect.

### References

- `docs/planning-artifacts/epics.md` — Epic 73 definition
- `docs/planning-artifacts/research/technical-ios-app-store-submission-readiness-research-2026-03-09.md`
- Apple docs: [Create an app record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (claude-opus-4-7)

### Debug Log References

None — manual App Store Connect work, no code or test execution.

### Completion Notes List

- **AC #1 — App record**: Verified `de.schuerig.peach` bundle ID, "Peach Ear Trainer" App Store name (per 72.1; home-screen label stays "Peach" via `CFBundleDisplayName`), English (U.S.) primary language. Set Music as primary category, Education as secondary. Entered per-locale name and subtitle in "Übersetzbare Informationen":
  - EN: `Peach Ear Trainer` / `Ear Training for Musicians` (26 chars)
  - DE: `Peach Gehörtrainer` (18) / `Gehörbildung für Musiker:innen` (30, at limit)
  - German subtitle uses the gender-inclusive colon form (`:innen`); the 30-char subtitle limit precludes a longer "Musiker und Musikerinnen" workaround. Apple uses the same convention.
- **AC #2 — Age rating**: Questionnaire completed with all answers "None"/"No"; resulting rating is 4+.
- **AC #3 — Pricing & availability**: Price set to 0.0 in all currencies (= Free / Tier 0); availability enabled in all territories; no in-app purchases.
- **AC #4 — Copyright**: `2026 Michael Schürig` entered in the copyright field. Note: in current App Store Connect UI, copyright lives on the version page ("Allgemeine App-Informationen" section near the bottom), not on the App Information page as the AC text implied.
- **AC #5 — Universal Purchase**: Deferred to story 74.1. In modern App Store Connect, Universal Purchase is not a toggle on an existing single-platform record; it is achieved either by adding the macOS platform to the existing iOS app record, or by linking a separate Mac record via Universal Purchase at creation time. Neither is possible until a Mac build is ready for submission, which is the scope of 74.1. Bundle ID `de.schuerig.peach` is consistent across iOS and macOS builds, satisfying the cross-platform prerequisite.
- **Platform availability toggles**: iPad-app-on-Mac and iPad-app-on-Vision-Pro both disabled. Mac users will get the native macOS build via Universal Purchase once 74.1 ships (brief gap between iOS and Mac App Store availability is acceptable). Vision Pro untested; can be enabled later if desired.
- **"Einstellungen zur letzten kompatiblen Version"**: Left empty. This setting designates an older build for users on outdated OS versions; not applicable for a first release with iOS 26 minimum.
- **Content Rights ("Inhaltsrechte")**: Set to Yes (app bundles third-party SoundFont content: GeneralUser GS, FluidR3_GM — both with permissive redistribution licenses; both credited in the in-app Info screen). Jnsgm2 was a developer reference download only and is not in the shipped `Samples.sf2`.
- **License Agreement**: Left blank — Apple Standard EULA applies (same as TestFlight per 72.2).
- **Recommendation for 74.1**: Add an explicit subtask to complete Universal Purchase (add macOS platform to app record or link records) when submitting the Mac build.

### File List

- `docs/implementation-artifacts/73-1-complete-app-store-connect-app-record.md` (status, tasks, Dev Agent Record, Change Log)
- `docs/implementation-artifacts/sprint-status.yaml` (status: ready-for-dev → in-progress → review; last_updated)
- `docs/planning-artifacts/appstore-metadata.md` (added per-locale Name fields; updated DE subtitle to `Musiker:innen`; updated keyword-exclusion note to reference full app names)

## Change Log

- 2026-03-29: Story created
- 2026-03-29: Added AC #5 — Enable Universal Purchase for single cross-platform listing
- 2026-05-26: Implementation completed. ACs #1–#4 done in App Store Connect; AC #5 (Universal Purchase) deferred to story 74.1 because it requires the macOS platform to be added to the app record or a linked Mac record, neither possible until the Mac build is ready. Localized name and subtitle entries chosen; `appstore-metadata.md` updated to reflect the "Peach Ear Trainer" App Store name and the gender-inclusive German subtitle (`Musiker:innen`). Platform-compatibility toggles for iPad-on-Mac and iPad-on-Vision-Pro disabled. Status → review.
