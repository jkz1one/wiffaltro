# Implementation Status

**Current phase:** Phase 1 — Pitch/Bat Lab

## Implemented in repository

- [x] Godot 4.7.2 project baseline
- [x] Mobile renderer selected
- [x] Jolt selected explicitly
- [x] 60 Hz physics baseline
- [x] physics interpolation enabled
- [x] collision-layer names established
- [x] Git/Godot ignore rules
- [x] frozen design and technical docs
- [x] stable content ID validation
- [x] Resource definition base
- [x] DeliveryProfileDefinition
- [x] BallAeroProfileDefinition
- [x] BallSetupDefinition
- [x] PitchDefinition
- [x] PlayerDefinition
- [x] ContentManifest
- [x] ContentDB
- [x] PitchState
- [x] PitchLaunchParameters
- [x] field/pitcher coordinate helper
- [x] minimal trajectory debug-draw helper
- [x] prototype Overhand delivery resource
- [x] prototype standard ball/fresh-ball resources
- [x] prototype Overhand Four-Seam resource
- [x] debug player resource
- [x] Pitch/Bat Lab bootstrap scene

## Validation status

- [x] Repository structure inspected through GitHub
- [x] Cross-file resource paths reviewed statically
- [x] Godot 4.7.2 import/parse run — user-reported clean on 2026-09-18
- [x] Main scene launched successfully in Godot 4.7.2 — user-reported clean on 2026-09-18

The initial engine smoke test was run by the user in Godot 4.7.2 and reported clean. The current scene is intentionally only a bootstrap, so there is not yet a visible gameplay test.

## Next after runtime validation

Begin Phase 1 with the fixed-step Pitch solver and trajectory lab.


## Phase 1 first visible milestone

Implemented in repository:

- [x] 240 Hz fixed-step RK2 PitchFlightSolver
- [x] gravity + quadratic drag
- [x] spin/Magnus-style lift
- [x] orientation-dependent perforation/asymmetry force
- [x] nominal PitchLaunchBuilder
- [x] visible PitchFlightActor
- [x] live trajectory trace
- [x] graybox mound / plate / strike zone
- [x] automatic prototype Overhand Four-Seam throw
- [x] SPACE repeat throw
- [x] R clear/reset
- [x] live speed/position/flight-time readout
- [ ] Godot 4.7.2 runtime validation of Phase 1 visible milestone

The current launch target is deliberately a debug value chosen to place the nominal Four-Seam through the visible zone before PitchAimSolver exists. It is not the final aiming model.
