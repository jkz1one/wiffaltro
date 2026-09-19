# Plastic-Ball Baseball Roguelite — Technical Preproduction

**Version:** v0.1.4
**Status:** FROZEN BASELINE WITH FATIGUE, CADENCE, AND INPUT AMENDMENT
**Scope:** Project architecture, Pitch simulation, batting/contact, ball-in-play, vanilla match
**Companion doc:** `SOURCE_OF_TRUTH.md`

---

# 1. Technical Objective

Build the core sport so that:

- pitching is highly tunable and distinctive
- batting is skill-driven and readable
- physical fields matter
- baseball rules remain deterministic and testable
- mobile is a first-class architectural target
- later roguelike systems can modify the sport without rewriting it

Governing architecture rule:

**Godot owns presentation, collision, and environment physics. Our code owns baseball.**

---

# 2. Engine Baseline

- Godot 4.7.2
- typed GDScript
- Mobile renderer
- Jolt 3D physics
- Godot physics tick: 60 Hz initially
- custom Pitch integration: 240 Hz internal substeps initially
- physics interpolation enabled
- Blender → glTF/GLB
- Git/GitHub
- SI units internally: meters, seconds, kilograms

Do not upgrade the engine mid-production casually.

Patch upgrades may be evaluated deliberately. Major/minor engine upgrades require a concrete benefit and regression check.

---

# 3. Architectural Layers

Use three explicit conceptual layers:

## Definition

Authored, reusable content.

Examples:

- PlayerDefinition
- PitchDefinition
- DeliveryProfileDefinition
- BallAeroProfileDefinition
- BallSetupDefinition
- SwingProfileDefinition
- FieldDefinition
- FieldFeatureDefinition

Use Godot `Resource`.

Definitions are treated as immutable at runtime.

## Simulation / State

Mutable game state and pure-ish logic.

Examples:

- PlayerSeasonState
- PlayerMatchState
- PitcherState
- PitchState
- PitchLaunchParameters
- SwingIntent
- ContactResult
- BattedBallLaunch
- BaseState
- BallPlayState
- BallPlayOutcome
- MatchState

Prefer `RefCounted` for state classes that do not need scene-tree behavior.

## Presentation / Engine Actors

Things that need Nodes, transforms, collision, animation, rendering, or UI.

Examples:

- PitchFlightActor
- BattedBallBody
- BatterActor
- PitcherActor
- FielderController
- MatchController
- UI

Do not collapse all three layers into one Node script.

---

# 4. Content Definitions

Initial minimum definition hierarchy:

```text
DefinitionBase
├── PlayerDefinition
├── PitchDefinition
├── DeliveryProfileDefinition
├── BallAeroProfileDefinition
├── BallSetupDefinition
├── SwingProfileDefinition
├── FieldDefinition
├── FieldFeatureDefinition
└── StrikeZoneDefinition
```

Later:

```text
PlayerAbilityDefinition
GearDefinition
EndorsementDefinition
LeagueDefinition
DifficultyDefinition
StadiumPartDefinition
```

## Stable IDs

Every definition has a stable content ID.

Examples:

```text
pitch.overhand_four_seam
pitch.sidearm_sinker
player.sal
field.backyard_01
```

Save data must reference stable IDs, not resource paths.

---

# 5. Content Manifest

Create one explicit `ContentManifest.tres`.

It references all authored content.

`ContentDB` loads the manifest and builds lookup dictionaries such as:

```text
pitch_by_id
player_by_id
field_by_id
ball_setup_by_id
```

Do not rely on arbitrary runtime directory scanning as the primary content-registration system.

---

# 6. Autoload Policy

Initial Autoloads:

```text
ContentDB
```

Add `SaveService` only when persistent saves begin.

Avoid giant global managers.

Do not begin with:

```text
GameManager
BaseballManager
PhysicsManager
GlobalEventBus
```

Match-local systems remain match-local.

---

# 7. Match-Local Architecture

A match owns:

```text
MatchController
MatchEventHub
MatchState
BallPlayResolver
FieldingResolver
TagAdvanceResolver
```

