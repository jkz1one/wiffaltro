# Alley family calibration decision

Measured 2026-10-02 using Godot 4.7.2. **Experiment only; no playable tuning change.**
User priority is to finish the shop and its items before another larger system.

## Current contract and blocker

Equipment/Sponsors v18, lines111–128, and retained Blueprint v114 EU/EV,
lines19407–19560, specify clean Contact flattening toward16°, strengths0.25/0.50/0.75,
and Power penalties8/12/16%. Source of Truth's 2026-09-28 Alley entry explicitly
requires a separately reviewed design decision before widening eligibility or altering
core swing tuning. No newer source supersedes that gate. Values remain Working;
smoothing remains an unapproved Proposal. Frozen Rope's small-gap direction is Approved,
but lane scoring, field-relative depth and candidate spacing are still unspecified.

The actual Contact profile has attack angle7°. The resolver uses:

- quality = 1 − length(normalized horizontal, vertical, depth error);
- launch = 7° + 32° × normalized vertical error, within ordinary launch clamps.

At quality>=0.65, vertical error cannot exceed0.35, so launch cannot exceed18.2°.
Current flattening begins at18° and reaches full angular weight at20°; quality weight
simultaneously approaches zero at0.65. This is why the current effect is negligible.
Increasing strength alone cannot make the two remaining Bat tiers useful.

## Measured comparison

The fine sweep resolves100,001 positive vertical-error samples per tier, with centered
horizontal contact and perfect timing. This is the maximum-quality envelope for each
reachable launch, not a simulated player distribution. Values below are sampled maxima,
not mathematical exact extrema or measured hit-rate improvements.

| Flattening strength | Current16° target, entry18–20° | Candidate10° target, entry12–14° |
| --- | ---: | ---: |
| Alley0.25 | 0.000042763° | 1.658227° |
| Gap Driver0.50, experimental only | 0.000085526° | 3.316455° |
| Frozen Rope0.75, flattening only | 0.000128289° | 4.974682° |

Current maximum was measured near quality0.653080 / launch18.101442°. Candidate
maximum was near quality0.697920 / launch16.666563°. These describe angular change
only. They do not establish carry, defender outcomes, fairness between Bats or fun.

## Concrete decision to review

Recommend testing **item-local target10°, smooth entry12–14°**, retaining the existing
quality0.65–0.70 shoulder,38–40° upper falloff, tier strengths and Power penalties.
Only qualifying fair Contact changes; normal Contact attack angle stays7°. Already-low
hits, weak contact, fouls and whiffs are not improved. Full qualifying15° contact would
become13.75°/12.5°/11.25° at the three strengths. No added speed, changed spray, timing
allowance, quality, spin or guaranteed hit is proposed.

This recommendation is **not Approved and not active in gameplay**. User acceptance
would select a Working test candidate, not approve balance. Keep the historical A02
receipt identity and frozen catalog signatures when implementing a versioned mapping;
do not silently alter old serialized catalog bytes. Old paid copies, migration replay,
live-sale retirement and prospective progression require the normal integration slice.
The retained original A02 identity audit already exists in Source of Truth; this pass
does not allocate new tier IDs or start counting historical Alley use.

Frozen Rope still requires a separately authored bounded gap-scoring contract. The
current two field presets have the same scoring dimensions, so testing those alone
cannot establish portability to smaller/asymmetric fields or construction obstacles.
No gap score, depth band, sector division or candidate spacing was invented here.

## Reproducible engineering evidence

Run `python tools/verify.py --only alley-calibration --only season-mapped-gear --only regressions`.
Run20261002T062747379436Z passed10/10 checks: seven common gates plus these three scenes.
The new measurement scene performs:

- 300,003 fine-sweep resolver samples over three strengths;
- 29,478 normalized3D error-grid samples, across Contact ratings0/5/10 and both stances;
- 108 normal swept-contact encounters, across incoming speeds12/24/36m/s, the same
  ratings/stances, and six vertical offsets;
- candidate boundary continuity, no weak/low-contact rescue, speed magnitude and
  horizontal-direction preservation; normal batted-ball launch continuity;
- authored-resource neutrality and unchanged ten earned Gear definitions.

The grid contains8,514 fair samples;54 are affected by the candidate. Those counts are
an artificial uniform error grid, **not activation probability or player performance**.
The candidate is isolated inside `src/tests/alley_calibration_test.gd`; production does
not reference it. Existing mapped-Gear verification covers runtime ownership/migration,
Power penalty and UI. Core regressions cover the preserved gameplay baseline.

The runner writes `alley-calibration.json` alongside its logs. The committed
`ALLEY_CALIBRATION_RESULTS.json` is the exact parsed measurement output from the run.
No warnings/errors were emitted. No new complete physical game, native rendered review,
human visual/feel acceptance or full-suite pass is claimed. The historical intermittent
exit-zero-before-marker issue remains open; it did not occur in this run.

Build39/save43/Career19/opponent policy2 are unchanged. Content remains23/25 Gear,
35/35 sponsors, five tactical supplies, three learned abilities and one transformation.
Whole-project estimate remains approximately74%, not release readiness.
