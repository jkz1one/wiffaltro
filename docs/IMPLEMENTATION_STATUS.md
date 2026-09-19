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
- [x] Godot 4.7.2 runtime validation of Phase 1 visible milestone — user screenshot confirmed visible ball, trajectory trace, strike-zone crossing, and telemetry on 2026-09-18

The current launch target is deliberately a debug value chosen to place the nominal Four-Seam through the visible zone before PitchAimSolver exists. It is not the final aiming model.


## Phase 1 runtime observation

User screenshot from Godot 4.7.2 confirmed the first visible Pitch Lab milestone is functioning:

- Four-Seam crossed the displayed strike zone at approximately x 0.06 m / y 1.20 m
- trajectory trace rendered
- live ball position/speed telemetry rendered
- measured plate speed was approximately 26.4 mph
- measured flight time was approximately 0.783 s

The large velocity loss is a tuning/calibration question, not evidence that the solver pipeline failed. Before pitch families are balanced, the Lab should add better comparative instrumentation so release speed, plate speed, displacement, and pitch-to-pitch differences can be evaluated directly.


## Phase 1 expanded milestone — implementation complete, runtime validation pending

Implemented after the first Four-Seam smoke test:

- [x] iterative intended-location PitchAimSolver
- [x] deterministic trajectory simulator for aim/instrumentation
- [x] execution-quality perturbation
- [x] fatigue-driven velocity/spin/control degradation
- [x] seeded orientation instability for knuckle-style movement
- [x] prototype drag recalibration
- [x] Overhand Four-Seam
- [x] Overhand Sinker
- [x] Sidearm Sinker
- [x] Overhand Slider
- [x] Sidearm Slider
- [x] Eephus
- [x] Knuckleball
- [x] Sidearm Riser
- [x] Drop
- [x] Pitch selection controls
- [x] movable intended Pitch target
- [x] release speed / plate speed instrumentation
- [x] aerodynamic movement comparison against a no-spin/no-asymmetry baseline
- [x] three debug camera views
- [x] Contact Swing profile
- [x] Power Swing profile
- [x] movable batting aim
- [x] spatial/timing ContactResolver
- [x] exit velocity / launch angle / spray output
- [x] debug contact launch vector
- [x] Godot 4.7.2 parse/import validation for expanded milestone — user screenshots confirmed clean runtime on 2026-09-18
- [ ] hands-on pitch-family differentiation test
- [ ] hands-on aim/execution/fatigue test
- [x] hands-on Contact/Power swing functionality test — user screenshots confirmed both swing paths produce contact telemetry

Do not mark the unchecked items complete until the expanded build has actually been run in Godot.


## Phase 1 screenshot evidence

User-provided Godot screenshots confirmed:

- selectable Pitch UI is functioning
- pitch target and batting aim markers render
- multiple camera views render correctly
- trajectory traces are visible in both catcher and side views
- Eephus and Overhand Slider produce visibly different flight timing/shapes
- Contact Swing generated contact telemetry (42% quality, 35.4 mph EV in the captured Eephus example)
- Power Swing generated contact telemetry (84% quality, 80.9 mph EV in the captured Slider example)
- launch angle and spray outputs render
- the solver, aim system, and contact resolver are connected end-to-end

Balance/feel remain provisional. Pitch-family differentiation and fatigue feel should continue to be judged during later playtests rather than blocking Phase 2 architecture.