When the match ends, its event system and transient simulation state die with it.

Later modifiers may subscribe to match-local events without turning the entire game into a global singleton architecture.

---

# 8. Repository Layout

Recommended starting structure:

```text
/project.godot

/docs/
    .gdignore
    SOURCE_OF_TRUTH.md
    TECHNICAL_PREPRODUCTION.md

/src/
    core/
        ids/
        math/
        rng/

    content/
        definitions/
        manifest/

    gameplay/
        pitching/
        batting/
        ball_in_play/
        fielding/
        match/

    presentation/
        characters/
        ball/
        camera/
        ui/

    labs/
        pitch_bat_lab/
        ball_in_play_lab/

    tools/
        debug/

    tests/
        unit/
        integration/

/assets/
    environment/
    characters/
    audio/

/art_source/
    .gdignore
```

Keep working Blender source in `art_source/`.

Export clean GLB/glTF assets into `/assets/`.

---

# 9. Coordinate and Unit Conventions

Use SI units internally.

World convention should be documented immediately and never casually changed.

Recommended field-local convention:

```text
+Y = up
+Z = from home plate toward center field
+X = toward right field
```

For Pitch authoring, also define a semantic pitcher-relative frame:

```text
arm_side
up
toward_plate
```

Handedness maps the semantic frame to world space.

Do not author Pitch movement using hardcoded world-left/world-right when “arm side” or “glove side” is the real meaning.

---

# 10. Pitch Definition

A game-facing **Pitch** includes pitch type + delivery/arm slot.

A `PitchDefinition` should carry authored tactical/physical identity such as:

```text
id
display_name
category
delivery_profile
nominal_velocity
nominal_spin_rate
nominal_spin_axis
hole_orientation
control_difficulty
execution_difficulty
stamina_cost
rarity
tags
aero_recipe/profile references
```

Exact final schema should remain lean until the first solver is running.

Do not duplicate data merely because it may become useful later.

---

# 11. Ball Setup vs Pitch

Keep Pitch identity and ball condition separate.

## PitchDefinition

Describes release recipe / intended pitch identity.

## BallSetupDefinition

Describes the aerodynamic object/condition.

Possible ball parameters:

- drag multiplier
- perforation-force multiplier
- stability
- surface asymmetry
- scuff profile

This allows the same Pitch to behave differently with different ball setups without duplicating the Pitch definition.

---

# 12. Pitch Runtime State

Conceptual baseline:

```gdscript
class_name PitchState
extends RefCounted

var position: Vector3
var velocity: Vector3

var orientation: Quaternion
var angular_velocity: Vector3

var elapsed_time: float
var pitch_id: StringName
var seed: int
```

The solver should operate on explicit state rather than reading arbitrary Nodes or player objects.

---

# 13. Pitch Launch Builder

Separate gameplay stats from physical simulation.

`PitchLaunchBuilder` combines:

- PitchDefinition
- DeliveryProfile
- PlayerMatchState
- BallSetupDefinition
- player handedness
- Natural Delivery compatibility
- aim
- effort
- execution input
- Stamina/fatigue
- applicable modifiers

and produces:

```text
PitchLaunchParameters
```

The aerodynamic solver receives physical launch parameters.

It should not know whether the Pitch came from Sal, an Endorsement, or an Exhausted state.

Prototype effort is a bounded per-pitch input. It scales launch velocity and
modestly changes movement authority before nominal aim solving. Higher effort
also raises Stamina cost and introduces a small execution penalty. The initial
lab range is 82–112%; exact limits and curves remain tuning values.

---

# 14. Pitch Simulation Ownership

Do **not** use `RigidBody3D` as the authoritative Pitch-flight model.

During pitch flight:

```text
PitchFlightActor : Node3D
```

owns a `PitchState`.

The custom solver advances the Pitch.

Godot/Jolt provides world collision queries.

This preserves precise authorship over:

- velocity
- drag
- lift
- spin
- effective spin
- hole orientation
- unstable movement
- exaggerated plastic-ball behavior
- fictional future Pitches

without fighting rigid-body integration.

---

