# Stable field coverage and strike-zone timing

**Camera status:** Unpublished prototype, not a visually accepted solution. The
latest user clarification requires preserving offensive camera behavior and
better differentiation of small contact from deep flight. See
[CAMERA_REDESIGN_RESEARCH.md](CAMERA_REDESIGN_RESEARCH.md), which supersedes the
camera direction below. Fixed lens and same-side coverage are not requirements
for the next design. The AI audit remains a separate record.

Date: 2026-09-24. Base: published main `f1dc209`. Branch: `season-stable-field-camera`.

The user reported that camera comfort had regressed again and AI hitters still
felt too automatic on strikes. Passing visibility and continuity tests did not
validate either experience. This pass replaces the prior roaming coverage path
and tests AI timing against the actual production swing window.

## What the references establish

- [MLB 15 The Show's official manual](https://playstation-doc.net/j/theshow15/ps3/option2.html)
  distinguishes Dynamic, Medium, High and Broadcast fielding views. That supports
  choosing a consistent playable view; it does not document proprietary camera
  algorithms or the behavior of the latest edition.
- [Super Mega Baseball 4 Update 3](https://www.ea.com/news/update-3-patch-notes)
  narrowed the special line-drive camera to plays where it helps judge an infield
  jump. The official indexed text was available; a special angle should earn its
  use by improving a fielding decision.
- [Seminole Productions' coverage assignments](https://sempro.cci.fsu.edu/training/diamond-sports/)
  describe wide ball-follow coverage with field context and center-field widening
  on balls up the middle. These are assigned camera positions, not instructions
  to fly one camera across the field on contact.

Our implementation is an adaptation of those principles, not a reproduced MLB
The Show or SMB camera algorithm. No new comparative gameplay footage was viewed.
Mets-style dramatic editing remains relevant to between-play presentation.

## Camera changes

The old system combined ball-relative translation, a carry-driven side change,
lens expansion, and a 14 m extra lateral destination near a pole. Capping each
frame's motion did not prevent a long, disorienting journey.

The replacement opens one consistent rig per player side. Contact strength sets
the amount of field coverage. Live field of view stays constant. Lateral opening
is capped at four metres, and position / angular speed are bounded. The framing
includes ground context. Acquired height is retained through bounces and descent.
No scoring-line crossing, launch direction or obstacle proximity selects an orbit.
These are current shot choices, not a restriction on what cameras may do after
pitch release. No camera movement modifies the stored batting aim.

For the occasional obstructing venue mesh, a private alpha material keeps the
ball readable while retaining a prop silhouette. Physics remains unchanged. The
original material is restored when clear or when leaving live coverage. This
avoids moving the whole view around a pole. It uses material alpha because
[Godot's instance transparency is ignored by the Mobile renderer](https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html).
Alpha compositing and subjective visibility still need native visual review.

## AI changes

The previous 12–24 ms base timing variation was small relative to a contact
swing's 155 ms active window and a power swing's 130 ms window. In the matched
baseline production zone fixture, only four of 1,414 swings had a timing miss.
Aim scatter was doing almost all the work of preventing contact.

Plans now begin roughly 0.30–0.36 seconds before contact. Timing variation has a
55–70 ms base, modified by skill, speed, pitch difficulty and awareness. Changes
in observed speed have a stronger signed rhythm effect. A very late plan starts
before the receiver handoff so an attempted late swing reaches physical
resolution instead of disappearing from the decision record. Earlier planning
also exposes uncertainty in the extrapolated flight. The 12 cm mean-read
regression remains in place.

These are game-balance parameters, not empirically measured human distributions.
There is no forced strikeout, post-contact reroll or automatic inside advantage.
Count-based swing decisions, aim scatter, power selection and player contact
geometry retain their previous formulas. A well-placed pitch can still be hit.

## Measurement

`src/tests/ai_zone_test.gd` drives 1,944 actual match launches: three pitch types
(four-seam, slider, drop), nine zone locations, three contact ratings, both
matching handedness pairs, and 12 seeds per cell. Counts include 0–0 and 0–2.
Pitcher stamina and batter/inning identity are explicitly reset. The fixture
classifies actual plate crossings; its audit-only trajectory forecast never goes
to the batter model. These are controlled deliveries, not complete games.

Contact includes fouls; it is not batting average. Per-location counts are small
and paired, so the CSV supports diagnosis, not narrow confidence claims.

| Contact rating | Before contact/swing | After contact/swing | Before timing misses/swings | After timing misses/swings |
| --- | ---: | ---: | ---: | ---: |
| 3 | 51.7% | 35.4% | 2/474 | 38/480 |
| 5 | 68.2% | 47.7% | 2/468 | 38/486 |
| 8 | 83.3% | 70.9% | 0/472 | 34/484 |

All 1,944 delivered pitches in this controlled grid crossed the actual zone.
Contact rates pool center, edges and corners. Strong hitters still make more
contact, but strikes now produce meaningful early/late misses. This deliberately
changes balance and needs playtesting, especially for low-rated opponents.

Per-location results: `SEASON_STABLE_AI_ZONE_AUDIT.csv`. The same test fails its
new timing-miss requirements against the unmodified published baseline. A second
matched model/physical-contact audit covers 38,880 deliveries per version, all
nine pitch types, five horizontal targets, three ratings and three familiarity
conditions; results are in `SEASON_STABLE_AI_CONTACT_AUDIT.csv`. The two audits
have different pitchers, seeds and sampling grids and should not be pooled.


## Remaining validation

The camera audit covers 7,680 path samples plus 96 aerodynamic flight scenarios
across both venues, both roles, and 30/60/120 fps. Checks include the first contact
frame, ball framing, fixed lens, lateral bounds, no defensive reversal, and
occluder material restoration without a collision change. The added ground-reference
check also passed for all 96 flight scenarios.

All 30 clean-suite verification steps passed with Godot 4.7.2, including the new
production zone test, reads, chase, both live matches, match soak and existing
regressions. Run: `builds/verification/20260924T025943002941Z/`. The subsequent
camera-only test adds the ground-reference assertion without changing runtime
code; log: `builds/stable-camera-ground.log`. No native visual approval is claimed.

Native rendering is unavailable here: a portable Xvfb attempt could not create
display sockets. Headless projection and material tests do not establish human
comfort or rendered alpha quality. Review short grounders, hard liners, popups,
and deep flies at normal speed before calling the camera solved. Full-season
balance also remains open. No progression blueprint changes are included.
