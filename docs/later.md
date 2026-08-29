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