# 15. Pitch Timestep

Initial baseline:

```text
Godot physics: 60 Hz
Pitch solver: 240 Hz
Pitch substep: 1 / 240 s
```

Each 60 Hz physics tick performs four Pitch substeps.

Reason:

A fast pitch travels too far per 60 Hz tick for comfortable trajectory integration, while making the entire game run at 240 Hz is unnecessary.

Collision detection still sweeps the whole movement segment.

## Convergence test

Before treating 240 Hz as permanent, compare:

- 120 Hz
- 240 Hz
- 480 Hz

For extreme prototype Pitches.

If 240 → 480 produces materially visible plate-position differences, either improve the integrator or increase the Pitch step rate.

---

# 16. Pitch Integrator

Use a fixed-step midpoint / RK2 integrator initially.

Per substep:

1. evaluate acceleration at current state
2. estimate midpoint state
3. evaluate acceleration at midpoint
4. advance position/velocity
5. advance orientation
6. sweep ball shape from previous → next position
7. process any collision/event

Avoid:

- render-delta-driven Euler
- unnecessary RK4 complexity before evidence requires it

---

# 17. Pitch Forces

Initial force families:

## Gravity

Standard downward acceleration.

## Drag

Quadratic drag based on relative airflow.

Conceptually:

```text
F_drag ∝ -|v_rel| * v_rel
```

## Spin / Magnus-type force

Use active/effective spin and spin axis to derive transverse lift.

Do not use:

```text
more spin = more Break
```

as a simplistic rule.

## Plastic-ball perforation / asymmetry force

Model orientation-dependent aerodynamic bias separately from conventional spin lift.

This is required because perforated plastic balls can generate strong orientation-dependent movement and can curve even with low spin.

Total Pitch acceleration is therefore conceptually:

```text
gravity
+ drag
+ spin-induced lift
+ perforation/asymmetry force
+ optional wind
```

---

# 18. Ball Orientation

Maintain ball orientation explicitly.

Conceptually:

```text
orientation: Quaternion
angular_velocity: Vector3
```

The aerodynamic profile knows the perforated-hemisphere/hole axis in local ball space.

Each solver step transforms that axis to world space and evaluates its relationship to airflow.

This enables physically grounded orientation-dependent plastic-ball movement.

---

# 19. Knuckleball Model

Do not implement arbitrary random lateral impulses.

Prototype model:

- low spin
- low orientation stability
- small seeded deterministic wobble torque
- orientation changes
- changing orientation changes asymmetric aerodynamic force
- resulting path becomes irregular

Seed the behavior so identical launch conditions are reproducible for debugging.

---

# 20. Eephus Model

No special fake trajectory system.

Use:

- very low launch speed
- high arc
- normal gravity
- low conventional break
- low Stamina cost as gameplay data

The same solver handles it.

---

# 21. Pitch Aim Semantics

The player's aim cursor represents the **intended plate-crossing location**.

It does not directly represent initial launch direction.

Use:

```text
PitchAimSolver
```

to solve for the nominal initial launch direction that makes a perfectly executed Pitch reach the desired target.

Conceptually:

1. choose target point
2. guess launch direction
3. simulate nominal Pitch
4. measure crossing error
5. adjust direction
6. repeat a small number of iterations

Because this is one ball and a tiny search problem, runtime cost is negligible.

---

# 22. Execution Error and Hangers

Apply execution/fatigue error **after** nominal target solving.

Velocity degradation must not create a dominant artificial dirt bias. The
execution layer may apply a bounded vertical release-angle compensation for
the extra gravity drop caused by lost velocity. This compensation preserves
the intended vertical reach only; it does not correct lateral movement,
attenuated break, release error, or later command error.

Possible degraded launch properties:

- spin magnitude
- spin axis
- hole orientation
- release position
- launch direction
- velocity

Fatigue uses a back-loaded severity curve rather than raw linear Stamina loss.
The initial match bands are:

- 0–35% fatigue: no mechanical penalty
- 35–50%: trace variance, reaching only 2.5% effect at 50%
- 50–92%: progressive nonlinear degradation
- 92–100%: steep danger band

