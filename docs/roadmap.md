# Roadmap

Work top to bottom. One item per session unless told otherwise. Check items off here when their done-when is met. Items marked **GATE** end with a human decision; stop and wait.

Everything here is v1 as defined in `CLAUDE.md`. If something seems missing, it's deliberately out of scope — note it in `docs/later.md`, don't build it.

---

## Phase 0 — Skeleton and spike

- [x] **1. Repo skeleton.** `project.yml`, App target (SwiftUI, iOS 18), `Core` package with `Detection` / `Rating` / `Places` modules and one test target each, `Spike` macOS command-line target with embedded Info.plist, `.gitignore` (Xcode, `docs/private/`, `*.xcconfig` except a checked-in `Example.xcconfig`), README. No feature code.
  *Done when:* `xcodegen generate` succeeds, `cd Core && swift test` is green with one trivial test per module, the App scheme builds for the iPhone 16 simulator, the Spike scheme builds for macOS, first commit pushed.

- [ ] **2. Clustering.** `Core/Detection`: a pure function from `[PhotoSample]` (id, date, lat, lon) to `[Cluster]` (photos, centroid, start, end). Thresholds as parameters (default 2 h, 50 m). Ignores samples with no location.
  *Done when:* tests cover: two photos 30 min / 20 m apart cluster; 3 h apart don't; 200 m apart don't; a no-location photo is dropped; 50 photos across 4 visits produce 4 clusters.

- [ ] **3. Spike.** Three parts. (a) POI load: script or Swift code that uses DuckDB against Overture's S3 release to pull the US eat-and-drink subset (see CLAUDE.md Places data), writes `docs/private/places.sqlite` with name, lat, lon, category, subtype, GERS id, and an R-tree or grid index. (b) Photo read: PhotoKit fetch of assets in the last 365 days with date + location, on macOS. (c) Pipeline: cluster → match candidates within 75 m → Vision food check on one photo per cluster → confidence → home/work exclusion → `docs/private/spike-report.md`.
  *Done when:* the report lists every cluster with date, best candidate, alternatives, confidence, photo count, sorted by date, and the run completes in under 5 minutes.

- [ ] **GATE 3a. Read the report.** You mark each row right / wrong / missed-visit-not-shown. Decide: does detection surface enough correct visits with few enough wrong ones to be the primary entry point, or is it a bonus and search is the product? Note threshold adjustments.

- [ ] **3b. Tune.** Apply the threshold and heuristic changes from the gate. Re-run. Record the before/after in the report.
  *Done when:* you're satisfied with precision on your own library.

## Phase 1 — Backend

- [ ] **4. Supabase.** Add the Supabase Swift SDK (ask first). `supabase/migrations/` with: `profiles`, `friendships` (requested / accepted), `places` (our IDs + GERS id + MapKit id columns, PostGIS point, category, subtype), `visits` (user, place, date, source: detected / manual), `ratings` (visit, score 1–10, category at time of rating), `dish_ratings` (visit, dish name, must / good / skip), `photos` (visit, path, tier sizes), `drop_rules`, `reminders`. RLS: a user reads their own rows and rows of accepted friends; writes only their own. Seed script: NYC subset from `places.sqlite` into `places`. Config from `Config.xcconfig` (gitignored). Dev auth: anonymous sign-in.
  *Done when:* migrations apply cleanly to a fresh project, the seed loads NYC, a signed-in simulator user can insert a rating and a second user can't read it until friended (tested with two anonymous users).

## Phase 2 — Core loop

- [ ] **5. Search.** Prominent search bar on home. Server-side query on `places` by name prefix + proximity (PostGIS), NYC-biased. Results list with name, subtype, neighborhood. "Can't find it?" → `MKLocalSearch`, choose a result → insert into `places` with MapKit id → open it. Restaurant page skeleton: name, category chip, address, your rating if any.
  *Done when:* typing "Lupa" surfaces Lupa in under 300 ms on the simulator against the seeded DB; a place not in the DB can be added from Apple's results and appears in search afterward.

- [ ] **6. Rating flow.** The slider per CLAUDE.md Rating spec: stepped 1–10, no default, band-mates above, nearest-band fallback, histogram in track, category chip. Band-mate selection and histogram in `Core/Rating` with tests. Writes a visit + rating to Supabase. Revisit: preset to current score, standing updated. Dish tagging: text field with autocomplete from that place's existing dish names.
  *Done when:* with 30 seeded ratings, sliding shows the right band-mates at every stop and the empty-band fallback at stops with none; a rating round-trips to the server and appears on the restaurant page; tests cover band-mate priority and rotation.

