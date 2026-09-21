# Wiffaltro

Plastic-ball baseball roguelite where **one run equals one season**.

## Status

The **first Phase 4 Season Shell** now surrounds the vanilla match: main menu,
four-round tryout draft, lineup, ten-game schedule, standings, playoffs and
between-game saves. Run the project, choose **New Season**, and follow the
draft into the season hub; **Exhibition** goes straight into a standalone game.
The shared Mechanics Lab remains available through F2 at safe match boundaries.
Godot 4.7.2 regression coverage includes season progression and camera geometry.
Rendered/hands-on camera, season-flow QC and result-distribution sampling remain open.

For the one-command development check and automatic playtest records, see
[Verification](docs/VERIFICATION.md). After one-time setup, run
`python3 tools/verify.py`.

Canonical docs:

- `docs/SOURCE_OF_TRUTH.md` — gameplay/design baseline
- `docs/TECHNICAL_PREPRODUCTION.md` — architecture and Phase 0–4 engineering baseline

## Technical baseline

- Godot 4.7.2
- typed GDScript
- Mobile renderer
- Jolt 3D physics
- 60 Hz Godot physics
- 240 Hz custom Pitch solver
- Blender → glTF/GLB
- Steam/PC + iOS + Android architecture

Core rule: **Godot owns presentation, collision, and environment physics. Our code owns baseball.**

## Current implementation

The repository now contains:

- main, preseason, draft, lineup, schedule, postgame and season-results menus
- 24 authored two-way players across six clubs, ten games and four-team playoffs
- deterministic AI league scores, standings and validated local season checkpoints
- stable content IDs
- immutable Resource definition types
- explicit ContentManifest + ContentDB
- nine prototype Pitches and two deliveries
- intended-location aiming, fatigue/execution, and Pitch telemetry
- Contact and Power swings with 240 Hz swept, authored contact resolution
- Jolt physical ball-in-play with custom aerodynamics
- starter-field authored hit rules
- automatic Primary Fielder and Pitcher defense
- ghost-base and sacrifice-fly resolution
- complete five-inning match state, counts, batting order, Stamina, mercy, and extras
- role-aware opponent control and automatic camera changes
- per-Pitch effort control
- timed player release, continuous action-mapped aim, and controller basics
- reactive mouse batting on the mathematical contact plane
- one confirmation per new offensive Batter, followed by automatic
  within-at-bat Pitch cadence and a visible Pitcher telegraph
- nonlinear late-game fatigue with plate-reach protection
- clickable four-player pitching-staff management
- full-simulation pause with saved display settings and nine inspection views
- clickable Pitch repertoire with Pitch count, Stamina and fatigue stage
- handed player avatars, independent visible bat actor, and angled batting camera
- deterministic Batter awareness for repeated Pitches and visible locations
- shared hold/release mouse pitching and overhead 3×3 Field Setup
- varied Pitcher rhythm and readable fast/off-speed identity
- post-plate Pitch visibility, hardened back wall, and tighter Fielder/Pitcher defense
- a debug-only Pitch receiver; missed Swings no longer stop the Pitch
- automatic dead-ball flow with player-controlled defensive Pitch tempo
- short automatic game intro and win/loss broadcast sequences
- actionable swing miss feedback and smooth camera direction
- deterministic count-aware opponent decisions and per-play records
- a headless core regression scene
- one integrated Match Mode plus preserved Mechanics Lab scene

## Milestone order

Phase 0 Foundation → Pitch/Bat Lab → Ball-in-Play Lab → complete vanilla match
→ first Season Shell with ongoing human QC → Seasonal Build Systems → Opponents/Fields/
Leagues/Difficulty → Persistent Club Layer → Production and Content Scale.

**Wiffaltro is a working title.**