Velocity, movement authority, release position, and launch direction receive
separate seeded rolls. Faster Pitches have more velocity to lose; breaking
Pitches lose a larger share of spin/finish. Heavy-tail lapses are reserved for
the upper fatigue band instead of appearing throughout an ordinary outing.

A fatigued Slider aimed outside may fail to achieve expected movement and
remain over the plate. At high fatigue, a continuous seeded command-regression
term also pulls misses toward the heart, weighted most strongly for edge and
corner targets. This supplements degraded stuff and variable execution; it
does not replace every target with the zone center.

That naturally creates a hanger.

A final reach guard prevents velocity loss and error from sending exhausted
Pitches below the simulation world before the plate plane. It does not force a
strike: low, high, and lateral misses remain valid. At 100% fatigue, Pitches
should still arrive but resemble batting practice through lost speed, flattened
shape, and frequent hittable location.

Avoid special-case code like:

```text
if stamina == 0:
    pitch_to_center()
```

---

# 23. Pitch Collision

During custom Pitch flight, use sphere/shape sweep queries along:

```text
previous_position -> next_position
```

for relevant solid interactions.

Do not rely on discrete point overlap.

The Pitch is not a Jolt rigid body during this phase.

---

# 24. Strike-Zone Crossing

Represent the plate/strike-zone plane mathematically.

Determine:

- crossing position
- Ball/Strike
- pitch location
- any relevant visual crossing data

from the sampled/swept trajectory.

Keep strike logic separate from presentation.

---

# 25. Batting Authority

The rendered bat is **not** authoritative for gameplay contact.

Use a mathematical arcade contact model.

The bat animation exists for presentation and synchronization.

Do not determine whether a swing succeeds based on tiny collider overlap at engine physics frequency.

---

# 26. Batting Coordinate Frame

Define a plate-local contact frame.

Recommended semantic axes:

- horizontal across zone
- vertical
- depth toward/away from Pitcher

The player's aim sets a target contact region in the plate plane.

---

# 27. Swing Profiles

Initial authored profiles:

```text
ContactSwingProfile
PowerSwingProfile
```

Potential fields:

```text
contact_radius_x
contact_radius_y
contact_depth
swing_duration
time_to_sweet_spot
bat_speed
attack_angle
exit_velocity_multiplier
```

## Contact

- larger valid contact volume
- longer timing forgiveness
- lower EV ceiling

## Power

- smaller valid volume
- tighter timing
- higher EV ceiling

Keep these values in data, not hardcoded into Batter logic.

---

# 28. Swing Intent

On swing input, record:

```text
swing_type
start_time
aim_point
handedness
```

plus any minimal modifier state required.

This becomes `SwingIntent`.

For mouse input, project the pointer ray onto the authored contact plane. The
projected plate-local X/Y becomes `aim_point`, and the mouse button chooses the
Swing Profile. This preserves the same mathematical ContactResolver authority
used by keyboard/controller aim; mouse picking never substitutes a physics
collider for contact resolution.

---

# 29. Contact Resolver

During the valid contact interval, compare the Pitch trajectory against the moving virtual contact region.

Evaluate:

- spatial error
- timing error
- swing phase
- bat/ball vertical relationship

Select the best valid encounter.

Outcomes can include:

- miss
- foul/weak contact
- solid contact
- near-perfect/perfect contact

Exact thresholds remain tuning data.

---

# 30. Spray Direction

Derive spray from actual swing/contact timing rather than a separate magic directional rule.

Early contact occurs farther in front:

- more pull

Centered timing:

- more center

Late contact occurs deeper:

- more opposite field

Handedness mirrors direction appropriately.

---

# 31. Launch Angle

Derive launch tendency from bat/ball vertical relationship and swing attack angle.

Simplified concept:

- contact below ball center → more lift/backspin
- contact near center → line-drive tendency
- contact above ball center → ground-ball tendency

This produces understandable arcade outcomes while retaining a physical basis.

---

# 32. Exit Velocity

Use a tunable physically inspired transfer model rather than full material-deformation simulation.

