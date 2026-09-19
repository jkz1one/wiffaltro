# Implementation Status

**Current phase:** Phase 3 — Timed contact and broadcast-flow hardening; hands-on validation pending

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


## Fatigue/hanger correction — second revision after match playtest

The 2026-09-18 playtest found that fatigue mostly drove Pitches into the dirt
while preserving too much velocity and movement. The first correction added
variation, but the 2026-09-19 match playtest found that penalties still arrived
far too early and could make pitching unplayable before a practical pitching
change. The implementation now:

- [x] keeps fatigue mechanically dormant through 35% and only 2.5% effective at 50%
- [x] ramps nonlinear degradation from 50–92% and steeply from 92–100%
- [x] roughly doubles provisional Pitcher Stamina capacity
- [x] makes faster Pitches lose more velocity
- [x] makes breaking Pitches lose more spin and finish
- [x] degrades perforation movement and instability authority independently
- [x] reserves seeded heavy-tail lapses for the upper fatigue band
- [x] adds probabilistic edge-to-heart command regression rather than a fixed center target
- [x] preserves location variance while making 100% fatigue resemble batting practice
- [x] guarantees exhausted Pitches can still reach the plate plane
- [x] makes release-window shrinkage use nonlinear fatigue pressure instead of raw fatigue
- [x] displays nominal release speed, executed release speed, and predicted plate speed separately
- [x] displays raw fatigue, effective pressure, and named fatigue band in debug telemetry
- [x] adds deterministic curve, capacity, plate-reach, velocity, spin, and hanger regressions
- [ ] Godot 4.7.2 hands-on second-revision fatigue/hanger retest


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
- [x] Godot 4.7.2 import/parse validation — user ran the Phase 2 build successfully
- [x] automated fielding runtime smoke — user reported fielding looked good on 2026-09-19
- [ ] exhaustive Ball-in-Play result-boundary and ghost-base runtime pass

Fielding is provisionally approved for continued development. Result-boundary,
base-advancement, and tuning details remain subject to the combined match test.


## Phase 3 Complete Vanilla Match — implementation and headless smoke validated

Implemented in repository:

- [x] explicit match phase state machine
- [x] two four-player provisional lab rosters
- [x] fixed batting orders with current and on-deck batter handling
- [x] Ball / Strike / Out counts, including two-strike fouls
- [x] walks with forced ghost-base advancement
- [x] hits, outs, sacrifice advancement, and runs connected to match score
- [x] top/bottom half-innings and five-inning regulation structure
- [x] 10-run mercy logic after three completed innings
- [x] extra innings with a ghost runner on second
- [x] walk-off and game-over states
- [x] persistent per-player Stamina and pitch counts
- [x] between-batter Pitcher changes, re-entry, and Primary Fielder changes
- [x] player batting against a visible-input AI pitcher
- [x] player pitching against a visible-flight AI batter
- [x] player ratings connected to batting coverage, exit speed, fielding, velocity, break, Control, and Stamina
- [x] automatic batting, pitching, and ball-in-play camera changes
- [x] clean scoreboard plus optional F1 debug telemetry
- [x] F2 switch between Match Mode and the preserved Mechanics Lab
- [x] larger visible/effective Contact and Power coverage regions
- [x] batting and pitching targets can move outside the strike zone
- [x] bounded 82–112% Pitch effort with velocity, movement, command, and Stamina tradeoffs
- [x] match timing telemetry
- [x] action-mapped continuous keyboard and controller aim
- [x] held player delivery with timed release and forced auto-release
- [x] Control widens and fatigue narrows the useful release window
- [x] actionable early/late and directional swing feedback
- [x] smooth role transitions and dynamic ball-in-play camera follow
- [x] deterministic count-aware opponent pitch/swing choices
- [x] JSON-safe deterministic per-play records with F3 output
- [x] headless regression scene for release, AI, count rules, and records
- [x] one acceptance per at-bat with automatic between-Pitch cadence
      (superseded by the zero-acceptance revision below)
