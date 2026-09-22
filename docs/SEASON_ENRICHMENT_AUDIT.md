# Season enrichment audit and decisions

2026-09-21. Baseline: main `937ce2f5b2dcd5925dbc66241907f95f3d30791f`.
Implements the user's ten-point list; the captain idea stays in `ENRICHMENT_NOTES.md`.

## Physical handedness correction — 2026-09-22

The human Casey Rivers recording exposed an axial-spin reflection bug in
left-handed pitches. The earlier enrichment audit checked visible batting hands
and pitch IDs but did not verify vertical pitch identity. Correcting that physical
bug changes the trajectory inputs used by the AI-read comparison below; its
historical measurements must not be used as current results.

The same 80-fixture-per-family comparison after correction gives:

| Pitch | Mean arrival error, old → current read | Two-strike offers, old → current read |
| --- | --- | --- |
| Four-Seam | 0.055 → 0.089 m | 74 → 74 / 80 |
| Overhand Slider | 0.753 → 0.100 m | 8 → 67 / 80 |
| Sidearm Slider | 0.685 → 0.086 m | 8 → 68 / 80 |

The visible-motion estimate still improves these breaking-ball fixtures, but it
is not superior to the old instantaneous-position heuristic for this straight
fastball fixture. The regression now bounds all three mean errors below 0.12 m
and retains the relative-improvement check for sliders. Production AI batting
logic and difficulty weights are unchanged. These are perception checks, not
hit-rate calibration or proof of a fair difficulty curve. See `VERIFICATION.md`
for paired physical tests and human-QC limits.

## Research informing the pass

- Microsoft's [text-display guidance](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101)
  supports readable defaults and avoiding information loss. Applied here as
  visible ratings, full stat names and mostly 18–22 px menu text at 720p.
  Text-scaling options and accessibility conformance are not claimed.
- Microsoft's [contrast guidance](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/102)
  and [UI navigation guidance](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/112)
  inform dark solid card backgrounds, light text, an explicit selection marker,
  focus highlighting, consistent footer actions and keyboard-operable controls.
  Comparing three cards uses the same rating order and scale; hover is optional.
- David Graham's [An Introduction to Utility Theory](https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter09_An_Introduction_to_Utility_Theory.pdf)
  describes scoring choices from multiple contextual factors and using weighted
  selection to avoid a single rigid action. This informs a small authored
  pitching model with count, signature, category and speed-change preferences,
  rather than a neural model or an omniscient trajectory optimizer.
- MLB's [Swing/Take visualization](https://baseballsavant.mlb.com/visuals/swing-take)
  separates swing decisions by attack region. We likewise distinguish taking
  a hittable strike from declining an obvious waste pitch; neither is equivalent
  to overall contact ability. Its real-baseball rates are not Wiffaltro targets.
- MLB's [Game Strategy Explorer](https://baseballsavant.mlb.com/game-strategy-explorer)
  treats count as relevant context for expectancy. Our count-dependent strike
  versus expansion choices are design heuristics, not copied probabilities or
  a claim of mathematically optimal pitching.
- [Godot's save documentation](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)
  supports JSON and `user://` persistence inside the game. Our version validation,
  reconstruction and prior-checkpoint backup are project-specific safeguards.

## Ten decisions and implementation

1. **Season-start GUI:** clear Season/Exhibition entry cards, concise setup stages,
   league summary and an actual Relaxed/Standard/Tactical strategy selector.
   No pretend shop, venue or achievement controls.
2. **Lineup stats:** all seven ratings appear in a comparison grid beside names
   and B/T. Repertoires are visible beneath it; role selectors identify the starter
   and Primary Fielder. Up/down buttons reorder without changing assigned people.
3. **Draft:** three consistent player cards with rating bars and numbers, handedness,
   pitching style and real arsenal. Selecting is separate from confirming the pick.
   The chosen-roster strip remains visible, and confirmation stays in the footer.
4. **Lineup timing:** freely edit before every game; lock batting order on start.
   A once-per-game reorder is not introduced: with four cycling players it could
   duplicate or skip turns unless a different batting-order rule were designed.
   Defense changes remain between Batters, not subject to that batting-order lock.
5. **Handedness:** the pool was not all left-handed, but the visible boxes were
   reversed relative to the catcher-facing camera. Corrected world/screen mapping,
   mirrored bat rig, camera offset, feedback and AI inside/outside together.
   The new pool has 10/48 left throwers, 46/48 matching default hands and two
   switch hitters. No ambidextrous pitching. Switch-side choice locks before
   windup and stays locked for the plate appearance. The scorebug shows Bats R/L.
6. **Fielder identity:** defense already used the selected player's Fielding and
   throwing hand. Added a direct named picker in Field setup, with Fielding visible;
   its identity and rating are checked against the actual controller. No new
   defensive-position stats or League variants are needed for this baseline.
7. **AI batting:** actual code compared pre-plate X/Y with the strike zone. The
   replacement estimates arrival from current visible motion and gravity. Existing
   chase probabilities, two-strike protection and execution spread remain. It can
   still take a strike, chase, misread a break or swing through a ball.
8. **AI pitching:** preference-weighted owned arsenal, count-aware attack/expansion,
   speed changes and individual Power/Breaking/Corners/Balanced identities.
   Breaking specialists can repeat their signature; no forced alternation.
   Difficulty and modest calendar progression change tactics, not hidden stat power
   or rubber-banding. Future authored clubs can override these player tendencies.
9. **Rare arsenals and pool:** 48 named authored players, only 24 active per season.
   Most have two or three Pitches; two have four and one has five. At most one
   specialist appears in a new twelve-card draft, and none is guaranteed.
   The full pool is currently eligible; collection unlocks remain a future system.
10. **Persistence:** Godot already owned local season saves. Schema 2 preserves
    pool order and AI replay inputs, migrates schema 1, retains a prior valid
    checkpoint and reports recovery. Saves include picks, lineup, difficulty and
    final scores, not an unfinished live game. Cloud saves and career history
    are not silently implied by this checkpoint system.

## Measured evidence and limitations

Godot 4.7.2 tests sampled 300 new drafts: 172 had one rare arsenal and 128 had
none; all 48 characters appeared across the sample. This is finite sample
coverage, not a promised fixed appearance percentage.

Across 1,200 seeded pitching decisions, the fixture attacked the zone 1,120
times at 3–1 versus 649 at 0–2. A Breaking specialist chose its signature 867
times. Edge targets increased from 432 with quality 0 to 879 with quality 1.
These test direction and personality, not optimal strategy or actual strikes.

For 80 center-targeted fixtures per family, both throwing hands, the old current
position read versus the new visible-motion estimate produced:

| Pitch | Mean arrival error, old → new | Two-strike offers, old → new |
| --- | --- | --- |
| Four-seam | 0.412 → 0.098 m | 40 → 73 / 80 |
| Overhand slider | 0.632 → 0.094 m | 17 → 63 / 80 |
| Sidearm slider | 0.589 → 0.082 m | 24 → 65 / 80 |

These are perception/decision fixtures, not hit-rate or human F3 calibration
samples. No Contact/Power, field boundary, fatigue or aerodynamic coefficient
was retuned. Human testing must still assess strike-taking, genuine chases,
swing-and-miss variety, rare-player value and early-season approachability.

Camera regression now checks the actual screen side for both hands, not just
mutual agreement among mislabeled coordinates. Rendering/comfort remains a
human gate. Menus have automated bounds and interaction checks, not a claim of
finished art, screen-reader support, controller-hardware certification or mobile UX.