Conceptually:

```text
base transfer from incoming pitch speed
+ effective bat speed
```

then modify by:

- contact quality
- sweet-spot quality
- Power stat
- swing profile
- Gear/modifiers

Design distinction:

- Power increases ceiling/effective bat speed
- Contact preserves quality under imperfect timing/position

---

# 33. Batted-Ball Spin

`ContactResolver` also produces initial batted-ball angular velocity.

Inputs may include:

- vertical offset
- horizontal offset
- attack angle
- timing
- smaller inherited component from Pitch spin

Output:

```gdscript
class_name BattedBallLaunch
extends RefCounted

var position: Vector3
var velocity: Vector3
var angular_velocity: Vector3
var orientation: Quaternion
var contact_quality: float
```

This object marks the transition from Pitch flight to ball-in-play.

---

# 34. Ball-in-Play Ownership

Architecture boundary:

```text
CUSTOM PITCH SOLVER
        ↓
CONTACT RESOLVER
        ↓
BATTED BALL LAUNCH
        ↓
JOLT RIGID BODY
```

After contact, emergent physical collision becomes desirable.

---

# 35. BattedBallBody

Use:

```text
BattedBallBody : RigidBody3D
```

with:

- CCD enabled
- contact monitoring enabled as needed
- custom aerodynamic force application
- simplified gameplay collision proxies for very thin geometry when required

Godot/Jolt handles:

- ground impact
- wall/fence bounce
- poles
- roofs
- trees
- ramps
- later physical objects

Our code still owns baseball rulings.

---

# 36. Batted-Ball Aerodynamics

Continue applying authored ball forces during ball-in-play:

- gravity
- drag
- spin lift
- plastic-ball asymmetry
- wind if present

Jolt handles collision response.

Do not surrender ball flight identity entirely after contact.

---

# 37. Baseball Rules vs Physics

Critical rule:

**A collision does not itself decide the baseball result.**

Physics emits physical events.

`BallPlayResolver` interprets those events according to the current FieldDefinition and baseball rules.

Example:

Hitting a wall is not universally a Double.

The resolver checks:

- whether the ball grounded first
- which wall/region was hit
- current field ground rules
- whether a more final result already occurred

---

# 38. FieldDefinition

Gameplay geometry is authored in field-local coordinates.

Home plate is the logical origin.

The definition may include:

- fair territory
- foul boundaries
- ordinary safe-hit boundary
- deep-air Double regions
- back wall/fence
- HR boundary
- fielder anchors
- ground-rule regions
- relevant return/throw destinations

The visual/collision mesh and scoring geometry are related but not identical.

This allows gameplay boundaries to be tuned without remodeling Blender geometry.

---

# 39. Important Rule Boundaries

For critical non-solid rule boundaries, mathematically test the ball segment:

```text
previous_position -> current_position
```

against the boundary.

Do not rely exclusively on thin `Area3D` triggers for:

- HR plane
- safe-hit boundary
- foul-line/rule crossing
Use physical collisions for solid objects.

Use mathematical crossing tests for rule geometry.

---

# 40. BallPlayState

Track the minimum state needed to resolve the play, such as:

```text
is_fair
has_grounded
first_ground_position
result_floor
last_defender_touch
caught
dead
catch_position
catch_time
```

`result_floor` conceptually supports:

```text
NONE
SINGLE
DOUBLE
TRIPLE
HOME_RUN
```

Do not overgrow this object until the actual prototype requires more.

---

# 41. Baseline Hit-Result Flow

Examples:

## Ground ball beats defense

- result floor = NONE
- crosses ordinary safe boundary
- floor becomes SINGLE
- fielder later controls it
- final result = SINGLE

## Fly ball hits wall on the fly

- has_grounded = false
- wall-on-fly rule triggers
- result = TRIPLE

## Bouncing ball reaches wall

- has_grounded = true
- reaches back wall
- result = DOUBLE

## Clears HR boundary on fly

- result = HOME_RUN
- play becomes dead

---

# 42. Primary Fielder

Presentation actor:

```text
FielderController : CharacterBody3D
```