- [x] readable Pitcher set / windup / delivery telegraph
- [x] pointer-projected batting aim with left-click Contact and right-click Power
- [x] full-simulation `P` debug pause
- [x] visible clickable four-player pitching-staff selector between batters
- [x] authored Middle Center anchor clearance from the Pitcher
- [x] fatigue/stamina/cadence/defensive-separation regression coverage
- [x] Godot script UID sidecars committed for stable cross-clone references
- [x] all current GDScript passes `gdparse` and `gdlint` static checks on 2026-09-19
- [x] prior Phase 3 revision: Godot 4.7.2 import/parse validation on 2026-09-19
- [x] prior Phase 3 revision: Godot 4.7.2 headless main-scene smoke on 2026-09-19
- [x] prior Phase 3 revision: Godot 4.7.2 headless core regression checks on 2026-09-19
- [x] hands-on match smoke — user reported the match works well overall on 2026-09-19
- [x] Godot 4.7.2 main-scene hands-on validation of the fatigue/cadence revision
      — user reported it works pretty well overall on 2026-09-19
- [ ] Godot 4.7.2 headless regression validation of the fatigue/cadence revision
- [ ] complete five-inning match runtime test
- [x] fatigue/click-batting/cadence/staff UI hands-on test; findings feed the
      player-presence and Pitch-identity revision below

The prior Phase 3 revision imports, launches, and passes the automated core
regression scene. The fatigue/cadence revision has now received a hands-on
match pass; its remaining feel findings are addressed by the next revision.


## Phase 3 player-presence and pitch-identity revision — hands-on findings received

The 2026-09-19 hands-on match pass reported good overall function and exposed
the next feel bottlenecks. Implemented in response:

- [x] stopped Pitch visuals no longer persist into the next Pitch
- [x] wider authored Contact and Power timing depths
- [x] handed over-shoulder batting camera for clearer depth perception
- [x] visible handed Batter, Pitcher, Primary Fielder, and animated bat
- [x] authored Pitch speed bands and per-delivery variation
- [x] small seeded per-delivery speed variation
- [x] pitch-authored recognition, timing, and mistake-punish values
- [x] deterministic Batter approach memory for repeated Pitch/location patterns
- [x] Batter decisions use visible late-flight location, never hidden target input
- [x] fatigue-slowed Pitches naturally reduce AI reaction pressure
- [x] bounded seeded Pitcher cadence and dead-ball rhythm variation
- [x] plate-plane mouse aim and pitching input
- [x] overhead Field Setup camera with direct 3×3 anchor selection
- [x] rating-scaled Fielder speed, explicit reaction delay, and fewer bobbles
- [x] shorter physical bobble deflections
- [x] visibly reactive automatic Pitcher defense in a 0.95 m mound envelope
- [x] mathematical back-wall crossing fallback and wall-position freeze
- [x] regression coverage for pitch bands, awareness, chase geometry, cadence,
      Pitcher radius, and back-wall resolution
- [ ] Godot 4.7.2 import/headless regression validation
- [x] hands-on/video review of Pitch identity, cadence, bat, and defense on 2026-09-19

## Phase 3 recording-driven hardening — runtime validation pending

- [x] restored the better-playing prior Pitch velocity baselines after the
      fast/slow extremes overshot the useful range
- [x] added fresh-state reachability regression coverage across all nine Pitches
- [x] hardened slow/high-arc aim solving with a gravity-compensated initial guide
- [x] added low-effort Eephus aim-area regression coverage and safe solve-failure
      rollback so a failed launch cannot strand the match in flight
- [x] separated `BatActor` from `PlayerAvatar` and rebuilt the procedural bat
- [x] added a short non-interactive post-plate visual catch-through
- [x] mapped mouse pitching to the same hold/release execution meter as Space
- [x] added a visible release bar and ideal-release marker
- [x] made left click advance dead balls/plate appearances without requiring Space
      (superseded by the zero-acceptance revision below)
