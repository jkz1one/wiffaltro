# Plastic-Ball Baseball Roguelite — Technical Preproduction

**Version:** v0.1.21
**Status:** FROZEN BASELINE WITH FIELD-SCORING / PITCHER-LANE AMENDMENT
**Scope:** Project architecture, Pitch simulation, batting/contact, ball-in-play, vanilla match, first Season Shell
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
- BatActor
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
recognition_difficulty
timing_difficulty
mistake_punish
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

Prototype player release uses a fast meter with a late command sweet spot near
85% progress. The small post-sweet-spot tail reports a normalized release
overdrive value. `MatchLabSupport` applies bounded category-aware stuff (more
velocity for Fastballs; more spin/perforation authority for breaking Pitches)
before nominal aim solving, then applies an explicit execution-quality and
Stamina penalty. This preserves one aim/flight pipeline and prevents the meter
from becoming a second unbounded effort control.

---

# 14. Pitch Simulation Ownership

Do **not** use `RigidBody3D` as the authoritative Pitch-flight model.

During pitch flight:

```text
PitchFlightActor : Node3D
```

owns a `PitchState`.

The authoritative Pitch ends at the mathematical plate-crossing event. Its
presentation may continue a short, non-interactive catch-through beyond the
plate before hiding. That visual tail cannot accept contact, change the call,
or remain visible into the next Pitch.

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

Very slow/high-arc Pitches should seed the search with a gravity-compensated
guide height and retain enough bounded iterations to find a crossing across the
authored aim area. A failed solve must restore `PRE_PITCH` without spending
Stamina, incrementing pitch count, or leaving the match soft-locked. An AI
Pitcher failure schedules a known-good repertoire/center fallback through the
normal visible delivery cadence; a player Pitcher remains in the ready state.

An accepted solve must meet the existing 1.25 cm target tolerance. Merely
crossing the plate is not success: the old best-candidate fallback could send
an underpowered Eephus far below a high aim point. If no candidate converges,
return failure and retain the safe retry behavior above. Do not silently add
velocity to satisfy the target. Minimum-effort Eephus reach depends on the
Pitcher's velocity and the requested height; the tested 90% effort fixture
can reach low, center, and high targets for both hands.

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
- 50–83%: gentle nonlinear degradation, reaching 25% pressure at 17% Stamina
- 83–100%: pressure rises from 25% to 100%; crisis/lapse rolls begin here

Match capacity is `(105 + 18 * Stamina rating) * 1.08`. These are distinct
quantities: the HUD shows Stamina remaining, while diagnostic fatigue is spent
capacity. Twenty percent remaining means 80% fatigue, not 20% fatigue.

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

Re-aim weakened velocity/spin/perforation/instability together before adding
release/direction/orientation errors. The previous vertical compensation ran
before movement loss, causing breaking pitches to miss by large distances at
ordinary targets. Command errors and seeded center pull remain separate, so this
does not restore lost movement or guarantee a Strike. The final reach floor is
0.12 m at the plate, keeping the ball visible above the ground.

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

The bat animation exists for presentation and synchronization. Its handed
stance, swing direction, and visible swing-plane tilt should read from the same
`SwingProfileDefinition` handedness and attack angle used by the resolver, but
the mesh remains non-authoritative. Its square-across-plate pose must occur at
the profile's `sweet_spot_time`, not at the animation's arbitrary midpoint or
finish. The ready stance is the loaded pose; after commitment, the barrel
drives directly through that synchronized contact pose and then decelerates
into a short front-shoulder finish. Do not use a full-circle recovery. The
separate Batter presentation should animate its hands and body on the same
timeline without merging character and equipment ownership.

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
contact_window_start
contact_window_end
sweet_spot_time
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

`BatterApproachModel` owns deterministic opponent recognition and decision
quality. Its memory resets per plate appearance and may learn from previously
observed Pitch identities and visible late-flight location buckets. It must not
read the player's intended target. Pitch-authored recognition, timing, and
mistake-punish values preserve differences such as a deceptive first Eephus
versus a repeated center-hanging Eephus.

The visual Batter and bat mirror handedness and animate the committed Swing,
but `ContactResolver` remains authoritative. Presentation geometry never adds
a second collision-based batting result.

---