Gameplay authority comes from a separate planner/resolver.

The physical fielder collider does not automatically determine catch success.

---

# 43. Fielder Planner

`FielderPlanner` predicts useful intercept opportunities from:

- current ball position
- velocity
- spin
- expected flight
- current fielder anchor/start position
- fielder movement capability

The planner chooses a reachable intercept.

After unexpected bounces/collisions, re-plan.

Initial predictor only needs to be good enough for:

- flight until first ground
- simple bounce/roll approximation

Do not build a perfect general future-physics solver before the prototype needs it.

---

# 44. Fielder Positioning

`FieldDefinition` exposes nine initial anchors:

- Shallow Left
- Shallow Center
- Shallow Right
- Middle Left
- Middle Center
- Middle Right
- Deep Left
- Deep Center
- Deep Right

The user's pre-pitch strategic choice selects one anchor.

Authored anchors must respect a Pitcher exclusion radius. The center lane may
use a field-specific depth offset so Middle Center remains selectable without
overlapping the mound.

After contact, the fielder moves according to the planner.

---

# 45. Fielding Resolver

At the interaction moment, evaluate:

- distance/reach
- ball speed
- arrival timing
- bounce state
- reach difficulty
- Fielding stat
- Fielding Ability if relevant

Base result bands:

- clean
- bobble
- miss

Prefer readable deterministic thresholds over hidden RNG in the baseline.

Randomness can be introduced later only when it improves the game.

---

# 46. Bobble / Deflection

A bobble should physically affect the ball.

`DeflectionModel` may alter:

- speed
- direction
- spin

based on the interaction.

Baseline rule:

A bobbled fair ball normally establishes at least a Single.

Recovery may still prevent further advancement.

---

# 47. Pitcher Defense

Use the same general fielding resolution model with a restricted Pitcher reaction envelope.

Pitcher may:

- catch comeback liners
- field weak grounders
- deflect hard contact

Pitcher does not roam as the Primary Fielder.

---

# 48. Defensive Assignment Logic

Between batters:

- choose/change Pitcher
- choose/change Primary Fielder

The Pitcher cannot simultaneously be the Primary Fielder.

Before each pitch:

- optionally reposition Primary Fielder among the nine anchors

Selections persist until changed.

---

# 49. Ghost Base State

Keep base occupancy pure logic.

Conceptual:

```gdscript
class_name BaseState
extends RefCounted

var first: RunnerToken
var second: RunnerToken
var third: RunnerToken
```

`RunnerToken` initially needs only enough identity to connect the runner to the batting order/player state.

No 3D runner object is required.

---

# 50. Sac-Fly / Tag Resolver

After a fly catch:

`TagAdvanceResolver` considers:

- catch position
- defensive return destination
- estimated defensive return time
- fielder ability
- standardized runner advancement time
- safety margin

Conceptually:

```text
if runner_advance_time + safety_margin < defensive_return_time:
    runner advances
```

No Speed stat initially.

---

# 51. Match State Machine

Use explicit phases.

Conceptual baseline:

```text
BETWEEN_BATTERS
    ↓
PRE_PITCH
    ↓
PITCH_IN_FLIGHT
    ↓
    ├── no contact → PITCH_RESOLUTION
    │
    └── contact → BALL_IN_PLAY
                       ↓
                    PLAY_DEAD
                       ↓
                BETWEEN_BATTERS
```

Additional transitions:

- 3 outs → INNING_TRANSITION
- game complete → GAME_END

UI/animation observes game state.

Presentation does not create authoritative game state.

---

# 52. Core Event Flow

```text
PitchCommand
    ↓
PitchLaunchBuilder
    ↓
PitchFlightSolver
    ↓
SwingIntent
    ↓
ContactResolver
    ↓
BattedBallLaunch
    ↓
BattedBallBody
    ↓
BallPlayResolver
    ↓
BallPlayOutcome
    ↓
BaseState / MatchState
    ↓
Presentation
```

This is the central gameplay pipeline.

---

# 53. Event Architecture

Use a match-local event hub for important gameplay events.

