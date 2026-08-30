# CLAUDE.md

Read this file fully at the start of every session. Product context lives in `docs/product-notes.md`; read the sections referenced below before touching related code.

## What this is

A social restaurant-logging app for iOS. Friends rate the places they eat, the app notices where you ate from photo metadata and starts the review for you, and popular NYC restaurants carry reservation-drop reminders. Think Beli with near-zero-effort logging and honest scores.

Working name: **Thumbs** (PLACEHOLDER — rename before first TestFlight upload).
Bundle ID: **com.CHANGEME.thumbs** (PLACEHOLDER — finalize before first TestFlight upload; do not register any capabilities that bind to it until then).

## Stack (pinned — do not deviate without asking)

- Xcode 26.6, Swift 6 with strict concurrency enabled
- iOS deployment target: 18.0
- macOS deployment target (spike CLI only): 15.0
- UI: SwiftUI only. UIKit only where SwiftUI cannot reach the API, and say so in a comment.
- State: `@Observable` view models. No Combine. No ObservableObject.
- Concurrency: async/await, actors, structured concurrency. Everything crossing an isolation boundary is `Sendable`.
- Persistence: SwiftData for app models. The spike's POI dataset is SQLite via the system `SQLite3` module. No third-party persistence libraries.
- Networking: URLSession with async APIs. No third-party HTTP clients.
- Backend: Supabase (Postgres/PostGIS, auth, storage) via the Supabase Swift SDK. NOT used by the spike. Added right after the spike, before the rating flow: ratings are server-authoritative from the first one (small local cache only) so there is never a storage migration. Ask before adding the SDK. Schema lives in SQL migration files in `supabase/migrations/`; friends-only visibility is enforced with row-level security. Project URL and anon key come from a gitignored `.xcconfig`, never hardcoded.
- Auth: Supabase anonymous sign-in or email OTP during development. Sign in with Apple only after the bundle ID is final and enrollment is complete; link identities then.
- Testing: Swift Testing (`@Test`, `#expect`) for everything in `Core`. XCTest only if a Swift Testing gap forces it.
- Project file: XcodeGen. `project.yml` is the source of truth.

## Repo layout

```
project.yml            XcodeGen spec — the only place targets/settings are defined
CLAUDE.md
docs/
  product-notes.md     Product spec (source of truth for behavior)
  detection-spec.md    Acceptance criteria for photo-based visit detection
  private/             Gitignored. Anything with personal data (spike reports).
  roadmap.md           Ordered prompt sequence with done-when criteria. Work through it top to bottom.
App/                   iOS app target. SwiftUI views + view models only. No business logic.
Core/                  Swift package. All logic. Fully testable from the terminal.
  Sources/Detection/   Photo clustering, place matching, confidence
  Sources/Media/       Image tiers, HEIC processing, storage paths
  Sources/Rating/      Score model, band-mate selection, histogram
  Sources/Places/      POI model, SQLite access, search
  Tests/               One test target per module
Spike/                 macOS command-line tool. Runs Detection against the local Photos library.
```

Views in `App/` are thin. If a view needs a rule, the rule goes in `Core` with a test.

## Commands

```
xcodegen generate                       # after any change to project.yml or new target
cd Core && swift build && swift test    # fast loop for all logic
xcodebuild -project Thumbs.xcodeproj -scheme Thumbs \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -project Thumbs.xcodeproj -scheme Spike -destination 'platform=macOS' build
```

Run `cd Core && swift test` before every commit. Run the iOS build before any commit that touches `App/` or `project.yml`.

## Rules

- NEVER edit `*.xcodeproj` or `*.pbxproj` by hand. Change `project.yml`, then `xcodegen generate`.
- NEVER add a dependency (SPM, brew, anything) without asking first.
- NEVER touch code signing, provisioning, entitlements, or capabilities. Those are manual.
- NEVER register anything that binds to the bundle ID (Sign in with Apple, push, App Groups) — placeholder ID.
- No new logic in `App/`. Logic goes in `Core` with tests.
- No singletons. Inject services into view models.
- Do not build anything outside the v1 scope below, even if it seems small. Note ideas in `docs/later.md` instead.
- Prefer deleting code to adding abstractions. One pattern per concern; don't introduce a second way to do something that already has a way.
- Comments only for non-obvious decisions (why, not what).
- Commit after each completed task with a one-line message describing the behavior change.
- At session start: `git status`, then `cd Core && swift test`. At session end: tests green, committed.

