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
- smooth camera transitions and dynamic ball-in-play follow
- bounded Pitch effort and outside-zone aiming
- larger visible Contact and Power batting coverage
- player-timed Pitch release influenced by Control and fatigue
- early/late and directional swing feedback
- count-aware deterministic opponent decisions
- deterministic per-play diagnostic records
- one-acceptance automatic at-bat cadence and Pitcher windup telegraph
- pointer-projected mouse batting
- clickable four-player pitching-staff panel
- full-simulation debug pause
- preserved Mechanics Lab and debug telemetry

## Shared controls

- `F1`: toggle detailed telemetry and trajectory overlays
- `F2`: switch between Match Mode and Mechanics Lab
- `F3`: print completed deterministic play records to the Output panel
- `P`: pause/resume the simulation for debug inspection
- `V`: cycle camera manually

## Match Mode controls

- `Space`: begin the next at-bat or acknowledge a completed plate appearance;
  while pitching, hold to start the delivery and release near the meter's
  center mark
- Mouse movement: position batting coverage on the contact plane
- Left click: aim at the pointer and commit a Contact Swing
- Right click: aim at the pointer and commit a Power Swing
- `W A S D` / left stick: continuously move batting aim
- `Z` / controller A: Contact Swing
- `X` / controller X: Power Swing
- `1–9`: select from the active Pitcher's repertoire while pitching
- Arrow keys / right stick: continuously move the Pitch target
- `- / =`: lower / raise Pitch effort from 82–112%
- Click the pitching-staff panel: select any of the four Pitchers between batters
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
- Left click / `Z`: Contact Swing
- Right click / `X`: Power Swing
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

Fatigue should be virtually invisible from 0–50%. Debug telemetry reports both
raw fatigue and effective pressure: 50% raw fatigue is only 2.5% effect. From
50–92%, velocity, movement, and command should worsen progressively. At 92%+
the Pitcher is in the danger band. At 100%, faster Pitches should be clearly
slower, breaking Pitches should lose most of their finish, and edge targets
should frequently leak toward hittable center territory. Location still varies,
but exhausted Pitches must generally reach the plate rather than disappearing
into the dirt.

The Knuckleball is intentionally less repeatable because its seeded orientation instability is part of the Pitch identity.

For batting, move the pointer over the approaching ball and click near the
plate. Left click uses Contact; right click uses Power. Mouse position is
projected onto the same mathematical contact plane used by the WASD and
controller reticle, so both paths exercise the same ContactResolver. The outer
cyan rectangle is Contact coverage and the inner orange rectangle is Power
coverage. Batter Contact rating scales both regions.

In Match Mode, press `Space` once to begin an at-bat. The Pitcher should visibly
set, wind up, and deliver. Taken Pitches, fouls, and non-terminal misses should
flow into the next Pitch automatically after a short readable hold. A walk,
strikeout, hit, out, or inning change waits for `Space` before continuing. The
camera should switch to the field on contact and return for the next role.
Counts must persist within a plate appearance, and the batter must advance only
when that plate appearance ends.

During the player's defensive half, the pitching-staff panel should list all
four players, Stamina, and fatigue state. Selection is enabled only between
batters. Choosing the active Primary Fielder as Pitcher must automatically move
the Primary Fielder role to another player. Middle Center must visibly start
clear of the mound rather than overlap the Pitcher.

While pitching, hold `Space` (or controller A) and release near the center cue.
High-Control, fresh Pitchers should have a more forgiving useful window than
tired, low-Control Pitchers. Early and late releases should reduce command
without allowing any mid-flight steering. Holding beyond the window must
auto-release rather than stall the match.

Missed swings should report whether timing or aim was the dominant error. The
opponent should protect more often with two strikes, take more selectively in
three-ball counts, and avoid feeling like a purely uniform random chooser.

Effort changes the speed of every Pitch, including off-speed Pitches. Higher effort should be faster and costlier without making an Eephus, Slider, or Drop feel identical to a Four-Seam.

The yellow line marks the ordinary Safe boundary. The cyan line marks Deep Air. A bouncing ball reaching the back wall is a Double, a wall strike on the fly is a Triple, and a fair airborne ball clearing the wall top is a Home Run. The brown pole is a live object: it should physically redirect the ball without deciding the baseball result by itself.

`B` cycles Grounder, Deep Air, Wall On Fly, and Home Run Arc diagnostics. These bypass Pitch/contact only so field physics and rulings can be inspected deliberately; normal swings still exercise the full contact-to-ball pipeline.

Use `G` to put a runner on third, then produce or diagnose a fly catch at different fielder depths. Shallow catches should normally hold the runner; sufficiently deep catches can score a sacrifice fly.

## Not yet final

All coefficients, field dimensions, fielding thresholds, Pitch identities, swing windows, camera framing, UI, and visual geometry remain tuning/debug content.
