# Season camera and AI revision

Date: 2026-09-23. Branch: `season-qc-camera-batting`. Replaces the automatic
contact-cut implementation in the first season video QC pass.

## Research basis

Camera references and the distinction between broadcast editing and playable
coverage are in [SEASON_CAMERA_RESEARCH.md](SEASON_CAMERA_RESEARCH.md).

[Saijo, Fukuda and Kashino, 2025](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2025.1514301/full)
found different dependencies on visual information for timing and swing adjustment
in a VR batting experiment. This supports separating those tasks. Our reaction
windows, noise levels and correction limits are game tuning, not measured human
constants or a validated biomechanical model.

## What changed

- Removed the automatic transform replacement at contact and the later visibility
  recovery teleport. Translation and rotation now approach a chosen shot with
  bounded movement. Soft contact receives less pullback and widening than hard
  contact. Grounders retain a view toward home; estimated airborne carry earns
  an elevated lateral view. A scoring-line crossing does not select a new shot.
- Camera routes stay in front of the back wall, anticipate nearby narrow uprights,
  retain their selected side, and hold the resolved frame after the play ends.
- AI timing plans begin earlier. Visible velocity changes estimate pitch curvature;
  bounded aim correction uses delayed observations. No future trajectory or hidden
  target is read. Separate seeded streams drive timing, aim and approach.
- Reduced repetition benefits: total awareness caps at 0.50, shared location memory
  at 0.12, and neither removes execution error. Pitch speed changes affect rhythm.
- AI decisions now run on flight substeps rather than render frames. All physical
  swings use the player's shared aim limits, closing the AI's unlimited-aim gap.

## Contact audit

Each version uses 38,880 deliveries: nine pitch types, five horizontal locations,
three contact ratings, fresh/repeated/mixed history, both pitcher hands, and 48
matched seeds per hand. The batter is right-handed in this matrix; the production
regressions and additional matchup audit cover both batter hands. Same pitches,
execution seeds and decision seeds are used before and after. Foul contact counts
as contact. Fair contact is not a base hit: fielders and scoring are outside this
harness. Simulation stops at the production plate boundary.

The table pools center and near-edge targets (x = -0.35, 0, +0.35 m), excluding
waste targets. It reports **contact per swing**, not per pitch or batting average.

| Contact rating | Fresh before | Fresh after | Repeated before | Repeated after |
| --- | ---: | ---: | ---: | ---: |
| 3 | 49.9% | 50.5% | 69.8% | 48.7% |
| 5 | 69.8% | 63.5% | 87.5% | 64.3% |
| 8 | 91.2% | 83.6% | 98.9% | 83.1% |

These supersede the smaller preliminary samples discussed during implementation.
Repetition may also increase swing frequency and power-swing selection, so it need
not increase conditional contact percentage for every rating. The expanded sample
preserves weak-batter viability while removing near-guaranteed elite contact.

## Pitching and sequence audit

Another 2,592 deliveries cover pitcher ratings 3/8, good/poor releases, fresh/empty
stamina, grouped/alternating fastball-slider-eephus sequences, 0-0/0-2/3-0 counts,
and both batter hands. These are controlled counts and six-pitch memory windows,
not complete plate appearances. Targets alternate x = ±0.32 m; pitcher hand is
right. Grouped and mixed sequences have the same total pitch mix, but order and
execution seeds are not perfectly crossed: small differences are descriptive.

- Fresh: mean plate speed 15.5 m/s; mean target error 0.022 m; contact on 59.9% of swings.
- Poor Release: mean plate speed 15.3 m/s; mean target error 0.224 m; contact on 50.6% of swings.
- Exhausted: mean plate speed 12.3 m/s; mean target error 0.327 m; contact on 66.5% of swings.

Poor command can reduce contact by moving pitches out of the zone; it is not
therefore better pitching. Takes, balls and count leverage matter. Existing
pitch-quality tests separately cover all nine pitch types and fatigue levels.
The rating-3/8 pitcher comparison is modest in this pooled matchup sample; this
pass does not establish full-season difficulty or claim every rating has an ideal
statistical effect. No pitch-force, release-meter or fatigue curve was changed.

Raw cells: [contact audit](SEASON_AI_CONTACT_AUDIT.csv),
[matchup audit](SEASON_AI_MATCHUP_AUDIT.csv). Reproduce with pinned Godot 4.7.2:

```sh
godot --headless --path . res://tools/audits/ai_pitching_audit.tscn
godot --headless --path . res://tools/audits/ai_pitching_matchups.tscn
python3 tools/verify.py
```

## Validation

The camera audit passes 7,680 continuous tracking samples with zero scenery
occlusions and zero out-of-frame samples. A further 96 aerodynamic flight cases
cover both parks, both roles and 30/60/120 fps: zero occlusion, zero out-of-frame
samples and zero defensive grounder reversals. Continuity includes the first
contact frame. At 60 fps, the worst sampled rotation step is about 1.58 degrees;
these are engineering limits, not human comfort thresholds.

The physical batting regression covers 2,880 mirrored deliveries across both
pitcher and batter hands. A new reach regression verifies that requesting a
three-meter-wide aim cannot move the physical bat outside player reach.
Final clean-suite verification passed all 29 steps on 2026-09-23 using Godot 4.7.2. The run used a disposable source copy and included parsing, lint, regression scenes, soak checks, and main-scene startup. Logs: `builds/verification/20260923T050130337873Z/`.
Rendered playback was unavailable in this environment. Headless visibility and
motion limits do not establish human comfort. Human QC should compare a short
roller, a roller past Double, a hard liner, a short popup, a deep fly, and a live
inside/outside pitch sequence. Full-season balance remains open.
