# Implementation Status

**Current phase:** Phase 3 — first human feedback implemented; follow-up human QC pending

## Presentation polish and sound — 2026-09-21

- Source of truth v0.4.23 adds original procedural contact, clean-fielding,
  bobble, wall and HR sounds. Pause > Settings saves Mute sounds, immediately
  stops active cues and discards muted events. Explicit teardown releases audio.
- Batted balls gain a soft ground shadow and a bounded historical trail. Pitch
  flight, collision, Contact/Power, scoring geometry and aerodynamics are unchanged.
- Brief scorebox-adjacent feedback reports actual timing/aim, taken or chased
  locations with correct handedness. Bobble text updates after resolution.
  Feedback freezes in pause, expires, and clears with the next Pitch/reset.
- Per user correction, fatigue adds no warning text: the existing Stamina bar
  turns red at 17% remaining. Existing percentage and condition remain.
- All nine Pitch definitions have short tactical descriptions available only
  on hover, with no added hold input or permanent description panel.
- Catches/strikeouts get at least 2.25 s; longer inning holds and 4.4 s HR holds
  remain. Immediate non-HR game endings wait 2.5 s before outro. Bobbles stay live.
- New presentation tests cover waveform validity/routing, mute persistence,
  UI bounds, handedness, bar color, physical-ball aid lifecycle and result timing.
  Existing player-hit and physical-HR tests now also assert their sound hooks.
- Final `python3 tools/verify.py` passed on Godot 4.7.2 with no errors or warnings:
  parse/lint/import, presentation checks, 324 pitch-quality cases, actual player
  input, two live matches, 100 seeded match replays, 12 Jolt fixtures, core rules,
  QC export and main-scene smoke. Logs: `builds/verification/20260921T051512553496Z`.
- Godot and Microsoft primary documentation informs the implementation; sources
  and the original sound provenance are recorded in `TECHNICAL_PREPRODUCTION.md`.
  These choices remain subject to listening/rendered human QC, not a fun-gate approval.

## Home-run, pitcher and at-bat follow-up — 2026-09-21

- Source of truth v0.4.22 supersedes the prior pitching re-entry rule. Once an
  arm has thrown and is removed, it cannot pitch again that game; batting and
  fielding remain available. Bullpen rows mark removed arms USED. AI changes
  pitchers between Batters at 17% Stamina or less when a fresher arm is available,
  replacing the former inning-index rotation.
- Home Runs carry physically beyond the wall for 1.25 s, then use a wider
  celebration camera with 4.4 s total call time. Scoring remains final at wall
  clearance. Walk-offs finish that hold before the outro. Pause/reset are covered.
- Pitcher pursuit includes nearby air balls and grounders at 3.6–4.6 m/s, with
  the existing 0.20 s delay, 5 m local intercept limit and actual-body reach.
  Ground control outside the original mound preserves earned result floors.
- Single moves from 10.5 to 11.25 m at the user's request, a provisional human-QC
  adjustment. The prior proxy's 10.5 m percentages do not validate this revision.
  Deep Air, wall, HR height, Contact/Power and aerodynamic coefficients are unchanged.
- Pitch selector is narrower with one-line rows and collapses during delivery.
  Field/Bullpen buttons shrink; bottom text clears Pause; Esc is the sole pause
  shortcut. The batting camera is raised 0.22 m and tilted slightly down.
- T grants one tactical timeout during the pre-windup set per plate appearance,
  preserving the selected AI Pitch and count. Normal pause remains unlimited.
- Borderline chase offers and two-strike protection increase; in-zone AI contact
  ability is unchanged. Seeded choice fixtures produced 155/600 borderline offers,
  245/600 with two strikes, and 11/600 offers at a far waste location.
- Fatigue diagnosis reproduced 0/12 broadly hittable Slider samples and 1/12 Drop
  samples at 20% Stamina. Compensating after all stuff degradation, before command
  error, corrects those misses. The same revised samples are 12/12 hittable for
  both Slider variants and Drop. These are trajectory fixtures, not human hit rates.
  Match capacity grows 8%; the steep ramp begins below 17% remaining, with a
  positive plate-height floor. Weak stuff and command variance remain penalties.