# 29. Contact Resolver

During the valid contact interval, compare each authoritative 240 Hz Pitch
segment against the moving virtual contact region. Resolve the closest valid
encounter within that segment rather than evaluating the ball only at the input
frame. A committed swing may therefore begin before the Pitch reaches the
contact plane.

The virtual region's center travels in depth and height on the authored attack
plane, crossing the player's aimed X/Y point at `sweet_spot_time`. This makes
Pitch-descent/attack-angle alignment part of timing forgiveness and makes the
vertical ball/barrel offset at the actual encounter authoritative for launch
and spin. It does not move the player's aim point or create contact after the
authored window closes.

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

The independent `BatActor` uses the same profile sweet-spot time but remains
presentation-only. Its authored pose path is load → slot/drive → square contact
→ extension → decelerating front-shoulder finish. `PlayerAvatar` mirrors the
same handed path and adds bounded torso/weight transfer while counter-transforming
the hands so they remain attached to the bat. Aim posture is strongest at rest,
still partially expressed at contact, and fades during the finish. No mesh
collision may replace `ContactResolver` as baseball authority.

If the moving Pitch never encounters the virtual region before the authored
window closes, record an early/late or spatial miss but do not stop Pitch
flight. The authoritative Pitch continues to its plate-crossing call and its
non-interactive receiver presentation. Fair contact and fouls end custom Pitch
flight at the resolved encounter. Both then transition to a physical Jolt ball:
fair contact enters normal BallPlayResolver rules, while a foul remains live
only for a clean airborne catch and otherwise resolves on first ground or
out-of-play contact.

### Research basis

