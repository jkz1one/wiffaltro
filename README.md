# Wiffaltro

Plastic-ball baseball roguelite where **one run equals one season**.

## Status

Preproduction is frozen and the **Phase 2 Ball-in-Play Lab** is awaiting Godot 4.7.2 runtime validation.

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
- Contact and Power swings with authored contact resolution
- Jolt physical ball-in-play with custom aerodynamics
- starter-field authored hit rules
- automatic Primary Fielder and Pitcher defense
- ghost-base and sacrifice-fly resolution
- one integrated core-mechanics Lab scene

## Milestone order

Phase 0 Foundation → Pitch/Bat Lab → Ball-in-Play Lab → complete vanilla match.

**Wiffaltro is a working title.**