- Targeted coverage includes 324 pitch-quality trajectories, 12 actual Jolt
  fixtures, home-run/walk-off presentation, timeout boundaries, bullpen eligibility,
  keyboard pause and HUD bounds. Full Godot 4.7.2 verification passed, including
  two live matches, 100 seeded match replays, core regressions and import/smoke.
  Final local log: `builds/verification/20260921T043958550883Z`.
- Next gate remains hands-on camera/HUD/fatigue review and a meaningful F3 sample.
  Season/meta work remains deferred.

## Human playtest feedback — 2026-09-21

- Source of truth advanced to v0.4.21 for bounded Pitcher grounder pursuit and
  presentation changes. Geometry, Contact/Power transfer, aerodynamic coefficients
  and AI batting probabilities remain unchanged.
- Pitcher charges nearby moving grounders before Single, using actual movement
  and defender clearance. The original fixed mound remains the only exception
  to ordinary safe ground control. Same-frame Single crossings preserve their
  floor before contact; fielding poses persist through the result hold.
- Pause now contains Settings with saved scorebox position and blue-sky/green
  backdrop, Resume and camera inspection. All nine authored angles are available
  while paused; normal live framing stays stable.
- Major result text is larger and higher; batting zone/aim guides are more
  transparent. Pitching guides are unchanged. A clickable repertoire panel owns
  player-Pitcher count, Stamina and fatigue stage.
- AI varies the quiet setup before windup independently of the smooth delivery.
  F3 records now include AI swing/read/error values to investigate fastball
  contact with a representative sample rather than an unsupported hitting nerf.
- Automated feedback coverage checks menu/input boundaries, saved settings,
  HUD bounds, Pitch selection locking, cadence and remote Pitcher control floors.
  Physical coverage includes a tenth actual Jolt launch for charging before Single.
- Full `python3 tools/verify.py` passed on Godot 4.7.2 after the final audit:
  parse/lint/import, feedback and player-flow scenes, two complete live matches,
  100 seeded match replays, ten Jolt fixtures, core regressions, QC export and
  main-scene smoke. Local logs: `builds/verification/20260921T034453354987Z`.
- Human feedback supports the current spacing and Pitch movement baseline.
  Follow-up rendered UI/camera review and meaningful F3 distributions remain
  required; the vanilla fun gate is not yet greenlit. Season/meta work stays deferred.

## Final pre-playtest pass — 2026-09-21

- `P` pauses play; `V` cycles the four inspection views while the camera keeps
  its smooth interpolation. `P` resumes and restores the previous gameplay,
  setup, or presentation view. Closing a setup panel during inspection returns
  to the appropriate gameplay view instead.
- Fixed bat and Batter animations inheriting always-process mode from the lab:
  their swing poses now freeze with the ball instead of continuing during pause.
- Pause coverage checks actual camera movement plus frozen actors, swing poses,
  match/release/result/presentation timers, and state across ready, windup,
  Pitch flight, Swing, ball-in-play, result hold, setup, intro, and Mechanics Lab.
- Complete live-match checks now continue through the settled final-score outro
  and `R` into a fresh match, retaining the completed match's QC export.
- This is the handoff for human playtesting, not clearance of the fun gate.
  The post-approval roadmap remains `SOURCE_OF_TRUTH.md` §35: Phase 4 Season
  Shell first, followed by build systems, opponents/fields, persistence, and
  production/content scale. No season or meta systems were implemented here.

## Player-flow hardening — 2026-09-20

- Releasing Space, left mouse, or controller A while debug-paused cancels the
  uncommitted delivery. Resuming cannot auto-throw it or spend Stamina; a fresh
  hold/release still launches normally.
- Refused Mechanics Lab entry preserves pause. Safe Match/Lab round trips
  restore the original ready message instead of a stale pause cue.
- Pitching Staff and Field Setup preserve the Pitch target against incidental
  mouse, arrow-key, and stick movement. Escape closes display options first,
  then returns from defensive setup to the pitching camera.
