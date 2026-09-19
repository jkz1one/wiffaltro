# Vanilla Match + Mechanics Lab — Phase 3 Milestone Test

This is a functional match simulator and shared debug lab, not a polished game screen.

## What this milestone now contains

- 9 selectable Pitches
- Overhand and Sidearm release profiles
- 240 Hz custom RK2 Pitch simulation
- gravity, drag, spin lift, perforation/asymmetry, and seeded instability
- iterative aim solving to an intended plate location
- execution error and fatigue degradation
- release/plate-speed and aerodynamic movement instrumentation
- Contact and Power swing profiles
- timing/spatial contact resolution
- exit velocity, launch-angle, and spray output
- corrected fatigue degradation and release-speed telemetry
- Jolt physical ball-in-play with custom aerodynamic forces
- starter field Safe, Deep Air, back-wall, and Home Run rules
- automated Primary Fielder and Pitcher defense
- deterministic clean, bobble, deflection, miss, and recovery handling
- ghost-base hit advancement and sacrifice-fly/tag advancement
- four debug camera views
- full five-inning Match Mode with provisional four-player rosters
- batting order, current/on-deck batter, counts, walks, outs, runs, and innings
- Stamina, pitch counts, pitching changes, mercy, extra innings, and game over
- automatic batting, pitching, and ball-in-play cameras
- bounded Pitch effort and outside-zone aiming
- larger visible Contact and Power batting coverage
- preserved Mechanics Lab and debug telemetry

## Shared controls

- `F1`: toggle detailed telemetry and trajectory overlays
- `F2`: switch between Match Mode and Mechanics Lab
- `V`: cycle camera manually

## Match Mode controls

- `Space`: request/throw the next Pitch or continue after a dead play
- `W A S D`: move batting aim, including outside the strike zone
- `Z`: Contact Swing
- `X`: Power Swing
- `1–9`: select from the active Pitcher's repertoire while pitching
- Arrow keys: move the precise Pitch target, including outside the strike zone
- `- / =`: lower / raise Pitch effort from 82–112%
- `Q / E`: previous / next Pitcher between batters
- `F`: cycle Primary Fielder between batters
- `C`: cycle Primary Fielder position through the 3×3 grid
- `[ / ]`: set a minimum fatigue level for focused testing
- `R`: restart the match

## Mechanics Lab controls

- `1–9`: select Pitch
- `Space`: throw selected Pitch
- Arrow keys: move intended Pitch target
- `W A S D`: move batting aim
- `Z`: Contact Swing
- `X`: Power Swing
- `- / =`: lower / raise Pitch effort
- `, / .`: lower / raise execution quality
- `[ / ]`: lower / raise fatigue
- `C`: cycle Primary Fielder position through the 3×3 grid
- `G`: cycle empty / runner-on-third / bases-loaded test states
- `B`: launch the next direct Ball-in-Play diagnostic
- `R`: reset lab conditions

## Pitch keys

1. Overhand Four-Seam
2. Overhand Sinker
3. Sidearm Sinker
4. Overhand Slider
5. Sidearm Slider
6. Eephus
7. Knuckleball
8. Sidearm Riser
9. Drop

## What to look for

At 100% execution / 0% fatigue, different Pitches aimed at the same marker should generally finish around that intended location while taking visibly different paths.

At high fatigue, executed release speed should be visibly lower than nominal release speed. Pitches should generally reach the plate, but velocity, shape, and location should vary materially from throw to throw. Breaking Pitches should sometimes retain usable bite, sometimes miss unpredictably in either axis, and sometimes fail to finish into hittable territory. Repeated tired Pitches should not trace one linear miss pattern or always become center-cut gifts.

The Knuckleball is intentionally less repeatable because its seeded orientation instability is part of the Pitch identity.

For batting, aim the coverage reticle with WASD and press Z or X while the ball is near the plate. The outer cyan rectangle is Contact coverage and the inner orange rectangle is Power coverage. Batter Contact rating scales both regions. Successful contact transfers to the Jolt batted ball, switches to the field camera, activates both defenders, and resolves the play through authored baseball rules.

In Match Mode, the player bats in the top half and pitches in the bottom half. The camera should switch to the correct role before the next Pitch, switch to the field on contact, and return only after `Space` advances the dead play. Counts must persist within a plate appearance, the batter must advance only when that plate appearance ends, and the scoreboard must always show score, inning half, count, outs, bases, current/on-deck batter, Pitcher, pitch count, and Stamina.

Effort changes the speed of every Pitch, including off-speed Pitches. Higher effort should be faster and costlier without making an Eephus, Slider, or Drop feel identical to a Four-Seam.

The yellow line marks the ordinary Safe boundary. The cyan line marks Deep Air. A bouncing ball reaching the back wall is a Double, a wall strike on the fly is a Triple, and a fair airborne ball clearing the wall top is a Home Run. The brown pole is a live object: it should physically redirect the ball without deciding the baseball result by itself.

`B` cycles Grounder, Deep Air, Wall On Fly, and Home Run Arc diagnostics. These bypass Pitch/contact only so field physics and rulings can be inspected deliberately; normal swings still exercise the full contact-to-ball pipeline.

Use `G` to put a runner on third, then produce or diagnose a fly catch at different fielder depths. Shallow catches should normally hold the runner; sufficiently deep catches can score a sacrifice fly.

## Not yet final

All coefficients, field dimensions, fielding thresholds, Pitch identities, swing windows, camera framing, UI, and visual geometry remain tuning/debug content.
