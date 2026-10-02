# Frozen Rope: explicit gap-selection candidate

Status: **unapproved, isolated experiment**, authored 2026-10-02 before prototype code.
This is a proposal for Working testing, not selected gameplay tuning or balance approval.
Sources: Equipment/Sponsors v18, retained planning blueprint v114 EU/EV; current Alley
calibration follows the user-selected Working amendment in SOURCE_OF_TRUTH. The repository
blueprint is preserved unchanged. Frozen Rope is not added to stock by this experiment.

## Proposed rule

| Choice | Concrete candidate |
| --- | --- |
| Depth band | Minimum to maximum Z of the active field's available defensive anchors, strictly in front of its back wall. Current fields: 8.5–19.5 m. Invalid/empty band disables assistance. |
| Lane | Straight planar segment from the contact-origin ray's near-band crossing to its far-band crossing. No predicted landing point or flight time. |
| Openness | Smallest planar distance from any current fieldable defender to that segment, divided by band length. Include the actual pitcher and primary fielder; one defender also works. No movement, reach, ratings or reaction information. |
| Search | Original plus offsets in 0.5° steps on both sides, including the exact quality cap, each clipped to the legal sector interval; reject points belonging to another sector and deduplicate. At most 17 directions. |
| Quality cap | 4° × smoothstep(0.80, 1.00, actual quality). Only fair ordinary Contact above 0.80; no Power, miss or foul help. |
| Sectors | Three equal angular thirds of the authored fair wedge. For the current 42° half-angle: boundaries −42°, −14°, +14°, +42°. Center includes both inner boundaries. Pull/opposite names use the committed stance; world-space sectors mirror exactly. |
| Fair geometry | Never exceed the authored half-angle. Both band endpoints must also satisfy the field's ordinary planar fair-point rule, including its existing 0.45 m tolerance. The original direction must already be valid. |
| Obstacles | Reject rays whose contact-to-far-band segment intersects an expanded static obstacle footprint. Expand by actual ball radius. Ignore obstacle height conservatively; no predicted overflight. Unknown/unsupported obstacle geometry disables comparison. |
| Improvement/ties | Require score improvement greater than 0.000001 band lengths. Scores within that tolerance tie; choose smallest adjustment. Equally good, equally small opposite adjustments retain original, regardless of enumeration order. |
| Failure | Missing defenders, invalid geometry, obstructed original lane or no better candidate retains original. Never reroll. |

These choices intentionally use the field's existing authored defensive depth instead of
new stadium-size constants. The nearest-defender score measures static clearance only.
It does not estimate catch probability. A centered pitcher can dominate it, and exact
symmetry deliberately produces no assistance. Half-degree sampling can change the chosen
angle discretely even though the quality cap ramps smoothly. Those tradeoffs require review.

## Integration boundary after selection

Production currently has one primary fielder and a fieldable pitcher. Snapshot their actual
positions before `_start_ball_in_play`, which reapplies defensive assignments. The receiver
is not an additional fieldable defender. Snapshot static collision geometry, not decorative
meshes or future routes. The backyard contains a physical box pole; Commons has no pole.
Their matching field dimensions alone cannot demonstrate portability to a smaller field.

Normal contact and the selected 0.75 vertical flattening happen first. Gap rotation is
separate from elevated-angle qualification: perfect ordinary Contact launches at 7° and
must still be able to receive the proposed 4° horizontal envelope. Preserve vertical
velocity, horizontal speed, quality, spin and classification; publish one final launch.
No subsequent steering. No change to AI observation rights or swing selection.

After selecting this rule, implement the final stable identity, 20-Cash paid purchase,
16% fair Power exit penalty, prospective twenty-Gap-game access, frozen historical catalog
signatures, save validation, committed contact evidence, replay, collection, shared Equipped
details and safe live-sale retirement together. A replay must consume the committed choice,
not resnapshot a moved defense. This prototype is not that integration or a physics playtest.

## Verification and decision

Run `python tools/verify.py --only frozen-rope-candidate --only season-gap-driver --only regressions`.
Final run `20261002T074749542616Z` passed **10/10 checks** under Godot 4.7.2, with no
warnings/errors: seven common gates and those three scenes. The exact output is
`FROZEN_ROPE_CANDIDATE_RESULTS.json`. The new scene records 31,999 checks, 3,618 artificial
geometry/quality combinations (2,962 improved), and 36 ordinary resolver contacts
(18 improved). These are controlled samples, not player hit rates or balance evidence.

| Controlled example | Original spray | Selected spray | Meaning |
| --- | ---: | ---: | --- |
| One defender 1 m right of center at depth 14 m | 0° | −4° | Clearance grows from 1.000 m to 1.974 m. |
| One defender exactly centered | 0° | 0° | Equal left/right alternatives preserve original. |
| Two defenders equally flanking an already open lane | 0° | 0° | No nearby improvement. |
| Pitcher at actual mound and deep-left fielder | 3° | 7° | Static clearance improves; no catch prediction. |
| Obstacle blocks the best nearby ray | 0° | −1.5° | Blocked candidates are rejected. |
| Uniform 0.4× and 1.8× fields | 0° | −4° | Normalized score and selection stay consistent. |

Tests also cover altered center-anchor depth, narrow/wide fair wedges, both mirrored
stances, single/multiple defenders, weak/foul/Power/lower-tier exclusions, invalid geometry,
snapshot value copying, deterministic selection, serializable committed choice, speed
preservation and unmodified vertical velocity. JSON choice round-trip is not integrated
match-save/replay evidence. The production contact object itself is never mutated.

Early runs caught an incorrect test field ID, 32-bit angular-bound rounding, a typed-array
return issue and an exact-float assertion. Inspection then found near-duplicate candidates
on the same side being mistaken for opposite-side symmetry. The final test explicitly
regresses that quality-cap edge; only genuinely opposite equal choices cancel assistance.
Sector bounds use 64-bit scalar arrays. Only prototype/test files changed during correction.

The prototype does not yet cover live defender/obstacle snapshot extraction, committed
match evidence, physical games, human/AI live ownership, purchases or save migration.
Those belong to the integrated item slice after selection. Select this candidate as
**Working** before enabling it; do not mistake these engineering checks for balance approval.
No production source imports the prototype. Build/save/Career versions and playable item
counts remain unchanged. Native rendered review and human feel acceptance remain required.