The arcade resolver should preserve the useful relationships from Alan
Nathan's ball-bat collision work without attempting a deformable-body bat
simulation: incoming Pitch velocity/spin, bat velocity/direction, attack angle,
ball-bat centerline offset, and actual encounter timing jointly determine exit
speed, launch angle, spray, and spin. In particular, centerline offset remains
the primary launch-angle control, while useful attack-angle alignment preserves
exit speed. See [Optimizing the Swing](https://baseball.physics.illinois.edu/OptimizingTheSwing.pdf),
[Optimizing the Swing II](https://baseball.physics.illinois.edu/OptimizingTheSwingII.pdf),
and [Modeling the Ball-Bat Collision](https://baseball.physics.illinois.edu/AJP-Oct2006.pdf).
The presentation timing also follows the measured kinetic sequence summarized
in [Welch et al. (1995)](https://pubmed.ncbi.nlm.nih.gov/8580946/): hips,
shoulders, arms, and bat accelerate sequentially, with bat speed peaking just
before impact. Current Statcast definitions provide useful validation ranges
for [attack angle](https://www.mlb.com/glossary/statcast/attack-angle),
[swing-path tilt](https://www.mlb.com/glossary/statcast/swing-path-tilt), and
[swing length](https://www.mlb.com/glossary/statcast/swing-length); these are
references for readable relationships, not a mandate to copy MLB scale into
the plastic-ball game.

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
- contact above ball center → ground-ball/topspin tendency

Preserve the sign of this spin tendency when launching the physical ball.
Clamping negative offset to zero spin erases a useful, readable distinction
between undercut fly contact and rollover ground contact.

The launch bridge also carries the Pitch ball's orientation and derives bounded
side/gyro components from spray and horizontal contact error. This gives Jolt
flight deterministic carry, fade, drop, and roller variety without choosing a
hit result through hidden randomness.

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
is_foul_play
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

## Live foul

- `is_foul_play = true`
- safe/deep/HR advancement boundaries are ignored
- a clean airborne defensive control resolves an Out
- first ground or out-of-play contact resolves a Foul and applies the count rule

## Moving grounder before the Single line

- ball has grounded but remains above the authored settled-speed threshold
- clean Primary Fielder control before the safe boundary resolves an Out
- a stopped ball or any ball that already crossed the safe boundary retains at
  least a Single from the Primary Fielder
- a clean moving-ground-ball control inside the Pitcher's fixed mound envelope
  remains an Out exception even after the ball crosses the Single line

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

`FieldDefinition` exposes a 3×3 tactical layout with seven legal starter-field
anchors:

- Shallow Left
- Shallow Right
- Middle Left
- Middle Right
- Deep Left
- Deep Center
- Deep Right

The user's pre-pitch strategic choice selects one anchor.

Authored anchors must respect both the Pitcher exclusion radius and the delivery
sightline. The starter field disables Shallow Center and Middle Center as
`PITCHER LANE`; Deep Center remains legal. Direct selection, cycling, defaults,
and AI placement must all honor the same availability rule. Shallow side
anchors may be in front of the mound in depth but must stay laterally clear of
Pitch trajectories and batting/pitching camera sightlines. The starter field
uses X +/-5.5 m and depth rows 8.5, 14.0, and 19.5 m. Tests sample the actual
Pitch solver across all nine Pitches, both throwing hands, corner targets, and
fresh/stressed execution. Passing that finite matrix is not proof of a global
maximum trajectory envelope; unusual flights still require runtime QC.

The Match UI may expose these anchors in an overhead Field Setup camera. The
view is pre-pitch only and must return to the normal Pitching shot before a
Pitch can begin. Its player-facing grid is displayed from deep to shallow, with
disabled Pitcher-lane cells retained so the spatial layout stays legible.
Left/right labels follow the view from home plate toward the field rather than
raw world-X naming. The starter Field Setup view is orthographic so authored
depth and scoring-plane spacing are not compressed by perspective.

After contact, the fielder moves according to the planner.

The opponent chooses a new anchor between batters from visible Batter
handedness and Power plus a deterministic seed. It cannot read future contact.
The Fielder remains inactive at its anchor until ball-in-play begins. After
contact it may cross in front of the mound. `DefenderSpacing` checks full
movement segments against a 1.55 m body-clearance disc at the actual Pitcher position and picks
a deterministic clear heading toward the intercept. The clearance includes
both avatars and the Pitcher's existing visual reaction step. It is not a
ball-control radius or a whole-field depth clamp. FieldingResolver still owns
ball control; movement has no ball collider. Physical bump/error responses
remain deferred.

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

The resolver must reject interactions outside explicit horizontal and vertical
reach limits before applying clean/bobble bands. The visible actor's actual
position—not only the planner's predicted intercept—supplies interaction
distance.

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
- turn a still-moving fair grounder into an Out inside the fixed mound envelope

`PitchBatLabDefenseSupport` permits bounded pursuit after contact:
0.20 s reaction delay, a moving ball, a reachable `FielderPlanner` intercept
within 5.0 m of the original mound, and Fielding-scaled speed of 3.6–4.6 m/s.
Grounders and nearby air balls qualify; the Pitcher is slower than the Primary
Fielder. Both defenders route around the other's actual body position.
The attempt radius remains 0.60 m around the visible Pitcher, without remote
control or pre-contact pursuit. The fielding pose persists through the result hold.

Scoring floors are observed through the swept control position before applying
the outcome. Outside the original fixed mound envelope, charging control follows
the ordinary Single rule. Only verified clean moving control inside the original
mound envelope can erase Single. Stopped balls, bobbles and Double-or-higher
floors remain safe; pursuit does not move that exceptional scoring region.

Test that small envelope against the swept batted-ball segment each physics
frame. This prevents high-speed tunneling without increasing the radius or
granting control outside the visible reaction space.

---

# 48. Defensive Assignment Logic

`PlayerMatchState.pitching_finished` is set when an arm with at least one thrown
Pitch is replaced. `TeamMatchState.select_pitcher()` rejects returning arms;
cycling skips them. Batting and fielding eligibility are unchanged. A pre-Pitch
lineup preview does not burn an unused arm. The AI checks only between Batters,
keeps the current arm above 17% Stamina, and otherwise selects the freshest
eligible replacement. It keeps the current arm if no fresher replacement exists.

Between batters:

- choose/change Pitcher
- choose/change Primary Fielder

The Pitcher cannot simultaneously be the Primary Fielder.

Before each pitch:

- optionally reposition Primary Fielder among the field's legal tactical cells

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

## Match cadence and presentation

Dead-ball holds are state-driven and advance automatically. They use separate
bounded timing ranges for another Pitch in the same plate appearance, a new
batter, and an inning transition. A completed player-offense plate appearance
returns to a one-time Batter-ready confirmation before the opponent begins its
delivery; subsequent Pitches in that plate appearance need no confirmation.
This is the future pre-at-bat consumable/tactical boundary. On defense,
completion of the hold returns
the player to `PRE_PITCH`; the player controls tempo by choosing when to begin
the next delivery. On offense, the opponent delivery director begins its own
bounded set/windup cadence. `AtBatCadenceController` separates a quiet setup
hold (0.22–1.05 s, with an 18% chance of another 0.35–0.70 s) from the existing
1.12–1.78 s windup. The pose stays at progress zero during setup, then advances
smoothly through the windup. Both draws are seeded; dead-ball holds are unchanged.

Hardening prioritizes smooth, readable transitions over shortening this loop.
Extra acceptance input cannot skip a result hold. Debug pause freezes the
release meter, live actors, and cadence. A Pitch-button release during pause
cancels only an active uncommitted player delivery, with no throw or Stamina
cost. A rejected Mechanics Lab transition must preserve the paused state.
Safe transitions restore the pre-pause status before suspending the match.

Paused inspection accepts `V` and updates only camera interpolation/follow.
It cycles all nine authored views without advancing physics, Swing presentation,
match time, delivery cadence, or intro/outro time. Resuming restores the prior
shot through normal smoothing; a setup screen closed during inspection instead
restores its gameplay shot. Bat and Batter actors are explicitly pausable even
though the lab root must always process debug input and camera inspection.

Esc is the sole keyboard pause shortcut; it backs out of nested settings/setup
where applicable. Intro skip uses click/Space. `T` requests one Batter timeout
per plate appearance during the AI's quiet set only. It stops cadence, preserves
the preselected Pitch/target, and requires readiness confirmation to restart.
It cannot cancel an active windup or flight. Normal pause remains unlimited.

For player pitching, Pitch selection, target, effort, Pitcher/Primary Fielder
roles, and the Primary Fielder anchor are mutable only in their legal ready
states. They lock when the release meter begins and remain immutable through
Pitch flight and ball-in-play.

Pitching Staff and Field Setup shield the Pitch target from pointer and
continuous aiming input. Escape backs out of Settings, then resumes Pause,
then returns from defensive setup through the normal role-camera path.
At a normal gameplay boundary Escape opens Pause. `_input` also handles paused
Pitch-button releases before GUI consumption, preventing a menu click from
leaving an abandoned delivery armed.

`MatchPresentationDirector` is a match-local presentation state machine. It
selects one, two, or three unique, seeded intro/outro shots from an authored
pool, uses a longer duration for a one-shot take, deliberately varies the
package length between matches, uses readable holds,
blocks gameplay during the sequence, returns through the correct role camera,
and exposes a skip path. Each shot also receives a seeded, bounded motion mode:
still, zoom in/out, pan left/right, or tilt up/down. `MatchCameraDirector`
applies that motion to the authored shot transform without changing game time.
The presentation director observes `MatchState`; it does not own innings,
scores, results, or gameplay timing. High-stakes cinematic packages remain a
future extension of this director, not a second match state machine.

`MatchCameraDirector.prepare_ball_in_play()` receives the current player role
before switching shots. Player defense initializes the follow camera on the
pitching side, then raises/pulls back and tracks the live ball without crossing
to the Batter's side. Player offense retains the behind-the-Batter follow.
Camera interpolation changes presentation only and cannot affect ball physics
or fielding resolution.

`PitchBatLabHomeRun` handles scored-ball presentation separately from resolution:
the real body carries beyond the wall for 1.25 s, with scoring callbacks
disconnected, then freezes as the camera smoothly switches to Establishing.
The Home Run call lasts 4.4 s total; even a walk-off waits before the outro.
Pause freezes the carry and timer. Reset/cleanup cancels the sequence. Live-ball
tracking follows more of the ball's horizontal/depth travel and gains vertical
range; batting camera height is 2.10 m with a slightly lower target.

Match HUD ownership is split by purpose. `MatchScorebug` renders persistent
baseball state from `MatchState` at a user-selectable bottom-right, top-left, or
top-right anchor. A small boxless label beneath that anchor renders routine
Ball/Strike/Foul and speed telemetry. Larger transition/result messages render
above center at 26 px with dark-blue outline/shadow. `PitchPicker` renders the
current repertoire as numbered buttons and owns Pitch count, Stamina and fatigue
stage on player defense. The 252 px panel uses one-line numbered rows, preserves
readable text and selected state, and collapses to the selected Pitch when
delivery locks selection. It hides during Home Run presentation. Field/Bullpen
toggle buttons are 132 px wide; footer text ends above the Pause button. The scorebug
retains opponent condition during player batting. `PitchBatLabPauseMenu` nests
HUD-anchor, blue-sky/green and Mute sounds choices inside Pause. `PitchBatLabSettings` saves
them in `user://display-settings.cfg`. Batting zone opacity is 0.35 and aim
outline opacity is 45% of its original value; pitching materials are unchanged.
F1-owned labels render detailed
diagnostics. F2 may enter the
Mechanics Lab only at a safe stopped pre-Pitch boundary. The Lab keeps the
existing `MatchState` suspended and restores its selection/aim/role-facing
presentation state on return; it never creates a replacement match merely to
leave debug mode.

HUD research references: Microsoft's [text-display guidance](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101)
emphasizes readable size, spacing and player context; its [contrast guidance](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/102)
addresses information against changing backgrounds. The compact redesign removes
repeated delivery labels and unused rows before reducing text size. These are
design references, not a claim that headless layout checks establish visual
accessibility compliance. Rendered review is still required.

AI chase behavior uses a gradual outside-zone probability falloff: borderline
balls invite offers, two strikes add protection, and far waste pitches remain
mostly takes. In-zone swing, contact-aim and timing formulas are unchanged.

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
17. 3×3 tactical grid with field-authored legal anchors
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
29. one-confirmation-per-Batter flow, automatic within-at-bat dead-ball cadence,
    and Pitcher telegraph
30. pointer-projected Contact/Power Swing input
31. pausable debug inspection
32. visible four-player pitching-staff selection between batters
33. nonlinear fatigue-band and plate-reach regression coverage
34. handed Batter/Pitcher/Fielder presentation and visible bat swing
35. deterministic Batter approach memory without hidden-input reads
36. plate-plane mouse pitching through the shared hold/release execution meter
37. bounded delivery-rhythm variance
38. overhead 3×3 Field Setup view
39. mathematical back-wall segment fallback
40. independent BatActor presentation and post-plate visual catch-through
41. 240 Hz swept Pitch-versus-moving-contact-region resolution
42. missed-swing continuation through plate call and receiver presentation
43. faster authored Swing and player Pitch-release timing
44. automatic one-to-three-shot game intro and win/loss outro
45. state-safe presentation skipping and role-camera settlement
46. future high-stakes broadcast package seam without baseball-state ownership
47. seeded per-shot still / zoom / pan / tilt presentation motion
48. compact lower-right `MatchScorebug` plus boxless beneath-scorebug event ownership
49. safe-boundary Mechanics Lab suspension that preserves the live `MatchState`
50. late release sweet spot and bounded category-aware overdrive tradeoff
51. release-driven visible player-Pitcher delivery pose

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
- swept Swing timing and miss continuation
- BaseState advancement
- BallPlayResolver
- sacrifice advancement
- match-state transitions
- release timing quality and stat/fatigue influence
- count-aware opponent decision determinism
- JSON-safe per-play record serialization
- automatic dead-ball cadence and presentation-director sequencing

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


## Development verification and QC persistence

`tools/setup_verify.py` provisions pinned Godot 4.7.2 and gdtoolkit 4.3.4.
`tools/verify.py` checks an isolated current-source copy, preserves logs, and
fails on engine errors even with a zero process exit. See `VERIFICATION.md`
for commands, supported setup platforms, and current runtime findings.

`PlayRecordExport` saves completed-play snapshots under `user://qc/`. F3
retains console output and reports the saved path; resetting rotates the file
without removing earlier sessions. Records retain match/lab provenance and
snapshots retain loaded geometry, engine version, and available Git metadata.
This is development telemetry, not a gameplay save system.

The verification runner also executes seeded full-match state transitions,
two scripted-player live-scene matches, live player-input flow checks, and
isolated Jolt ball fixtures. These test reliability and collision-to-rule
integration, not a representative result
distribution. PitcherDefense must allow a grounded ball center down to world
height zero; a 5 cm lower gate excludes the authored 3.65 cm-radius rolling ball.
Negative-height positions remain ineligible. No mound radius or control
threshold changes accompany this correction.


## Presentation feedback follow-up — 2026-09-21

`PlaySounds` caches five original mono PCM cues in `AudioStreamWAV` resources,
played by pausable `AudioStreamPlayer` children at -12 dB. Contact, clean control,
bobble, wall and HR hooks observe authoritative events; audio never resolves play.
There are no third-party sound files, downloads, attribution obligations from
new assets, or runtime synthesis on the contact frame. `audio/muted` shares the
existing settings file, defaulting false for older files. Muting immediately stops
all cues, including paused playback, and new muted cues are discarded.
Accelerated headless fixtures allow two real mixer/update cycles at teardown,
so engine shutdown does not race queued audio cleanup. There is no gameplay wait.

`BallVisibility` owns a soft ground-reference shadow and a tapered transparent
ribbon made from recent actual batted-ball positions. It has no collision shape,
resolver calls, predictive trajectory, or Pitch-flight attachment. The ribbon
requires speed >=12 m/s and is bounded to 65 ms and 0.9 m. It clears on slow/frozen
balls and on cleanup; the shadow is hidden beyond the back wall and near ground.
The lab's paused update gate freezes history while allowing camera inspection.

`PitchFeedback` renders one 14 px, three-second note beside the scorebug, with a
short fade, no mouse interception, and no overlap with the routine call slot.
Top-left Pitch panel and top-right defensive buttons move down to make room.
Pitch calls live in `PitchBatLabPitchCall` to keep the main lab below its lint
size limit. Handedness/feedback are captured before the count resolver advances
the Batter, and miss feedback is taken from `ContactResult`. Repertoire tooltips
read `PitchDefinition.tactical_description`; descriptions reflect the authored
starter content rather than promising a real-world trajectory or guaranteed result.

The existing cadence still owns progression. Catch/strikeout holds have a 2.25 s
minimum, longer inning holds retain priority, and non-HR immediate game endings
hold for 2.5 s before outro. HR remains 4.4 s. Bobble feedback never pauses physics.
No field boundaries, transfer functions, aerodynamic coefficients, fatigue model,
AI odds, or windup durations changed in this pass.

### Sources and design interpretation

- [Godot AudioStreamWAV](https://docs.godotengine.org/en/stable/classes/class_audiostreamwav.html)
  documents generated PCM storage; [AudioStreamPlayer](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html)
  documents nonpositional playback and stop/pause control. These support the small
  cached cue implementation. The waveforms themselves are project-original code.
- [Godot Control](https://docs.godotengine.org/en/stable/classes/class_control.html)
  documents `tooltip_text`; the existing hover interaction provides optional
  descriptions without introducing a hold action or changing Pitch inputs.
- [Xbox XAG 103: Additional channels for visual and audio cues](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/103)
  supports retaining text/visual equivalents for audio and not relying on color
  alone. The existing Stamina percentage/condition remains beside a bar that turns red
  at 17% remaining; the user requested no added warning text. Live bobbles retain
  a text label alongside their sound.
- [Xbox XAG 105: Audio accessibility](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/105)
  supports player control over sound. This prototype has one effects category and
  one saved mute toggle; separate category levels can follow if music/voice arrives.
- [Xbox XAG 117: Visual distractions and motion](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/117)
  informs the restrained approach: no flashing warning, shake, or motion blur.

These sources inform implementation and accessibility choices. They do not
validate the chosen trail length, volume, result timing, or fun. Headless tests
cannot establish visual comfort, sound quality, or accessibility conformance;
rendered play and human listening remain required.

## Final sport audit and Season Shell — 2026-09-21

The initial full Godot 4.7.2 baseline passed at `5c22c22`. The new camera audit
then reproduced loaded-bat AABB intersections with three sampled incoming rays
per hand at the former 0.34 m camera-side offset. Reducing it to 0.18 m clears
all 90 sampled rays per actor across the two hands. This is a conservative mesh
bounding-box test at the loaded, centered-aim pose, not rendered pixel occlusion
or exhaustive aim/swing coverage. Height 2.10 m, depth -3.38 m, focus
`(0, 1.10, 7.1)` and 75-degree FOV remain; projected one-meter zone height is
about 132 px in the 1280×720 viewport. The camera stays stable during a Pitch;
the contact-plane pointer mapping round-trips at `ContactResolver.CONTACT_PLANE_Z`.
No broad camera or sport tuning was introduced.

That audit aligned `BatterApproachModel` and `PitchFeedback` with the old scene,
but did not verify baseball handedness from the camera. The follow-up below
supersedes that mapping: the old scene itself had its batter boxes reversed.

### Season boundaries

- `SeasonState` owns draft choices, the six-team circle schedule, league results,
  standings and playoff transitions. It creates `MatchState` from immutable
  authored `PlayerDefinition` resources; live play continues through the existing
  match/contact/physics pipeline. The 24 new starter players are manifest entries.
- `SeasonApp` owns main/menu/match scene lifetime. `SeasonMenu` supplies simple
  scrollable body pages with persistent footer navigation. Menus have no Pitch
  input handler; an active lab receives only unhandled gameplay input.
- `_player_home` drives role checks and the correct win/loss presentation.
  The configured match is consumed once. Menu-managed games reject `R` restart;
  standalone lab regression/debug behavior remains available.
- Result recording is guarded by the current fixture ID and a one-shot app
  flag. Final scores save during GAME_END; the existing presentation completes
  before Continue opens postgame. Pause > Leave confirms abandonment of an
  unfinished fixture. Finished games use the result handoff instead.
- New `SeasonSave` uses `user://season-v1.json`, a temporary write/flush/rename,
  versioned JSON primitives and stable player IDs. Only seed, draft picks,
  player-game scores and lineup selections are stored. Loading validates bounds,
  IDs, legal pick/result order, unique lineup and distinct defense roles, then
  reconstructs derived standings and AI scores. Corrupt/incompatible files are
  reported and left untouched. No midgame or career persistence is implied.
- Reconstruction assumes this version's content pool and simulation rules.
  Content-pool/algorithm changes require an explicit save-version migration or
  invalidation policy; silently reinterpreting an old season is unacceptable.
- AI-only games use seeded Poisson scores based on the average of the authored
  seven player ratings, with a seeded tie resolution. They do not run physical
  Pitches, use player standing for rubber-banding, or supply calibration evidence.
- Wins, run differential, runs scored and a seeded preseason draw are provisional
  tiebreaks. Every match starts with fresh player states. The neutral final has
  nominal home/away roles for inning rules and the starter field as placeholder.

### Implementation sources

[Godot saving games](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)
documents JSON serialization and the `user://` path.
[Godot DirAccess](https://docs.godotengine.org/en/stable/classes/class_diraccess.html)
documents file replacement through `rename_absolute`. These support the save
mechanism; the schema validation, replay design and season policies are project
decisions. The single-file checkpoint is not a cloud save or power-loss durability
guarantee. Save errors remain visible and the live session stays available.

## Season enrichment follow-up — 2026-09-21

See `SEASON_ENRICHMENT_AUDIT.md` for the ten-point audit, primary research,
decisions, measured evidence and scope boundaries.

- `SeasonPlayerCard` presents identical seven-stat rows on draft cards;
  `SeasonMenu` provides explicit selection then confirmation, a persistent
  chosen-roster strip, a visible lineup grid and focusable navigation. Ratings
  do not rely on hover, color or a single overall score.
- `PlayerDefinition` adds `switch_hitter`, `pitching_style` and
  `signature_pitch_index`. Pitcher handedness remains the existing R/L enum.
  `PlayerMatchState.batting_hand_override` is mutable match state, never a
  mutation of the shared Resource. Contact, bat, avatar and feedback read it.
- With home at Z=0 and field at +Z, the catcher's camera's screen-right basis
  points toward world -X. Right-handed Batters must therefore stand at +0.82 X,
  left-handed Batters at -0.82 X. Bat rig signs and the small camera offset mirror
  with that correction. The previous audit only tested mutual consistency and
  missed the reversed baseball convention. New camera tests assert screen side.
- `MatchRosterControls` exposes the real Primary Fielder and rating in Field
  setup, applying the same between-Batter guards as F. Its switch-hitter control
  is available only before initial readiness. Once the AI pitch plan is selected,
  even a timeout cannot unlock a side change for that plate appearance.
- `BatterApproachModel.read_plate_location` projects observed position/velocity
  to contact, bounded to 0.24 s, with gravity. It does not call the aim solver,
  future integration or hidden target. Recognition/timing/aim errors remain;
  F3 gains `ai_plate_read`, effective `batter_hand` and fixed `pitcher_hand`.
- `PitchingStrategy` is a seeded weighted-choice model using only owned Pitches,
  authored style/signature, count, previous-Pitch nominal speed and batting hand.
  Difficulty affects edge/expansion/sequencing weights, not ratings or command.
  Match tactical quality is `clamp(0.15 + difficulty*0.25 + min(round,9)*0.025)`.
  Difficulty 0/1/2 corresponds to Relaxed/Standard/Tactical. Effort is 0.94–1.04.
  Pitcher substitution clears the previous-Pitch index rather than interpreting
  an old arsenal index as a different player's Pitch.
- Forty-eight explicit manifest players supply a randomized season pool.
  A deterministic swap keeps at most one >=4-Pitch player in the first twelve
  draft offers, without duplicating/removing anyone. Twenty-four players occupy
  the six active clubs; the rest are absent that season.
- Save schema 2 freezes ordered pool IDs, tiebreak draws, difficulty and the
  six AI simulation strength values alongside picks, lineup and player results.
  Full-precision JSON avoids rounding the replay inputs. Schema 1 recreates its
  original sorted 24-ID pool before replay. Future score-algorithm changes still
  require explicit migration. Player definition balance itself is not snapshotted.
- Before replacement, a valid primary save is copied to `.bak`. A corrupt or
  absent primary may restore that backup with a visible recovery notice; it is
  not silently called current progress. Invalid primary data stays untouched
  until a later deliberate checkpoint. Both invalid files produce an error,
  not a fabricated new season. File name remains `season-v1.json` for continuity;
  the JSON version, not the filename, identifies the schema.

Persistence remains local and between-game. Midgame suspension requires explicit
serialization of count, batting cursor, used Pitchers, Stamina, tactical state
and physics/presentation boundaries; it is not implemented as a quick scene dump.

## Season flow and performance follow-up — 2026-09-21

`SeasonPages` owns hub/pregame/recap/statistics presentation. `SeasonMenu` keeps
the shared frame, persistent footer, draft and editable roster. The main route
is hub → pregame → match → postgame → next pregame, with a separate season-ending
recap. Current opponent starter information reads the same roster index used by
`SeasonState.make_match`. Standings movement compares complete league rounds;
the preseason tiebreak draw is not presented as movement after the first game.

`MatchPerformance` observes completed plate appearances at the existing
`MatchState` scoring methods, before batter advancement and game-end handling.
It never resolves a play. Hits, walks, strikeouts and sacrifice scoring therefore
use authoritative results. Pitch counts come from each `PlayerMatchState` at
snapshot time. Match/Lab suspension retains the same MatchState, so clearing
development telemetry cannot erase gameplay statistics. No ERA or individual
runs are inferred from ghost runners or inherited runners.

`SeasonApp` submits a deep performance snapshot with the fixture's final score.
`SeasonState.record_player_result` validates it before mutation and retains it
in the same single-commit result. Unfinished games never enter season totals.
`SeasonPerformance` validates roster IDs, integer bounds, hit-type bounds and
balanced batting/pitching totals, aggregates player IDs and finds tied leaders.

Save schema 3 keeps schema 2's replay inputs and embeds optional statistics in
completed player results. Version 1/2 histories remain score-only, with visible
coverage. Mixed older/newly recorded seasons remain valid. The existing valid
backup and temp/flush/rename mechanism is retained. There is no midgame resume,
career history or simulated AI box score. Full-season statistics are a sum of
saved completed-game observations, including playoffs.

The new flow test covers real scoring-method attribution, substitution,
walk-off, a twelve-game scored season, save/reload and malformed stats, older
save migration, page bounds and scroll preservation. The live drafted-match
test additionally checks that actual AI/contact/Jolt events yield balanced
statistics and one observation per completed appearance. Human visual/feel QC
remains necessary; headless layout checks do not establish aesthetics.