Potential event vocabulary later includes:

- PitchReleased
- PitchResolved
- SwingStarted
- ContactMade
- FirstGroundContact
- ZoneEntered
- ObstacleHit
- FielderContact
- BallControlled
- OutRecorded
- Strikeout
- RunnerAdvanced
- RunScored
- InningEnded
- GameEnded

Do not implement every event before a real subscriber exists.

The future modifier system should extend this architecture rather than bypass it.

---

# 54. Explicit Non-Goals for Initial Core

Do not build yet:

- physical runner AI
- throw-to-base simulation
- manual fielding
- authoritative physical bat collision
- rigid-body Pitch flight
- global gameplay EventBus
- full shop/economy
- League system
- persistent stadium system
- multiplayer
- giant custom content editor
- production art pipeline beyond what the Lab needs

---

# 55. Phase 0–3 Engineering Backlog

## Phase 0 — Foundation

1. initialize Godot 4.7.2 project
2. Mobile renderer
3. Jolt
4. physics interpolation
5. Git/GitHub
6. folder structure
7. typed-GDScript warning policy
8. collision-layer convention
9. docs committed
10. stable ID utilities
11. DefinitionBase
12. ContentManifest
13. ContentDB
14. PlayerDefinition
15. DeliveryProfileDefinition
16. PitchDefinition
17. BallAeroProfileDefinition
18. BallSetupDefinition
19. runtime PitchState
20. PitchLaunchParameters
21. coordinate/unit conventions
22. minimal debug-draw helpers

### Phase 0 acceptance

A Pitch can be fully authored as data and resolved through ContentDB without changing simulation source code.

---

## Phase 1 — Pitch/Bat Lab

1. semantic pitcher-relative frame
2. handedness mapping
3. fixed-step RK2 Pitch solver
4. gravity
5. drag
6. spin lift
7. perforation/asymmetry force
8. orientation integration
9. sphere/shape sweep collision
10. visible Pitch actor
11. trajectory trace
12. plate/strike zone
13. Four-Seam prototype
14. Sinker prototype
15. Slider prototype
16. Riser prototype
17. Drop prototype
18. Eephus prototype
19. Knuckle prototype
20. PitchAimSolver
21. execution/fatigue perturbation
22. SwingProfileDefinition
23. Contact Swing
24. Power Swing
25. SwingIntent
26. ContactResolver
27. spray output
28. launch-angle output
29. exit-velocity output
30. batted-ball spin output

### Phase 1 acceptance

- Overhand Sinker and Sidearm Sinker are authored separately as data.
- They produce visibly distinct release/flight.
- Identical launch inputs reproduce the same sampled trajectory.
- Aim refers to intended plate crossing.
- early/on-time/late contact trends toward pull/center/opposite.
- Contact and Power swings feel mechanically distinct.

---

## Phase 2 — Ball-in-Play Lab

1. BattedBallBody
2. Jolt CCD
3. custom batted-ball aero
4. starter graybox field
5. safe-hit boundary
6. deep Double region
7. back wall
8. HR boundary
9. mathematical crossing tests
10. BallPlayState
11. BallPlayResolver
12. Single
13. deep-air Double
14. bounce-to-wall Double
15. wall-on-fly Triple
16. Home Run
17. nine fielder anchors
18. trajectory predictor
19. FielderPlanner
20. FielderController
21. FieldingResolver
22. clean/bobble/miss
23. DeflectionModel
24. Pitcher defense
25. BaseState
26. ghost advancement
27. TagAdvanceResolver
28. sacrifice-fly behavior

### Phase 2 acceptance

A single hit can travel through physical 3D space and resolve coherently as Out/Single/Double/Triple/HR while the automated fielder and Pitcher defense visibly react.

---

## Phase 3 — Complete Vanilla Match

