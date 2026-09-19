# Wiffaltro

Plastic-ball baseball roguelite where **one run equals one season**.

## Status

Preproduction is frozen and **Phase 0 Foundation** is underway in Godot 4.7.2.

Canonical docs:

- `docs/SOURCE_OF_TRUTH.md` — gameplay/design baseline
- `docs/TECHNICAL_PREPRODUCTION.md` — architecture and Phase 0–3 engineering baseline

## Technical baseline

- Godot 4.7.2
- typed GDScript
- Mobile renderer
- Jolt 3D physics
- 60 Hz Godot physics
- planned 240 Hz custom Pitch solver
- Blender → glTF/GLB
- Steam/PC + iOS + Android architecture

Core rule: **Godot owns presentation, collision, and environment physics. Our code owns baseball.**

## Current foundation

The repository now contains:

- stable content IDs
- immutable Resource definition types
- explicit ContentManifest + ContentDB
- Pitch and player definition scaffolding
- physical Pitch runtime-state scaffolding
- a prototype Overhand Four-Seam, fresh ball setup, and debug player
- the initial Pitch/Bat Lab scene

## Milestone order

Phase 0 Foundation → Pitch/Bat Lab → Ball-in-Play Lab → complete vanilla match.

**Wiffaltro is a working title.**
