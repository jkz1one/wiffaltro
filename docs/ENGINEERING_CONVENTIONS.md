# Engineering Conventions

These rules apply to implementation unless a documented decision changes them.

## Language and data

- Use typed GDScript.
- Treat authored `Resource` definitions as immutable at runtime.
- Keep mutable match/season state out of definition resources.
- Stable content IDs use lowercase dotted namespaces such as `pitch.overhand_four_seam`.
- Save data references stable IDs, never resource paths.

## Units and coordinates

Internal simulation uses SI units: meters, seconds, kilograms.

Field-local axes:

- `+Y` = up
- `+Z` = home plate toward center field
- `+X` = home plate toward right field

A pitcher at the mound faces home plate (`-Z`).

Pitch authoring should use semantic arm-side/glove-side directions where possible rather than hardcoded world left/right.

## Architecture

- Definitions: `Resource`
- Mutable simulation state: `RefCounted` where practical
- Presentation/collision/animation: Nodes and scenes
- Keep Autoloads minimal.
- No global gameplay EventBus.
- Godot owns presentation/collision/environment physics; game code owns baseball rulings.

## GDScript quality

- New public methods must have typed parameters and return types.
- Prefer explicit property types when inference is not obvious.
- Warnings are treated as actionable; do not normalize warning spam.
- Avoid giant manager scripts and deep inheritance trees.
- Prefer small pure helpers for math and rule resolution.

## Testing honesty

Do not claim code is runtime-tested unless it has actually been opened/run under the pinned Godot version.

Static review and repository inspection are not substitutes for an engine parse/import test.