- [x] added roughly one second to the readable dead-ball hold and automatic
      continuation within an unfinished plate appearance on offense and defense
- [x] reduced Primary Fielder movement speed, horizontal/vertical reach, and
      clean-control generosity; debug coverage now matches actual reach
- [x] added deterministic reach/height rejection regressions
- [ ] Godot 4.7.2 import/headless regression validation
- [ ] hands-on cadence, release meter, Pitch visibility, bat, and defense retest


## Phase 3 timed-contact and broadcast-flow revision — runtime validation pending

This revision supersedes the earlier one-acceptance and click-through flow.

- [x] Swing input now starts an authored-duration Swing instead of immediately
      resolving contact on the click frame
- [x] ContactResolver sweeps every 240 Hz Pitch segment against the moving
      virtual contact region
- [x] Contact and Power have distinct authored duration, valid window, and
      sweet-spot timing
- [x] missed Swings leave the Pitch in flight for the plate call and visible
      receiver continuation
- [x] a non-authoritative receiver ring gives taken and missed Pitches a visual
      destination in the explicit debug layer without obstructing either role
- [x] independent BatActor Swing timing is shorter and synchronized to the
      authored profile
- [x] right- and left-handed Batter box, hands, shoulder, bat, and Swing
      presentation mirror from the same handedness
- [x] opponent Swing commitment uses visible ball timing with lead time rather
      than snapshot contact
- [x] player Pitch release meter reaches its ideal and auto-release sooner
- [x] dead-ball and inning-transition holds advance automatically; each new
      player-controlled offensive Batter receives one explicit confirmation,
      while Pitches within that plate appearance need no extra acceptance
- [x] player pitching tempo remains deliberate because the next Pitch begins
      only when the player starts the delivery
- [x] automatic seeded two-to-three-shot `GAME START` presentation
- [x] deterministic two/three-shot variation with longer readable intro holds
- [x] guarded contact-time Pitch reset against same-frame null-state access
- [x] handed bat stance now begins behind the back shoulder and completes a
      short continuous follow-through instead of snapping to rest
- [x] BatActor visibly uses the authored Swing attack angle while remaining
      independent from authoritative mathematical contact
- [x] oblique contact now passes signed backspin/topspin into physical BIP
- [x] Mechanics Lab preserves its manually selected camera through contact;
      Match Mode retains automatic broadcast camera changes
- [x] narrowed Godot warning suppression to support-owned lab fields and
      removed built-in-shadowing names from the touched gameplay paths
- [x] automatic seeded win/loss and final-score presentation
- [x] intro/outro input lock, skip handling, and role-camera settlement
- [x] deterministic regression coverage for swept contact, early miss
      continuation, automatic terminal cadence, and camera-shot selection
- [x] camera cycling explicitly casts its wrapped index back to the typed `Shot`
      enum, preventing the Godot 4.7.2 script-reload failure found in playtest
- [x] all current GDScript passes `gdparse` and `gdlint` static checks on
      2026-09-19
- [ ] Godot 4.7.2 import/headless regression validation
- [ ] hands-on timed Swing, receiver, handed bat, cadence, release meter, and
      intro/outro validation


## Canonical post-fun-gate roadmap — not implemented

The ordered roadmap now lives in `SOURCE_OF_TRUTH.md` §35. Phase 3 and the
sport fun gate remain the current priority.

- [ ] Phase 4 — Season Shell
- [ ] Phase 5 — Seasonal Build Systems
- [ ] Phase 6 — Opponents, Fields, Leagues, and Difficulty
- [ ] Phase 7 — Persistent Club Layer, including earned post-season player-card
      packs and draftable-player unlocks
- [ ] Phase 8 — Production and Content Scale