- Added live player-input coverage for Contact/Power hits, an early miss,
  duplicate swings, readable result holds, next-Batter readiness, pause of
  physical balls, and restarting during ball-in-play.
- Smooth, readable play remains the priority. Delivery timing, result holds,
  camera interpolation, scoring geometry, and physics coefficients are unchanged.
- Headless input/physics checks do not replace rendered camera and human feel QC.

## Live match and Jolt follow-up — 2026-09-20

- Added 100 seeded state-machine matches with deterministic replays and an
  explicit extra-inning/walkoff scenario.
- Added two full live-scene scripted-player matches with stall watchdogs.
- Added nine actual Jolt ball fixtures covering rolling lines, wall/HR/Deep Air,
  and Pitcher clean/bobble/miss results. See `VERIFICATION.md` for isolation limits.
- Fixed the Pitcher minimum-height gate that excluded physical rolling balls.
  Mound radius, scoring floors, Contact/Power, and aero coefficients are unchanged.
- Rendered camera QC and representative human F3 distribution sampling remain pending.

## Pitching regression follow-up — 2026-09-20

- Full `python3 tools/verify.py` pass on Godot 4.7.2: parsing/lint, import,
  core regressions, QC export persistence, and main-scene smoke.
- Nominal aim now rejects candidates outside the existing 1.25 cm solver
  tolerance. Previously, an underpowered Eephus could return a crossing far
  below the chosen target as a successful solve.
- An actual failed delivery is tested to preserve Stamina, Pitch count,
  throw number, and records; an explicit higher-effort retry launches normally.
- The exhausted Slider's centerward correction already achieved its intended
  target. Replaced the confounded fresh-vs-tired lateral comparison with a
  same-trajectory correction test, retaining velocity/spin-loss and reach checks.
- Clearance still covers 180 launched flights. Eight minimum-effort Eephus
  target cases now explicitly retry at normal effort in the test matrix.
  The game does not silently boost the player's effort.
- No velocity, fatigue, Contact/Power, aerodynamic, or scoring coefficients changed.

This supersedes the three-failure status in the initial tooling report below.

## Verification tooling update — 2026-09-20

- Godot 4.7.2 is available in this development environment.
- One-command verification and reproducible tool setup: `docs/VERIFICATION.md`.
- Import, automatic QC export tests, and headless main-scene smoke pass.
- Core regressions run but fail three pre-existing pitching assertions:
  exhausted Slider center tendency and two low-effort Eephus aiming cases.
- Corrected an off-tree fielder fixture in the match-suspension test.
- Completed plays automatically save session JSON; F3 displays its path.
- No gameplay coefficients or boundaries changed; focused human QC remains pending.

The initial tooling update supersedes earlier statements below that the engine run
was unavailable or wholly pending. The follow-up above records the full passing suite.

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
- [x] persistent 3×3 Primary Fielder layout with field-authored legal cells
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
- [x] one confirmation per new player-controlled Batter with automatic
      between-Pitch cadence inside the plate appearance
- [x] readable Pitcher set / windup / delivery telegraph
- [x] pointer-projected batting aim with left-click Contact and right-click Power
- [x] full-simulation `P` debug pause
- [x] visible clickable four-player pitching-staff selector between batters
- [x] initial authored Middle Center depth clearance from the Pitcher
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
- [x] initially added visibly reactive automatic Pitcher defense in a 0.95 m
      mound envelope; later hardening reduced the final radius to 0.60 m
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
      (superseded by automatic dead-ball continuation below)
- [x] added roughly one second to the readable dead-ball hold and automatic
      continuation within an unfinished plate appearance on offense and defense
- [x] reduced Primary Fielder movement speed, horizontal/vertical reach, and
      clean-control generosity; debug coverage now matches actual reach
- [x] added deterministic reach/height rejection regressions
- [ ] Godot 4.7.2 import/headless regression validation
- [ ] hands-on cadence, release meter, Pitch visibility, bat, and defense retest


## Phase 3 timed-contact and broadcast-flow revision — runtime validation pending

