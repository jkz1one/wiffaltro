# Core Mechanics Lab — Phase 2 Milestone Test

This is a debug lab, not a polished game screen.

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

## Controls

- `1–9`: select Pitch
- `Space`: throw selected Pitch
- Arrow keys: move intended Pitch target
- `W A S D`: move batting aim
- `Z`: Contact Swing
- `X`: Power Swing
- `, / .`: lower / raise execution quality
- `[ / ]`: lower / raise fatigue
- `C`: cycle Primary Fielder position through the 3×3 grid
- `G`: cycle empty / runner-on-third / bases-loaded test states
- `B`: launch the next direct Ball-in-Play diagnostic
- `V`: cycle camera
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

For batting, aim the cyan marker with WASD and press Z or X while the ball is near the plate. Successful contact now transfers to the Jolt batted ball, switches to the field camera, activates both defenders, and resolves the play through authored baseball rules.

The yellow line marks the ordinary Safe boundary. The cyan line marks Deep Air. A bouncing ball reaching the back wall is a Double, a wall strike on the fly is a Triple, and a fair airborne ball clearing the wall top is a Home Run. The brown pole is a live object: it should physically redirect the ball without deciding the baseball result by itself.

`B` cycles Grounder, Deep Air, Wall On Fly, and Home Run Arc diagnostics. These bypass Pitch/contact only so field physics and rulings can be inspected deliberately; normal swings still exercise the full contact-to-ball pipeline.

Use `G` to put a runner on third, then produce or diagnose a fly catch at different fielder depths. Shallow catches should normally hold the runner; sufficiently deep catches can score a sacrifice fly.

## Not yet final

All coefficients, field dimensions, fielding thresholds, Pitch identities, swing windows, camera framing, UI, and visual geometry remain tuning/debug content.
