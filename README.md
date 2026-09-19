# Wiffaltro

Plastic-ball baseball roguelite where **one run equals one season**.

## Status

The **Phase 3 vanilla-match simulator** has passed multiple hands-on match
smokes. The current timed-contact, automatic-cadence, and broadcast-flow
revision awaits Godot 4.7.2 runtime validation.

Canonical docs:

- `docs/SOURCE_OF_TRUTH.md` — gameplay/design baseline
- `docs/TECHNICAL_PREPRODUCTION.md` — architecture and Phase 0–3 engineering baseline

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
- automatic within-at-bat Pitch cadence and visible Pitcher telegraph
- nonlinear late-game fatigue with plate-reach protection
- clickable four-player pitching-staff management
- full-simulation debug pause
- handed player avatars, independent visible bat actor, and angled batting camera
- deterministic Batter awareness for repeated Pitches and visible locations
- shared hold/release mouse pitching and overhead 3×3 Field Setup
- varied Pitcher rhythm and readable fast/off-speed identity
- post-plate Pitch visibility, hardened back wall, and tighter Fielder/Pitcher defense
- a visible Pitch receiver; missed Swings no longer stop the Pitch
- automatic dead-ball flow with player-controlled defensive Pitch tempo
- short automatic game intro and win/loss broadcast sequences
- actionable swing miss feedback and smooth camera direction
- deterministic count-aware opponent decisions and per-play records
- a headless core regression scene
- one integrated Match Mode plus preserved Mechanics Lab scene

## Milestone order

Phase 0 Foundation → Pitch/Bat Lab → Ball-in-Play Lab → complete vanilla match
→ sport fun gate → Season Shell → Seasonal Build Systems → Opponents/Fields/
Leagues/Difficulty → Persistent Club Layer → Production and Content Scale.

**Wiffaltro is a working title.**