This revision supersedes manual click-through between Pitches while retaining
one deliberate confirmation for each new player-controlled Batter.

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
- [x] automatic seeded one-to-three-shot `GAME START` presentation
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
- [x] broadcast shot sequences now retain the typed `Shot` enum through their
      arrays and return values, removing the adjacent function-boundary warning
- [x] Pitch execution now preserves the explicit deterministic execution seed;
      a stale built-in identifier from the warning-cleanup rename was removed
- [x] an AI aim-solver failure now rolls back the unspent Pitch and schedules a
      known-good center fallback instead of leaving the offense soft-locked
- [x] Pitch choice, effort, Pitcher/Primary Fielder roles, and Fielder anchor
      lock when delivery begins so live play cannot observe a different plan
      than the release
- [x] queued batted balls disconnect their collision callback before replacement,
      and live telemetry guards a missing resolver state
- [x] targeted regressions cover execution-seed preservation, failed AI Pitch
      recovery, pre-delivery editing, and delivery-time setup locking
- [x] supplied 2026-09-19 recordings re-audited against the current contact,
      Swing, receiver, and camera paths; observed crash paths have explicit guards
- [x] all current GDScript passes `gdparse` and `gdlint` static checks on
      2026-09-20
- [ ] Godot 4.7.2 import/headless regression validation
- [ ] hands-on timed Swing, receiver, handed bat, cadence, release meter, and
      intro/outro validation


## Phase 3 interaction and presentation hardening — runtime validation pending

The 2026-09-20 follow-up found a concrete handedness inversion and asked for a
cleaner playable-match shell before the next human QC pass. Implemented:

- [x] corrected `BatActor` pivot to the same handed side as the Batter's hands
      and reversed the mirrored yaw/tilt path so each bat loads at the back
      shoulder and drives toward the front shoulder
- [x] added handed stance/contact-direction regressions for both sides
- [x] added a visible procedural player-Pitcher load/delivery pose driven by
      the same release-meter progress used for execution
- [x] shortened the player release meter, moved the gold sweet spot near 85%,
      and added a small post-cue overdrive tail
- [x] made overdrive category-aware: bounded Fastball velocity or breaking
      finish in exchange for explicit command and Stamina penalties
- [x] serialized release overdrive in deterministic play records and covered
      its velocity/break/control relationships with regressions
- [x] made F2 suspend and resume the existing match at safe stopped pre-Pitch
      boundaries instead of constructing a new match
- [x] added seeded still, zoom-in/out, pan-left/right, and tilt-up/down camera
      motion to the two-/three-shot intro/outro director
- [x] lengthened presentation shots and reduced the dark overlay opacity
- [x] replaced the large text scoreboard with a compact broadcast-style
      scorebug for score, inning, count, outs, bases, Batter, Pitcher, Pitch
      count, and Stamina
- [x] first moved prompts/results into a dedicated event layer and retained
      pitch/contact/fielding telemetry only in the F1 debug layer; the later
      HUD pass relocated that layer beneath the scorebug and removed its box
- [x] reduced persistent controls text and removed redundant match-state prose
- [x] added regression coverage for actual bat transforms, Pitcher pose,
      release tuning, scorebug state, presentation motion, F2 resume/refusal,
      and play-record overdrive serialization
- [x] all current GDScript passes `gdparse` and `gdlint` static checks on
      2026-09-20
- [ ] Godot 4.7.2 import/headless regression validation
- [ ] hands-on bat direction, player windup, F2 resume, release overdrive,
      scorebug/result stack, and moving intro validation


## Researched bat-swing synchronization pass — runtime validation pending

The pre-QC audit compared the supplied Alan Nathan collision/optimization
papers, Welch et al.'s measured batting sequence, current Statcast swing
definitions, the 2026-09-19 recordings, and the existing 240 Hz resolver. The
authored Contact/Power speeds and attack angles remain reasonable; the concrete
defect was disagreement between visible animation and mathematical contact.

- [x] visible bat now reaches a square-across-plate pose exactly at each
      profile's authored sweet-spot time