## Info.plist strings

- `NSPhotoLibraryUsageDescription` (App and Spike):
  "We use the location and time on your photos to spot restaurants you've visited, so reviewing takes one tap. Nothing is uploaded until you choose to share it."
- `NSCalendarsWriteOnlyAccessUsageDescription` (App, for reservation reminders):
  "We add a reminder to your calendar for the moment reservations open."

The Spike is a command-line tool, so its Info.plist must be embedded in the binary (`CREATE_INFOPLIST_SECTION_IN_BINARY = YES`, `INFOPLIST_FILE` set in project.yml) or the Photos permission prompt will not appear.

## v1 scope (build exactly this; see docs/product-notes.md §5h)

1. Search that resolves to a restaurant fast (prominent on home)
2. Slider rating flow (integers 1–10, live band-mates) with dish tagging as a text field + autocomplete (no AI labeling)
3. Friend feed — everything friends-only; comments on visits (added 2026-08-29)
4. ~~Recent-visits widget~~ — deferred to v1.5 after the on-device spike (2026-08-29); see docs/later.md. Detection ships only inside onboarding.
5. Calibration onboarding: photo library → last 10 distinct places (180-day max lookback) → slide a score for each; fallback grid of well-known nearby places if photo access is declined
6. ~~Reservation drops~~ — cut from v1 (2026-08-29); see docs/later.md

Not in v1 (do not build): lists, map, public profiles, nearby tabs, web profile, AI dish labeling, re-rank page, rec score, up-and-coming, dish search, unlocks, reservation sharing/outcomes/crown, anything restaurant-facing.

Order of work: Spike (detection) → Supabase setup + schema + places seed → search → rating flow → feed → onboarding → TestFlight prep.

## Rating spec (v1) — docs/product-notes.md §6

- Control: a stepped slider, integers 1–10, haptic tick per stop, numbers also tappable. No half-points.
- No default position. Thumb starts unselected; band-mate cards are hidden until first touch.
- As the thumb rests on a stop, show 2–3 existing places at that score in the same category (restaurant / cafe / bar), with photos, ABOVE the slider. Crossfade on change; only swap after the thumb has rested on a stop (~150 ms) so a fast drag doesn't strobe.
- Empty band: show the nearest non-empty bands above and below, labeled ("no 8s yet · your 9s · your 7s"). Fewer than 3 in a band: show what exists.
- Track shows a faint per-stop histogram of the user's existing ratings in that category.
- Category chip next to the slider, auto-set from the place, tappable to override.
- Band-mate selection priority: most visits, most recently visited or viewed, survived a re-rank. Rotate so the same three don't repeat.
- Release = done. There is no separate confirm step.
- Dishes: per-dish Must-order / Good / Skip, optional, never rolled into the restaurant score.
- One editable rating per place (decided 2026-08-29, replacing per-visit ratings + standing blend): re-rating opens the same slider preset to the current score and edits the number in place. Visits remain the activity log. Ratings are never deletable from the UI — X during a first rating discards it as if it never happened; X while editing reverts to the previous score and category.
- Re-rank page (not v1) uses the same component.
- No forced order within a band. No sub-scores for service/ambiance/value.

## Detection spec (spike) — docs/detection-spec.md is authoritative

