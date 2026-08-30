# Later — deliberately out of v1

Things confirmed out of scope for v1. See also the "Not on this roadmap (v1.5+)" list at the bottom of `docs/roadmap.md`.

## Recent-visits widget (was roadmap item 9) — deferred 2026-08-29

The always-on detection surface: scan on app open, home-screen cards for detected
unrated visits, "wrong place" alternatives, local notification after 2 days.

**Why deferred:** measured on-device (iPhone, real photo resolution, one-year
library): 8 high-confidence detections per year and ~3 "X or Y?" asks per week.
The high tier is capped by candidate density, not by the food signal — "exactly
one candidate within 75 m" is structurally rare where people actually eat. Too
thin to carry an always-on widget, and wrong-visit notifications are the most
trust-damaging failure mode. Precision was excellent (every high correct,
ambiguous right in top 2–3), which is why detection stays in calibration
onboarding (roadmap item 10), where confirm-or-skip is the whole interaction.

**Revisit when:**
- Friend-visit data exists to build ranking priors (places friends log get
  boosted — needs the core loop shipped and used), and/or
- The "clearly dominant candidate" relaxation is tried: treat nearest as
  single-candidate when it's ~3× closer than the runner-up. Lifts the show
  count; trades against currently-spotless precision, so test against the
  spike report first.

The detection pipeline itself is built and tested (`Core/Detection`), shared by
the Spike CLI and the app's debug screen — the widget is UI + scan scheduling +
notifications on top of it.

## Server search quality (noted 2026-08-29, during item 5)

Server search is name-prefix + distance; Apple's blended results are visibly
better ranked. Cheap upgrades when it starts to matter: `pg_trgm` for
typo-tolerant fuzzy matching (one migration), word-level prefix matching
("carota" finds "Via Carota"), and a friends-rated-here ranking boost once
visit data exists.


## Reservation drops (was roadmap item 11) — cut from v1, 2026-08-29

Product decision: not necessary for v1. The rule engine, drop-rules CSV
workflow, restaurant-page widget, and calendar/notification CTA are all
unbuilt; the `drop_rules` and `reminders` tables exist in the schema and stay
dormant. Revisit if testers ask for it.


## Detection in onboarding (was part of item 10) — cut 2026-08-29

The full client-side stack was built and measured on-device: clustering,
frequent-location exclusion, server place matching, candidate dedupe,
dominant-nearest geometry, Vision meal filter, and OCR receipt/sign matching
(`uniqueTextMatch`). At city POI density it yields ~zero certain cards, and the
product bar for onboarding is certainty — ambiguous cards with pickers tested
poorly, wrong cards worse.

The missing ingredient is a behavioral prior (which candidate do humans
actually pick at this GPS blob) — the thing Foursquare's snap-to-place has and
scraped photos can't provide. **The app is building that dataset itself**:
every logged visit is a check-in. Revisit detection (onboarding cards and/or
the recent-visits widget) when there's enough visit data to rank candidates by
it; licensed place data (Foursquare-class) is the buy-side alternative if
traction justifies it. All pipeline code lives on in Core/Detection with tests,
plus the Spike CLI and the app's debug tab.