- [x] loaded stance begins genuinely behind the back shoulder, then follows a
      single drive/contact/front-shoulder-finish path with no circular recovery
- [x] opposite handedness mirrors stance and finish while sharing the same
      square contact orientation
- [x] independent Batter hands and torso now follow the bat's profile timing
      instead of remaining static during the equipment animation
- [x] authoritative virtual swing center now travels on the profile's attack
      plane and crosses the aimed X/Y point at the sweet spot
- [x] timing/vertical offset therefore feed the existing launch and signed-spin
      model without adding mesh collision or hidden aim assistance
- [x] regression coverage added for back-shoulder depth, synchronized contact
      pose, non-wrapping finish, Batter motion, and attack-plane travel
- [ ] Godot 4.7.2 import/headless regression validation
- [ ] hands-on right-/left-handed stance, contact synchronization, swing feel,
      miss continuation, and contact-crash validation


## Live-foul, defensive-rule, and broadcast-HUD pass — runtime validation pending

The next pre-QC audit reconciled Wiffle ground-ball/foul rules with the existing
BallPlayResolver and separated objective asymmetries from small-sample feel.
Primary Fielder speed/reach remains symmetric for both teams and was not raised.

- [x] foul contact now launches a visible physical Jolt ball instead of ending
      invisibly at contact
- [x] live foul balls can be caught by the Pitcher or Primary Fielder for an
      Out; first ground/out-of-play contact resolves the Foul count
- [x] clean control of a still-moving fair grounder before the Single line is
      an Out, while stopped or boundary-crossed balls retain at least a Single
- [x] initially placed the starter Single line inside the front of the small
      mound reaction envelope; the final field-balance pass below supersedes
      that provisional plane while preserving Double/Triple rules and the
      modestly lowered Home Run wall
- [x] kept Pitcher defense inside a 0.60 m reaction envelope and removed the
      former edge-trigger mismatch that spent its only attempt outside actual
      control reach
- [x] increased deterministic AI timing and aim error as physical plate speed
      rises, while preserving Pitch/location awareness as earned compensation
- [x] moved and narrowed the broadcast scorebug to the lower-right and placed
      boxless Ball/Strike/Foul/result, pitch-speed, and exit-velocity reports
      directly beneath it for both player roles
- [x] removed redundant normal-play effort/instruction prose while retaining
      the release bar and detailed F1 diagnostics
- [x] moved the batting camera off the loaded-barrel sightline and added a
      subtle bounded bat/hand load response to batting aim
- [x] corrected player-facing field Left/Right labels and ordered the setup
      grid Deep, Middle, Shallow from top to bottom
- [x] converted Pitching Staff to a pre-Pitch submenu with a dedicated wide
      camera and uncropped four-player list
- [x] gave exactly one player-team prototype a six-Pitch repertoire
- [x] added static regression coverage for live fouls, moving ground outs,
      field labels, Pitcher envelope, speed challenge, repertoire count, and
      aim-reactive bat limits
- [x] all GDScript passes `gdparse` and `gdlint` static checks on 2026-09-20
- [ ] Godot 4.7.2 import/headless regression validation
- [ ] hands-on foul visibility/catches, ground outs, Pitcher chances, AI
      fastballs, boundary balance, submenus, HUD telemetry, and batting view


## Phase 3 presentation and defensive-variety pass — runtime validation pending

This pass answers the 2026-09-20 HUD, framing, field-balance, and defensive
readability playtest without expanding into season/meta scope.

- [x] reduced and tightened the scorebug, anchored it lower at bottom right,
      and added selectable bottom-right, top-left, and top-right layouts
- [x] added a tiny bottom-left display menu for HUD position and procedural
      sky/gray-backdrop selection
- [x] split small Ball/Strike/Foul and Pitch-speed calls beneath the scorebug
      from centered major transition/result text with dark-blue outline/shadow
- [x] removed normal-play WINDUP/DELIVERY/TRACK THE BALL and Field View helper
      prose while retaining detailed F1 telemetry