- [ ] **7. Photos on a visit.** Pick from library (PhotosPicker), on-device HEIC tiers per CLAUDE.md Images, strip location metadata, upload to Supabase Storage under `visits/{id}/{photoId}/{tier}.heic`, `ImageURLBuilder`, display on the visit and restaurant page, `full` tier lazy on zoom in detail view.
  *Done when:* a JPEG and a HEIC source both upload as three HEIC tiers; the feed-size view never requests `full`; storage RLS blocks a non-friend from fetching a photo path.

- [ ] **8. Friends and feed.** Profile (name, handle, avatar). Friend request / accept by handle. Feed: accepted friends' visits, reverse chronological, paginated 20 at a time, `display` tier images, tap → visit detail. Empty state when no friends.
  *Done when:* two simulator users friend each other and see each other's visits; a third user sees neither; scrolling 200 visits stays smooth.

- [ ] **9. Recent-visits widget.** Port `Detection` into the App: on app open, scan assets since the last scan (first run: 30 days), cluster, match against the server `places` table, Vision food check, home/work exclusion. Home widget above the feed: cards with thumbnail, place, date, tap → rating flow prefilled; "wrong place" shows alternatives; dismiss. Local notification 2 days after detection if still unrated, cancelled when rated. Permission request uses the CLAUDE.md sentence; declining leaves the app fully usable with search.
  *Done when:* a fresh install with photo access shows a correct card for a known recent visit within 5 s of launch; declining photo access shows no widget and no errors; the notification fires and cancels correctly (test with a short interval).

- [ ] **10. Calibration onboarding.** After sign-in: explain, ask for photo access, detect visits in the last 365 days, show up to 8 with confidence high, rate each with the slider (band-mates appear from the second onward), skip allowed per item. Fallback if declined: grid of ~20 well-known NYC places, "which have you been to?", rate the selected ones. Then a find-friends screen (by handle; contacts later). Land on home.
  *Done when:* both paths complete in under 90 s and produce rated places that appear on the profile; onboarding can't be re-triggered accidentally.

## Phase 3 — Reservation drops

- [ ] **11. Reservation drops.** `drop_rules` loaded from `docs/drop-rules.csv` (user-verified; columns: place, platform, rule_type, window_days, time_local, weekday, phone, url, confidence, verified_on). Rule engine in `Core/Places`: rule + desired date → drop moment(s), all rule types in CLAUDE.md Detection/Places specs, Eastern time, "already released" case. Restaurant-page widget: rule sentence, confidence, verified date, "this is wrong" (writes a report row). CTA: multi-date picker → one calendar event (write-only permission) + local notification per drop moment, collapsed when moments coincide → link or phone.
  *Done when:* rule-engine tests cover rolling / weekly / first-of-month / phone-only / no-window / already-released; picking three dates at a 30-day-rolling restaurant creates three events at the right times; picking two dates at a first-of-month restaurant creates one.

## Phase 4 — Ship to testers

- [ ] **12. TestFlight prep.** Finalize app name and bundle ID (find-and-replace, delete PLACEHOLDER notes). Sign in with Apple replacing anonymous auth, with identity linking for existing dev accounts. In-app account deletion (App Review requirement for any app with sign-up): deletes the user's rows and photos. `PrivacyInfo.xcprivacy` privacy manifest declaring required-reason APIs and data collection. App icon (placeholder is fine), launch screen, all Info.plist usage strings. Release build config.
  *Done when:* an archive uploads to App Store Connect without warnings, TestFlight review passes, and one external tester installs and completes onboarding.

- [ ] **13. Polish for the first 15.** Empty states for every screen. Error handling: offline rating queues and retries; failed uploads retry. Accessibility labels on the slider and cards. Haptics on slider stops. Crash-free on airplane mode.
  *Done when:* a full session (onboard → search → rate with photos → see a friend's visit → set a drop reminder) works with no dead ends, and the same session in airplane mode degrades without crashing.

---

## Not on this roadmap (v1.5+)

Re-rank page · lists + Google Maps export · map · public profiles + nearby tabs · web profile · AI dish labeling · rec score · up-and-coming · dish search · unlocks and the Table Getter crown · reservation share links, "did you get it?", plans, booker attribution · "got one, clear the rest" · Android · backend move of images to R2.
