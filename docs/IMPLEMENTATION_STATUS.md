# Implementation Status

**Current phase:** Phase 0 — Foundation

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
- [ ] Godot 4.7.2 import/parse run
- [ ] Main scene launched successfully in Godot 4.7.2

The engine-runtime checks remain intentionally unchecked until they have actually been run.

## Next after runtime validation

Begin Phase 1 with the fixed-step Pitch solver and trajectory lab.