- [x] kept a compact selected-Pitch identifier visible during player defense
- [x] moved the batting camera nearly to center with only a small handed offset
      and reframed Field Setup to include home plate and the Batter
- [x] added two broadcast angles and a deterministic one-long-take intro option
      alongside the existing two-/three-shot packages and motion operations
- [x] made left-handed prototype players uncommon rather than evenly split
- [x] added deterministic AI Fielder repositioning between player Batters
- [x] added swept-segment Pitcher defense so fast comebackers cannot tunnel
      through the intentionally small mound envelope
- [x] kept behind-mound Primary Fielders out of the Pitcher's immediate lane
- [x] separated the Single and Deep Air boundaries, moved/lowered the wall
      modestly, and added subtle foul-line presentation
- [x] broadened deterministic weak/strong contact speed and physical flight
      variation through nonlinear exit transfer plus inherited orientation and
      signed side/gyro spin
- [x] made opponent Batters swing slightly more while adding enough execution
      spread to create additional swings-and-misses rather than a raw buff
- [x] added static regressions for the revised safe-line geometry, swept
      Pitcher reaction, defender territory, roster handedness mix, batted-ball
      orientation/spin transfer, and one-shot presentation timing
- [x] all GDScript passes `gdparse` and `gdlint` static checks on 2026-09-20
- [ ] Godot 4.7.2 import/headless regression validation
- [ ] hands-on HUD anchors/menu, sky, camera framing, Pitcher/Fielder territory,
      AI variation, batted-ball variety, and field-boundary validation


## Swing, defensive-camera, and field-readability pass — runtime validation pending

This pass incorporates the supplied real-swing phase/arc references and the
2026-09-20 field screenshots without changing ContactResolver authority.

- [x] replaced the visible two-key swing interpolation with a staged loaded
      stance, slot/drive, square contact, extension, and decelerating finish
- [x] mirrored the complete path for left/right Batters and synchronized the
      independent torso, weight shift, hands, and bat
- [x] retained bounded aim-driven height/tilt through contact instead of
      erasing the presentation offset at the sweet spot
- [x] preserved the existing profile timing, attack plane, contact regions,
      and physical launch authority
- [x] made the starter back wall a lighter slate-blue surface and changed the
      strike-zone frame to thicker unshaded warm-white bars for contrast
- [x] first moved the Single and Deep Air boundaries closer while increasing
      their separation; the final field-balance pass below supersedes those
      provisional plane positions
- [x] added role-aware ball-in-play perspective so player defense pulls wider
      and tracks from the pitching side instead of flipping behind the Batter
- [x] added static regressions for staged/mirrored swing transforms, retained
      aim posture, closer boundary geometry, Pitcher opportunity, and defensive
      camera orientation
- [x] all GDScript passes `gdparse` and `gdlint` static checks on 2026-09-20
- [ ] Godot 4.7.2 import/headless regression validation
- [ ] hands-on swing arc/hand attachment, wall/zone contrast, boundary balance,
      and player-defense ball tracking


## Starter-field scoring and Pitcher-lane pass — runtime validation pending

The final pre-handoff audit measured the scoring planes against the full field,
sampled the current Contact/Power launch model, and reviewed every defensive
anchor against the pitching sightline.

- [x] kept the 23.4 m wall because the starter field is already large enough
      for a compact plastic-ball game
- [x] moved the Single plane to 14.8 m, beyond the full 0.60 m Pitcher envelope
- [x] moved the Deep Air plane to 18.5 m, creating distinct 3.7 m Single/Deep
      and 4.9 m Deep/wall territories instead of a 1.6 m stripe pair
- [x] retained the rule distinction that Deep Air is only a Double floor for
      untouched airborne balls; grounders still require the wall
- [x] left Contact/Power transfer and aerodynamics unchanged until normal-play
      F3 records establish an actual result distribution after the geometry fix
- [x] disabled Shallow Center and Middle Center as reserved Pitcher-lane cells
      while preserving Deep Center and all six side anchors
- [x] made direct selection, cycling, defaults, and AI positioning honor the
      same legal-anchor set
