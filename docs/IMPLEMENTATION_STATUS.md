# Implementation Status

**Current phase:** Phase 2 — Ball-in-Play Lab implementation; Godot runtime validation pending

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

The initial engine smoke test was run by the user in Godot 4.7.2 and reported clean. That validation predates the Phase 2 changes documented below.


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


## Phase 1 expanded milestone — runtime validated; fatigue correction pending retest

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
- [x] hands-on pitch-family differentiation test — user reported the Pitching and hitting feel promising on 2026-09-18
- [ ] hands-on corrected fatigue/hanger test
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


## Fatigue/hanger correction — revised after playtest, runtime validation pending

The 2026-09-18 playtest found that fatigue mostly drove Pitches into the dirt while preserving too much velocity and movement. The implementation now:

- [x] applies a stronger high-fatigue velocity penalty
- [x] degrades spin, perforation movement, and instability authority
- [x] increases command error with Pitch difficulty
- [x] compensates only the extra vertical drop caused by velocity loss
- [x] leaves attenuated movement and command error uncorrected so hangers emerge without a center-target override
- [x] displays nominal release speed, executed release speed, and predicted plate speed separately
- [x] samples velocity, spin, perforation movement, and command degradation independently per Pitch
- [x] uses each Pitch's control difficulty to scale two-axis command dispersion
- [x] adds seeded heavy-tail fatigue lapses, with extra vulnerability for breaking Pitches
- [x] avoids a deterministic fatigue-to-center rule while allowing tired breaking Pitches to leak over the plate
- [ ] Godot 4.7.2 hands-on fatigue/hanger retest


## Phase 2 Ball-in-Play Lab — implementation complete, runtime validation pending

Implemented in repository:

- [x] ContactResult to BattedBallLaunch transition
- [x] Jolt RigidBody3D batted ball with CCD and contact monitoring
- [x] batted-ball drag, spin lift, and orientation-dependent perforation force
- [x] authored starter FieldDefinition and graybox field
- [x] physical ground, back-wall, and live-object collisions
- [x] mathematical Safe, Deep Air, and Home Run segment crossings
- [x] BallPlayState, BallPlayResolver, and BallPlayOutcome
- [x] Out / Single / Double / Triple / Home Run resolution
- [x] nine persistent Primary Fielder anchors
- [x] simple trajectory prediction and automatic fielder movement
- [x] deterministic clean / bobble / miss thresholds
- [x] physical bobble deflections and limited recovery attempts
- [x] automatic restricted-envelope Pitcher defense
- [x] pure ghost BaseState hit advancement
- [x] deterministic tag/sacrifice-fly advancement
- [x] fourth field camera and automatic contact camera switch
- [x] four direct ball-in-play diagnostic launches
- [x] player-facing telemetry for result floor, defense, result, runs, and bases
- [x] all GDScript passes `gdparse` and `gdlint` static checks on 2026-09-19
- [ ] Godot 4.7.2 import/parse validation
- [ ] Godot 4.7.2 Ball-in-Play Lab runtime validation

Static parsing is not engine validation. Do not treat Phase 2 as runtime-tested until the Godot checks above are completed.