1. four-player roster
2. fixed batting order
3. batter changes
4. Ball/Strike/Out counts
5. walks
6. runs
7. innings
8. pitching changes between batters
9. Primary Fielder changes between batters
10. Stamina
11. fatigue/hangers
12. pitcher re-entry
13. five-inning structure
14. 10-run mercy after three completed innings
15. extra-inning runner on second
16. game-over state
17. match timing telemetry
18. role-aware batting / pitching / ball-in-play cameras
19. current and on-deck batter presentation
20. visible pitch count, Stamina, bases, and complete count
21. shared Match Mode / Mechanics Lab debug layer
22. bounded per-pitch effort control
23. action-mapped keyboard/controller aim, swing, advance, and release inputs
24. player-timed release with Control- and fatigue-sensitive timing windows
25. count-aware deterministic opponent pitch and swing decisions
26. smooth role and ball-in-play camera direction
27. deterministic per-play records for reproduction and tuning
28. headless core regression scene
29. one-acceptance-per-at-bat automatic Pitch cadence with Pitcher telegraph
30. pointer-projected Contact/Power Swing input
31. pausable debug inspection
32. visible four-player pitching-staff selection between batters
33. nonlinear fatigue-band and plate-reach regression coverage

### Phase 3 acceptance

A complete vanilla game can be played repeatedly with no roguelike systems and is fun enough to justify building the season layer.

---

# 56. Production Gate

Do not implement the full roguelite until the vanilla sport clears this gate.

Questions:

- Is throwing Pitches fun?
- Can the batter read and react to them?
- Do Contact and Power swings create useful choice?
- Does fielder positioning matter?
- Are hit classifications understandable?
- Do bobbles/deflections read clearly?
- Is pitching fatigue interesting rather than merely annoying?
- Is a five-inning game an acceptable length?
- Do players want another at-bat/game?

If the answer is no, fix the sport before building shops and meta progression around it.

---

# 57. Technical Risks to Monitor

## Pitch readability

Movement can be physically interesting yet impossible to read.

This is a gameplay/tuning risk, not an engine-limit assumption.

## High-speed collision

Thin geometry may require simplified/thicker gameplay collision proxies even with CCD.

## Fielder prediction

Later absurd rebounds may require more frequent re-planning, not a perfect prediction model.

## Mobile

Rendering/animation/crowds are more likely to become mobile bottlenecks than one-ball aerodynamic simulation.

Test real phones early.

## Animation

Multiple delivery slots and handedness are a production-workflow risk to monitor once character animation begins.

None is currently a repo blocker.

---

# 58. Testing Direction

Before large-scale gameplay systems exist, prioritize pure logic tests for:

- stable ID/content lookups
- Pitch solver repeatability
- timestep convergence
- strike-zone crossing
- contact resolution
- BaseState advancement
- BallPlayResolver
- sacrifice advancement
- match-state transitions
- release timing quality and stat/fatigue influence
- count-aware opponent decision determinism
- JSON-safe per-play record serialization

Physics-heavy behaviors should also have small regression scenes with known expected ranges rather than relying only on unit tests.

The core regression scene runs with:

```text
godot --headless --path . res://src/tests/core_regression_test.tscn
```

---

# 59. Developer Tooling Direction

The first important tool is the Lab itself.

It should eventually expose:

- Pitch selection
- Pitch coefficients
- release slot
- velocity
- spin
- orientation
- ball setup
- trajectory trace
- strike-zone crossing
- contact-debug values
- batted-ball launch vector
- fielder coverage
- field-rule boundaries

Do not build an elaborate generalized editor before tuning proves which controls matter.

---

# 60. Architecture Freeze

For repo initialization, the following is considered settled:

```text
Engine:
Godot 4.7.2

Language:
typed GDScript

Renderer:
Mobile

Pitch:
custom fixed-step simulation
Node3D presentation
shape sweeps for collisions

Contact:
mathematical arcade resolver

Ball in play:
Jolt RigidBody3D + CCD + custom aero

Fielding:
planner/resolver + CharacterBody3D presentation

Baseball rules:
pure/state-machine logic

Content:
immutable Resource definitions

Runtime state:
RefCounted classes where practical

Presentation:
Nodes/scenes/animation

Global state:
minimal Autoloads

First real target:
Pitch/Bat Lab
```

Any deviation should be driven by an observed implementation problem, not hypothetical architecture anxiety.