- [x] strengthened regression coverage from swept Pitcher-radius detection
      through a clean moving-comebacker Out result
- [ ] Godot 4.7.2 import/headless regression validation
- [ ] hands-on plane spacing, legal anchor UI/AI, Pitcher reaction, and F3
      result-distribution sample


## Simulated starter-field calibration — runtime validation pending

A follow-up audit stopped treating the visible lines as generic hit-distance
markers and evaluated them against their actual resolver semantics, the current
Contact/Power launch equations, the 23.4 m wall, and the fixed mound envelope.
A 100,000-fair-ball proxy plus low/base/high aerodynamic sensitivity cases
supported a closer Single plane without changing contact or aero coefficients.

- [x] moved the Single plane from 14.8 m to 10.5 m, 3.216 m in front of the
      Pitcher and close to the classic half-field proportion without copying it
- [x] moved Deep Air from 18.5 m to 17.0 m, leaving 6.5 m between scoring
      planes and 6.4 m from Deep Air to the existing wall
- [x] preserved Deep Air as an untouched-airborne Double floor rather than a
      universal Double line; ground/bounce balls still need the wall
- [x] added a dedicated clean-moving-comebacker Out exception inside the
      existing 0.60 m Pitcher envelope so the closer Single plane does not
      erase visible Pitcher defense
- [x] kept stopped balls and Pitcher bobbles safe and prevented the exception
      from erasing a Double-or-greater result floor
- [x] added F3 calibration fields for exit speed, launch angle, spray, first
      ground position, resolution position/reason, result floor, and defender
      touch
- [x] updated static regressions for the new geometry, crossed-Single Pitcher
      control, and JSON-safe calibration records
- [ ] Godot 4.7.2 import/headless regression validation
- [ ] hands-on result distribution, first-ground distribution, rolling-ball
      crossings, and Pitcher clean/bobble/miss validation


## Pitch-lane clearance and charging defense — runtime validation pending

This revision supersedes the unpushed all-anchors-behind-mound interpretation.
The user clarified that side defenders may start shallow and may charge in
front of the Pitcher after contact; visibility and non-overlap are the rules.

- [x] restored starter side anchors to X +/-5.5 m, with depth rows 8.5/14.0/19.5 m
- [x] retained disabled Shallow Center and Middle Center cells in every selection path
- [x] replaced the post-contact depth clamp with local swept body-clearance routing
- [x] retained top-down orthographic Field Setup and perspective restoration
- [x] moved the existing playability-suite call from the bat suite to the core
      runner, avoiding the accidental duplicate call in the prior local commit
- [x] added deterministic scoring, movement, projection, and 180-flight Pitch/sightline
      clearance regression coverage; Godot execution remains pending
- [x] gdparse, gdtoolkit 4.3.4 gdlint, and diff whitespace checks passed;
      independent Python routing-math checks passed for four approach directions
- [x] added field-geometry metadata alongside the existing F3 records
- [ ] Godot 4.7.2 import/headless regression validation
- [ ] human QC of wild-Pitch sightlines, shallow side anchors, charging/routing,
      camera transitions, rolling crossings, and Pitcher clean/bobble/miss plays

Single 10.5 m, Deep Air 17.0 m, wall 23.4 m, HR height 3.25 m, and all
Contact/Power/aero coefficients remain unchanged. The earlier claim that the
playability suite was unreachable was incorrect: it was called by the bat
suite. The earlier attribution of the reported line-spacing problem to camera
perspective was not established by a current-build runtime observation.

## Canonical post-fun-gate roadmap — not implemented

The ordered roadmap now lives in `SOURCE_OF_TRUTH.md` §35. Phase 3 and the
sport fun gate remain the current priority.

- [ ] Phase 4 — Season Shell
- [ ] Phase 5 — Seasonal Build Systems
- [ ] Phase 6 — Opponents, Fields, Leagues, and Difficulty
- [ ] Phase 7 — Persistent Club Layer, including earned post-season player-card
      packs and draftable-player unlocks
- [ ] Phase 8 — Production and Content Scale