- Input: photo assets with creation date and location (PhotoKit). Screenshots and assets without location are ignored.
- Cluster: photos within 2 hours and ~50 m of each other (starting thresholds; tune against ground truth).
- Match: cluster centroid → candidate POIs from the local SQLite dataset within 75 m, food/drink categories only.
- Confidence: single candidate + ≥2 photos + at least one photo classified as food (Vision) = high. Multiple candidates = ambiguous (surface as "X or Y?", never guess). Otherwise low (do not surface).
- Exclude the user's most frequent clusters (home/work) after they recur ≥ N days.
- Output per cluster: date, centroid, candidates ranked, confidence, photo asset IDs.
- Report: human-readable, sorted by date, for a configurable window (default 365 days): date, best candidate, alternatives, confidence, photo count. Written to `docs/private/spike-report.md`. The user verifies it from memory; there is no ground-truth file.
- Optimize for precision over recall.

## Places data — Core/Places

- Canonical entity: our own `places` table with our own IDs. Reviews, visits, and reminders attach to it. Never use a third-party ID as the primary key.
- Seed source: Overture Maps Places (GeoParquet, monthly releases on S3). Filter to the eat-and-drink branch only using `basic_category` / `taxonomy` — the `categories` property is deprecated and removed in the September 2026 release. Nothing outside that branch (grocery, retail, hotels) is downloaded. Keep the Overture GERS ID as a secondary column for future syncs.
- Review categories: exactly three — `restaurant`, `cafe`, `bar`. Every place maps to one. Keep the original Overture subtype (cuisine, bakery, brewery, etc.) as metadata for search and recs. Mapping: restaurants of any cuisine, fast food, food trucks, food-hall vendors → restaurant · coffee shops, tea rooms, bubble tea, juice bars, bakeries, dessert, ice cream, donut and bagel shops → cafe · bars, pubs, cocktail and wine bars, breweries, wineries, beer gardens → bar. Unmapped subtypes → restaurant, and log them.
- Secondary source (gap-filling, optional): Foursquare OS Places (Apache 2.0). Dedupe by name + proximity before inserting.
- Scope: the US food/drink subset for the spike's local SQLite (filter the Overture release with DuckDB against S3 by category + US bounding box rather than downloading the full theme). The server database on Supabase's free tier is capped at 500 MB, so seed it with NYC plus the testers' cities only, and add regions per launch (or move to the paid tier for the full set). NYC is also the curation scope (drop rules, QA).
- In-app "add a missing place": MapKit `MKLocalSearch` (first-party, free, no key). A user-selected result creates a new row in our table; store the MapKit place identifier as a secondary column for dedupe.
- Do not add Google Places. Do not add any hosted POI API.

## Images

- Accept any source format from the photo library (HEIC, JPEG, PNG, etc.). Decode to pixels once, resize, then encode each tier as HEIC on-device. Never reject or special-case a source by file type.
- Three tiers, all encoded on-device as HEIC before upload. Set dimensions and quality; never squeeze to a byte target.
  - `thumb`: 480 px longest edge, quality 0.8. Grid tiles and strips only; never displayed larger than ~160 pt.
  - `display`: 1600 px longest edge, quality 0.8. Every full-width view: feed cards, visit card, first load of the detail view.
  - `full`: 2560 px longest edge, quality 0.85. Detail view only, loaded lazily when the user zooms.
- Never upload originals. Never compress an already-compressed file a second time. Never use server-side image transformations.
- Feed and lists must never request `full`.
- Store bucket-relative paths in the database, never full URLs. One function (`ImageURLBuilder`) turns a path + size into a display URL. Nothing else constructs image URLs.
- v1 bucket: Supabase Storage with RLS matching the visit's visibility. Designed so the backing bucket can move to Cloudflare R2 later by changing the URL builder and upload target only.
- Strip location metadata from photos before upload. Location lives on the visit record, not in the file.

## Session protocol

1. Read this file, then `docs/roadmap.md`.
2. Find the first unchecked item in the roadmap. Restate its done-when criteria before starting.
3. Do only that item. If it turns out to need something not in scope, stop and ask rather than expanding.
4. When the done-when criteria are met and tests are green, check the item off in `docs/roadmap.md`, commit, and stop. Do not start the next item in the same session unless asked.
5. If a roadmap item is marked **GATE**, stop after it and wait for the user's decision.
