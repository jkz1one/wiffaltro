# Pitch/Bat Lab — Phase 1 Milestone Test

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
- three debug camera views

## Controls

- `1–9`: select Pitch
- `Space`: throw selected Pitch
- Arrow keys: move intended Pitch target
- `W A S D`: move batting aim
- `Z`: Contact Swing
- `X`: Power Swing
- `, / .`: lower / raise execution quality
- `[ / ]`: lower / raise fatigue
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

Raising fatigue or lowering execution should create increasing misses, velocity/spin loss, and hanging/flattened shapes.

The Knuckleball is intentionally less repeatable because its seeded orientation instability is part of the Pitch identity.

For batting, aim the cyan marker with WASD and press Z or X while the ball is near the plate. The current milestone stops at contact math; the ball does not yet enter full ball-in-play physics.

## Not yet final

All coefficients, Pitch identities, swing windows, camera framing, UI, and visual geometry remain tuning/debug content.
