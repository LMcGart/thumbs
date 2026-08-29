# Better Beli — Product Notes & Honest Assessment

*Organized from brain dump, August 2026 — v4*

---

## 1. Summary

**Thesis:** Beli proved the core idea — trusted-friend restaurant rankings plus personalized recommendations — but has under-invested in the product since launch. Logging a visit is high-effort, new users hit a wall before they see any value, the recommendation score is weak given how much data Beli holds, and the UI is confusing. The plan is a "same thing, done better" product (Jeff Zalaznick's Major Food Group framing: not different, just better executed) — not a clone, and no Beli import. It's built on photo-assisted reviews that start from the home screen, an onboarding that produces real scores in the first minute, a rating system that stays accurate at scale, an honest rec score, and a friends-first home with discovery in tabs.

**Core belief:** People stop using Beli because logging is too much work for too little reward, and many never start because the first ten ratings are a chore with no payoff. Fix the effort/reward ratio at both ends and you win.

---

## 2. What Beli gets right (keep these)

- Reviews from trusted friends beat reviews from strangers — the anti-Yelp insight
- Comparative ranking produces more accurate scores than star ratings
- Recs are better than anything else available, even if still not good
- Up-to-date dish photos — knowing what to order is a killer feature
- Invite-only launch self-selected a foodie community and built a referral engine
- Playlists/lists as a replacement for Google Maps lists is a good idea, just badly surfaced

---

## 3. Issues with Beli

**Onboarding cliff**
- No scores appear until you've rated 10 places, and the comparison mechanic isn't explained — new users bounce before they see any value
- Setup is a chore: everything starts from a blank search box

**Logging & review friction (the #1 churn driver)**
- Every review starts with searching for the restaurant
- Every photo is manually uploaded and tagged; no autofill of dish data
- No "you were at X — want to review?" prompt or push notification

**Rating system**
- Comparative ranking is novel and works early, but degrades at scale: a large catalog makes it inaccurate and unmaintainable (each new entry re-ranks against a long list; scores drift as the list grows; old rankings go stale; no real model for revisits)

**Recommendations**
- The rec score isn't useful, so the "recommended for you" surface built on it isn't either — despite Beli sitting on one of the largest dining datasets anywhere

**UI, UX & discoverability**
- Unintuitive, visually dated, extremely confusing for first-time users
- Playlists are buried and unexplained; people want their lists in one place, and there's no export to Google Maps
- Little visible innovation since launch

**Discovery & search**
- No good cuisine or dish search
- Home screen doesn't surface useful nearby recs

**Social**
- Can't see other people's written reviews — the effort people put in goes to waste
- Many features gated behind "share with friends"; the invite model outlived its usefulness

---

## 4. Improvements you've proposed

| Issue | Proposed fix |
|---|---|
| Onboarding cliff | Calibration onboarding: find 5–10 recent visits via the photo library, walk the user through rating them against each other; scores exist from the first rating |
| Starting a review | Home-screen recent-visits widget: "You were at X on Tuesday" with thumbnails of your photos — tap to start the review. Search stays prominent on home as the manual path |
| Photo friction | AI identifies dishes in your photos and pre-fills the review; other photos from the same visit are attached automatically |
| Forgotten visits | Push notification after 1–3 days if a detected visit is still unrated |
| Photo privacy | Photo access is optional and everything works through manual search; detection runs on-device and only user-chosen photos are uploaded |
| Rating drift | Integer slider that shows your other places at each score as you slide, plus a re-rank page for aging ratings (see §6) |
| Rec score | Make it actually predictive before building surfaces on it |
| Home screen | Friends' reviews by default; tabs for Recs nearby and Reviews nearby (public profiles only — profiles default to private); map of nearby places with scores |
| Discovery | "Up-and-coming" page (many reviews in a short window); highest-rated nearby |
| Lists (playlists) | Keep them, make them first-class and obvious, add export to Google Maps |
| Social | Written reviews visible; see what people around you are reviewing (opt-in via public profile) |
| Cold start | No imports from Beli or anywhere else — the only cold-start tool is the photo-based onboarding calibration |
| Access model | No invite gating. Basics are excellent and free; fun or useful extras unlock as you review more |

---

## 5. Additional sections

### 5a. What Beli already does (don't rebuild these as "new")

Before positioning, know the current baseline. Beli already has: Google Maps list import, a Taste Profile, a friend Match Score, tags/notes/favorite dishes per restaurant, OpenTable booking integration, a SevenRooms collaboration, a reservation hand-off feature, and ticketed one-off events. It reports 75M+ ratings (Ivey Business Review, May 2026), was named to Inc.'s 2026 companies-to-watch list and Fast Company's 2026 most-innovative-in-social-media list, raised a $5.3M Series A (Nov 2023), and is actively hiring engineers. Reported team size ranges from under 10 to ~45 depending on the source.

"Dead product" is your experience as a user; it's not the market's read. The accurate framing: **stagnant UX on top of a strong, growing network.**

### 5b. Product principles

1. **Effort/reward.** Logging a meal takes under 30 seconds and gives something back immediately — a score, a friend's reaction, a stat.
2. **The app starts the review when it can.** Recent visits appear on the home screen ready to rate; a prominent search bar is always one tap away for everything else.
3. **Photos assist, they don't gate.** Photo access makes logging near-zero effort, but nothing requires it.
4. **Scores from the first rating.** No thresholds before the product shows value.
5. **Home is your friends.** Discovery lives in tabs, not mixed into the feed.
6. **Private by default, open by choice.** Profiles start private; public is one toggle away, and public reviews feed nearby discovery.
7. **Earn delight, never gate utility.** Everything needed to track and share is free from day one; extras unlock through use, not invites.

### 5c. Target user & wedge

Beli's base is roughly 80% under 35 and densest in NYC, Chicago, and SF. **Launch city: NYC.** That's Beli's home turf, chosen deliberately because the reservation-drops feature (§7) only matters where tables are hard to get, and it's the one thing in the plan that's useful to someone with zero friends on the app — the cold-start hook. Three wedges, in priority order:

- **The reservation chaser** — sets drop reminders, shares reminders with friends, lands the table, logs the visit. The zero-friend entry point.
- **The lapsed Beli user** — has a long list, stopped logging because it's a chore. Pitch: the app notices where you ate and a review takes 30 seconds.
- **The "what should I order" user** — dish-level, not restaurant-level. This is the gap Beli hasn't filled and small competitors are circling.

### 5d. Core loop

Eat and take photos as usual → next time you open the app, a card on the home screen says "You were at [X] on Tuesday" with your photo thumbnails → tap it → AI-labeled dishes, tap Must-order / Good / Skip → slide to a score while your other places at that score appear above the slider → done in ~30 seconds → post lands in friends' feed → friends save to lists or react → your taste profile sharpens → the Recs tab gets better → you go, take photos, repeat. If a detected visit sits unrated for 1–3 days, a push nudges you.

### 5e. Onboarding & cold start

There is no import — this isn't a Beli clone. The cold-start tool is the calibration onboarding:

1. Ask for photo access (limited or full) with a plain explanation: "We look at where and when your photos were taken to find places you've eaten."
2. Detect 5–10 recent restaurant visits from photo metadata (location + time clustering, matched to places).
3. Rate each one on the slider; from the second onward, the places already rated at that score appear as you slide.
4. Every place now has a real score — no comparisons against a long list, no threshold.
5. Land on the home screen with a ranked list, a map, and a prompt to find friends.

Target: under 60 seconds, ranked list on day one.

**Privacy-safe fallback:** if the user declines photo access, show a grid of well-known nearby places to tap ("which of these have you been to?"), then the same rating flow. Detection from photo metadata is far less invasive than background location tracking, which is why it's the primary path — but the app must be fully usable without it, and that needs to be true in practice, not just in the settings screen.

### 5f. Progression (earned, not gated)

Free and excellent from day one: logging, lists, feed, map, recs, sharing.

Unlock through reviews (roughly by count or streak): stats and year-in-review, custom list covers and themes, taste-profile deep dive, "top critic among friends" badges, advanced filters, profile flair, early access to new features. The monthly Table Getter crown (§7) lives here too: crown on the avatar for the month, an all-time tally on the profile, and a "hardest table you landed" line in year-in-review. Rule: gate delight, never utility.

### 5g. Risks & open questions

- **Network effects.** Friends' reviews are the value, and the friends are on Beli. One person switching doesn't move their friends.
- **Copyability.** A funded team can ship AI photo logging and a home-screen visit card in a quarter once they see traction. What's the durable edge?
- **Photo permission acceptance.** If most users decline photo access, the frictionless path collapses to manual search. This is the first number to measure.
- **Place detection accuracy.** Wrong-restaurant guesses in a dense block (three restaurants in one building) will erode trust fast; the card needs an easy "not here, it was ___" correction.
- **Drop-rule data decays.** Reservation rules change per restaurant and often; the feature is only as good as the curation. Budget a weekend for the first 100 and a monthly re-verification pass until crowd confirmation carries it.
- **Launching in NYC means fighting Beli where it's densest.** The trade is the zero-friend hook; if the reservation feature doesn't pull installs on its own, the city choice should be revisited.
- **Distribution.** Consumer social is brutal here. You can build the product; who's doing growth?
- **Cold-start recs.** Rec quality needs data you won't have on day one. What does the Recs tab show at 500 users?

### 5h. MVP scope (v1)

**The bet being tested:** near-zero-effort logging makes people log more, and friends' logs are worth reading. Everything in v1 serves that; nothing else ships until people are logging.

**Home screen:** a prominent search bar (always the fastest manual path) and, above the feed, a recent-visits widget — cards for detected, unrated visits with photo thumbnails, tap to start the review. When detection has nothing, the widget is empty and search is right there.

**Build:**
- Calibration onboarding (photo library → recent places → slide a score for each), with the no-photo-access fallback
- Recent-visits widget on home + unrated-visit push after 1–3 days
- Slider rating flow with live band-mates, dish tagging as a text field with autocomplete (no AI labeling yet)
- Friend feed — everything is friends-only in v1
- Search that resolves to a restaurant fast
- Reservation drops, NYC only, reminder-only (§7): drop-rule widget on the restaurant page, pick one or more dates → a calendar event + local notification per drop moment (collapsed when dates share a release), platform link or phone number. ~100 hand-curated restaurants with confidence + last-verified date and a "this is wrong" tap. Nothing else — no sharing, no outcome prompt, no crown.

**Cut from v1 (add back once people are logging):** lists and Google Maps export · map · public/private profiles and nearby tabs · shareable web profile · AI dish labeling · re-rank page · rec score · up-and-coming page · dish search · progression/unlocks beyond the crown · reservation extras (share links, "did you get it?", plans, booker attribution, crown, share card) · anything restaurant-facing.

**Defaults for the open rating decisions** (change later if data says so): integer slider 1–10 · three band-mates · re-rank cadence 6 / 18 months · three review categories (restaurant / cafe / bar), band-mates scoped by category.

**The number that says the wedge is real:** % of detected visits logged within 3 days, plus logs per user per week. Decide the target before building.

---

## 6. Rating system (proposed — v2 draft)

**Principle:** the score is absolute and belongs to the place; comparisons exist only to keep the score honest. Beli builds the list from comparisons, so scores drift with list size. Letterboxd has nothing concrete behind the number, so scores inflate. This does neither.

**Dishes:** buckets, unchanged. Must-order / Good / Skip per dish, optional, never rolled into the restaurant score.

**Rating a place**

1. A stepped slider, integers 1–10, haptic tick at each stop; numbers are also tappable. No half-points — with the comparison in view while you choose, a coarser scale is more honest.
2. No default position: the thumb starts unselected so no number anchors the user, and band-mate cards stay hidden until first touch.
3. As the thumb rests on a stop, 2–3 existing places at that score in the same category appear above the slider (above, so your hand doesn't cover them), crossfading on change and only swapping once the thumb has rested a beat.
4. Empty band → show the nearest bands above and below ("no 8s yet · your 9s · your 7s"). Fewer than three → show what exists. No threshold, no setup.
5. Release = done. Rate and compare are one gesture; there is no separate confirm step.

Also: a faint histogram in the track shows how many places sit at each stop (distribution feedback without a nag); a category chip shows restaurant / cafe / bar, auto-set and overridable; the re-rank page reuses this exact component preset to the current score.

**Which band-mates to show.** This is where accuracy lives. Prefer places you'll actually remember and that define the band: most visits, most recently visited or viewed, and ones that have survived a re-rank. Over time the band-mates converge on your de facto benchmarks without anyone maintaining a benchmark list. Rotate so the same three don't appear every time.

**Inflation control**

- The live band-mates are the main defense: you can't slide to 8 while looking at your best 8s without noticing.
- Distribution feedback: a small histogram on your profile, and a gentle nudge when a band gets crowded ("47 eights — want to spread them out?") that links to the re-rank page. Never auto-adjust anything.

**Recency and drift: the Re-rank page**

Ratings age. The page lists ratings due for a check: single-visit places after ~6 months, multi-visit places after ~18 months, plus anything never re-checked. Filters by age (6+ mo, 1+ yr, 2+ yr) and by band ("all my 9s"). Same slider as rating, preset to the current score with band-mates visible, so it takes seconds per place. A band-grid view lets you drag outliers between columns. Prompted lightly: a badge count, an optional weekly nudge ("12 ratings turned six months old — two-minute check-in?"), and a year-end re-rank that pairs with the year-in-review card. Confirmed places gain confidence; confidence feeds recs and band-mate selection.

**Revisits.** Re-rating a place runs the same flow, prefilled with the current score. Standing is a recency-weighted blend with a floor so one bad night can't erase five good ones. Show visit count next to the score.

**Ordering.** No forced order within a band. A hand-curated, draggable Top 10 sits above the scale (Letterboxd-style favorites). An optional "settle it" swipe deck for people who like the Beli game; it only affects cosmetic order within a band.

**Categories.** Exactly three — restaurant, cafe, bar — and band-mates come from the same one. Bakeries, dessert, ice cream, boba, and juice fold into cafe; breweries, wineries, pubs into bar; food trucks, food halls, fast food into restaurant. Cuisine stays as metadata for search and recs, not a review category.

**Where dish ratings go**

- Restaurant page: "Friends' must-orders," ranked by count — the "know what to order" feature, aggregated
- Your taste profile and recs: if you keep must-ordering noodles, noodle-strong places rank higher for you
- Discovery: a place with many must-orders from many people can be flagged "strong menu" without touching anyone's personal score

**What not to add:** numeric sub-scores for service, ambiance, value. They add friction and nobody uses them consistently. Tags do the same job and are filterable.

**Open decisions**

- ~~Whole-number input with half-point moves, or half-points directly?~~ — decided: integer slider, no half-points.
- Two band-mates or three?
- Re-rank cadence: 6 / 18 months as defaults, user-adjustable?
- ~~Category scope for band-mates~~ — decided: three categories, cuisine as metadata only.

---

## 7. Other feature & experience suggestions (from me)

**Logging**
- *Visit correction.* On the recent-visit card, a one-tap "wrong place" that shows the two or three other candidates at that location.
- *Batch review.* "4 unreviewed visits this week" — rate them all in one swipe session.
- *Voice → structured review.*
- *Private notes* per restaurant ("ask for the counter," "skip the tasting menu").

**Reservation drops (NYC first)**

*v1 is reminder-only: the widget, multi-date selection, the reminder, the link. Everything from "Share instead of groups" onward is v1.5+ and kept here as the design intent.*

- *The widget on the restaurant page.* One line stating the rule ("Resy · 30 days out · 10:00 AM ET" / "Phone only · call [number] at 10 AM" / "Walk-in only" / "No fixed window"), a confidence level and last-verified date, and a "this is wrong" tap. Under it the CTA: pick one or more dates → the app computes each drop moment → adds a Calendar event with an alarm per moment (dates that share a release, like weekly or first-of-month batches, collapse into one reminder listing the dates) (write-only calendar permission, lighter than full Reminders access) plus a local notification 5 minutes before → deep-links to the venue page on Resy / OpenTable / Tock / SevenRooms, or shows the phone number. If the date already released, skip the reminder, link now, and point to the platform's cancellation alerts.
- *Rule model.* Rolling window (N days at HH:MM), weekly batch, first-of-the-month batch, announced one-off drops, phone-only at a set hour, walk-in only, no fixed window. Eastern time. Never guess; say "no fixed window" when it's true.
- *Data.* Hand-curated, ~100–150 places to start. Never scrape platform APIs and never attempt the booking — human-in-the-loop only. Freshness comes from users: after each drop, "did it release when we said?" is one tap and feeds the confidence score.
- *(v1.5) Got one, clear the rest.* With several reminders out, landing a table should dismiss the remaining alarms in one tap. This is the first thing to add after v1.
- *Share instead of groups.* A reminder is a personal object. "Share" sends a link; anyone who opens it in the app gets the same reminder for the same restaurant and date. The link quietly connects those reminders so that when one person marks "got it," the others get "Sam got a table at Lilia for Oct 10" and can stand down. No group object, no RSVP, no live view — coordination stays in the iMessage thread where it already happens. Reminders are private unless shared.
- *Three separate events.* (1) **Attempt outcome** — right after the drop: "Did you get it?" Got it / No / Still trying, plus one tap for "did it release when we said?" Feeds data freshness, creates a plan, scores nothing. (2) **Plan** — restaurant + date, from "got it" or from an "I have a table" button on any tracked restaurant page (people land tables via cancellation alerts, luck, concierges — not only the reminder). Private by default; becomes the visit card. (3) **Logged visit with booker attribution** — when logging, one extra tap: "Who got the table?" Me / [friend] / walk-in / invited. This is the scoring event.
- *What counts.* A logged visit at a tracked restaurant where you were the booker. Guests don't get credit for Sam's table (Sam does, even if Sam isn't logging); cancelled reservations never count (no visit); walk-ins don't count (it's a reservation crown); it doesn't matter whether the reminder came from the app. Tracked restaurants only — that's the difficulty filter until tiers exist.
- *Confirmation, honestly.* No platform exposes a consumer-side way to verify a booking. Layers: self-report (worthless alone) → the visit must be logged (a fake claim now costs a fake visit) → photo-backed "verified" mark when geotagged photos from that day support the visit (nearly free, the detection pipeline already exists; crown ranks verified first) → friends-only (the real enforcement). If cheating becomes a problem, restrict the crown to verified visits. Build nothing more in v1.
- *Table Getter crown.* One crown per friend circle per month, reset monthly, all-time tally on the profile. No bottom-of-the-list states, ever. Later: difficulty tiers so the crown rewards the hardest tables, not the most; a small role set (Getter / Scout / Regular) only if it earns its place.
- *Flow.* Tracked restaurant page → Remind me → date → calendar event + notification → optional share link → drop → "did you get it?" → plan → visit card → log with "who got the table?" → booker gets credit → monthly crown.
- *Drop-day share card.* "Got it: Carbone · Sat Oct 10 · 8:15 PM" is the emotional peak and the most natural acquisition moment in the app. Make it beautiful.
- Existing standalone trackers (Ez Rez, Reservation Drops, It's a Date, SnagRes, ReservationFinder) prove the demand; none has the social layer or the loop into visits and reviews.

**Lists**
- Make lists a primary tab or a prominent profile section, not a buried feature.
- Export as KML/CSV for Google My Maps plus per-place deep links. Google Maps has no official list-import API, so this will be a little clunky — worth confirming the best path.
- "Friends who also want to try this" on every list item, with a one-tap "let's go" that starts a plan.

**Social & discovery**
- *Group decision mode.* Pick the people; get the intersection of everyone's want-to-try lists plus untried spots everyone is predicted to like. The most common real-world use case, and nobody nails it.
- *Taste-neighbors.* "People who rank like you" beyond your friend graph, so a new user in a thin city still gets signal. Only draws on public profiles.
- *Visible written reviews* with a "helpful" signal that feeds into whose reviews get surfaced in the nearby tab.
- *Neighborhood heat by velocity*, not raw count — surfaces new openings, not just popular incumbents.

**Growth loops**
- *Year-in-review / monthly stats card.* Historically the strongest organic loop for logging apps (Spotify, Letterboxd, Strava). Natural first "unlock."
- *Instagram-story-ready share cards* for every review and list.
- *Public web pages* for profiles and lists — SEO and link-shareable, for users who opt into public. Beli is app-locked; a web presence is a channel they don't have.
- *Widgets:* "friends' latest" and "tonight's pick" on the home screen.

**Contextual recs**
- Condition the Recs tab on occasion (date, group, quick lunch), budget, time, and who you're with. Beli's tags gesture at this but don't drive any surface.

---

## 8. Honest assessment: is there space?

**Short version:** there's space for a better *product*; there's much less space for a better *network* — and the network is what Beli is.

**On your side**
- Your diagnosis is right. The onboarding cliff and logging friction drive drop-off, comparative ranking degrades at scale, and Beli's rec score is widely seen as weak. These are real and Beli has been slow to fix them.
- The "do it better" playbook works in consumer when the incumbent is complacent (Letterboxd vs. IMDb, Strava vs. everything, Linear vs. Jira).
- On-device place detection and AI dish recognition are newly cheap. A review that starts itself is buildable by one person now.
- The reservation-drops feature gives a brand-new user something useful before any friends join, which is the cold-start problem every other app in this category has failed on. The cost is launching in NYC, where Beli is densest.
- Your background (UX research, full-stack React/TypeScript/Go) fits the product side of this problem well.

**Against you**
- Beli isn't dead. 75M+ ratings, fresh external validation in 2026, a growing team. Users who churn because logging is a chore don't churn to a competitor — they churn to nothing. Winning them back means their friends have to move too.
- Features are copyable. The moment "the app noticed where I ate" gets traction, Beli ships it. Your durable edge has to be a better *taste graph* (rec quality) or a community Beli doesn't serve — not a nicer review flow.
- Several small apps are already attempting pieces of this — Truffle (auto-logs from Instagram Stories), Crumble (dish-level ratings, friends-only), Savor, Yummi, Memolli, Bite, Seek Recs, Hooked. None has broken out. The missing ingredient isn't product; it's distribution and density.
- Consumer social has a long history of "better product, no users." This is mostly a distribution problem with a product component, not the reverse.

**My read:** worth building if (a) you pick a wedge Beli can't easily follow — I'd argue dish-level ratings plus group decision-making — and (b) you have a concrete plan for the first 5,000 users in one city. If the plan is "better UX and they'll come," the graveyard says otherwise.

---

## 9. Competitive landscape

- **Direct (social ranking):** Beli — the incumbent. ~5 years old, $5.3M raised, strongest in NYC/Chicago/SF, Gen Z base, word-of-mouth growth, founders on record against in-feed ads.
- **Indie trackers:** Crumble (dish ratings, web app, friends-only), Savor (private dish journal), Truffle (Instagram-story auto-logging), Yummi, Memolli (offline/travel), Mapstr, Bite, Seek Recs, Hooked. Small, fragmented, mostly pre-traction.
- **Giants that own discovery:** Google Maps (saves, lists, sharing, AI summaries — and the most likely to simply add friend-ranking), TikTok and Instagram (where most under-35 discovery actually happens), Yelp.
- **Editorial:** The Infatuation (owned by JPMorgan Chase), Eater, Michelin. Not apps, but they compete for trust.
- **Booking:** Resy (Amex), OpenTable, Tock, SevenRooms. Partners rather than competitors — and the likeliest acquirers of a dining-data company.

**Takeaway:** the field is Beli, a long tail of small dish-level/private trackers, and giants. Nobody yet owns the "social + dish-level + frictionless" corner.

---

## 10. Monetization without ads or eroding trust

**Rule of thumb:** charge users for utility, or charge restaurants for *insight* — never for *placement*. The moment a restaurant can pay to rank higher, the score is worthless.

1. **Premium subscription** (Letterboxd Pro model, ~$4–6/mo): advanced stats, year-in-review on demand, unlimited lists, priority AI logging, export, deep taste-profile, early features. Foodies pay for identity. Likely first revenue. Note the tension with earned unlocks — decide which perks are earned and which are paid, and don't sell what others earn.
2. **Booking referrals.** Reservations through OpenTable / SevenRooms / Tock pay per seated cover. Doesn't touch the rating. Beli is already here.
3. **Restaurant Insights (read-only).** Aggregated, anonymized: which dishes are loved, where ratings dropped after a menu change, how a place compares to its block. Sold to operators and groups. Beli is reportedly exploring this; it's the most valuable data product. Guardrail: no responding, promoting, or influencing scores.
4. **Events & supper clubs.** Ticketed dinners, chef collabs, member-only access at hard-to-get spots; take a cut. Beli does one-offs; this could be systematic.
5. **Reservation hand-off fee.** A small, transparent fee on high-demand reservations passed between users.
6. **Travel.** Paid city packs, or partner hotel/travel bookings when a user logs a trip. Low trust risk.
7. **Corporate.** Teams that entertain clients want vetted lists. Small market, high willingness to pay.
8. **Fintech partnership / acquisition.** Chase bought The Infatuation; Amex owns Resy. Dining data is worth a lot to card issuers. Not a revenue line, but the exit this whole category is pointed at.

**Avoid:** sponsored placement, paid "verified" badges, selling individual-level data, and any restaurant-facing feature that can touch scores.

---

## 11. Next steps

**Weeks 1–2: validation build, not the MVP**

1. **Detection spike.** Run photo-metadata visit detection on your own camera roll and two friends'. Measure hit rate and permission acceptance (full access is needed for automatic scanning on iOS). Below ~60%, search is the product and the widget is a bonus; above ~85%, the widget is the wedge.
2. **Get 15 yeses.** Pick one city and one community (a company, a college, a run club) and get 15 people who eat together to commit to using it with each other. If this is hard, that's the finding.
3. **Throwaway rating-flow prototype** (the slider with live band-mates) in those same people's hands. Measure time-to-log and whether seeing your own places while sliding changes the number people land on.
4. **Five lapsed-Beli interviews** alongside the spike: why they stopped, what would bring them back, whether dish-level matters.
5. **Start the NYC drop-rule sheet.** Restaurant, platform, rule type, window, time, phone number, source, verified date. First 100 over a weekend; it's the data the reservation feature lives on.

**Then: build the v1 in §5h**, in this order — search → rating flow → feed → recent-visits widget → calibration onboarding → reservation drops (widget + multi-date reminder; nothing else in v1).

**Before writing ranking code:** fix the category taxonomy. **Before Google Places becomes the restaurant database:** check per-lookup pricing. **Platform:** native Swift/SwiftUI, iOS only, built primarily with Claude Code (terminal, for logic) and Claude in Xcode (for SwiftUI views). XcodeGen manages the project file; non-UI logic (clustering, place matching, band-mate selection) lives in a Swift package with fast tests; CLAUDE.md pins Swift 6, deployment target, and SwiftUI-only. Backend: Supabase (Postgres/PostGIS, Sign in with Apple, storage) via its Swift SDK; own `places` table seeded from open POI data.

---

## 12. Pre-build to-do (split by who does it)

*Done: Xcode 26.6 with iOS simulator runtime. In progress: Apple Developer Program enrollment.*

**You — can't be delegated**

- [ ] Finish enrollment when Apple emails; add the Apple ID in Xcode → Settings → Accounts
- [ ] Install Claude Code and sign in; enable Claude in Xcode → Settings → Intelligence; one test prompt in each
- [ ] Install Homebrew (needs your password)
- [ ] Create an empty GitHub repo and clone it, or authenticate `gh` so Claude Code can push
- [ ] Decide: app name (check App Store), bundle ID, iOS 18 minimum, photo-permission sentence (Claude drafts options; you pick)
- [ ] Answer: iCloud Photos on this Mac? (yes → Mac CLI spike; no → iPhone, waits on enrollment)
- [ ] Grant Photos access when the spike first runs
- [ ] Recruit the 15 people who eat together — start now
- [ ] Verify every row of the NYC drop-rule sheet (Claude drafts from public sources; you confirm)

**Claude Code — paste decisions, then prompt**

- [ ] CLAUDE.md from your decisions
- [ ] `brew install xcodegen swiftlint`, `.gitignore`, README
- [ ] Repo skeleton: `project.yml`, app target, Core package (Detection / Rating / Places), test target, macOS CLI target — generate, build, tests green
- [ ] Detection acceptance criteria (in CLAUDE.md; you approve thresholds)
- [ ] Fetch + filter open POI data (Overture, US food/drink subset) to SQLite
- [ ] Clustering with synthetic tests
- [ ] PhotoKit reader for the CLI + Vision food check
- [ ] Run against your library; write the spike report; you verify it from memory
- [ ] Commit as it goes

**Gate:** name + bundle ID + permission wording unblocks everything on the Claude Code side.
