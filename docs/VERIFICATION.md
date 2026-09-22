# Fast verification and playtest records

One-time setup (Python 3.9+, Linux x86-64 or macOS):

```sh
python3 tools/setup_verify.py
```

This downloads Godot **4.7.2 stable**, checks its official SHA-512 checksum,
and installs `gdtoolkit==4.3.4` in an isolated Python environment. Everything
goes in ignored `builds/tooling/`. It does not replace an installed Godot.
Linux setup has been exercised here; macOS setup still needs a local check.

Then, from the repository:

```sh
python3 tools/verify.py
```

An existing engine can also be selected with `--godot /path/to/Godot` or
`GODOT_BIN`. Version mismatches fail explicitly. The runner checks whitespace,
GDScript parsing/lint, engine import, core regressions, seeded match soak,
player-input flow, playtest-feedback UI/cadence and follow-up checks, pitch quality, two live matches,
season progression/save/menu handoffs, camera geometry,
physical-ball fixtures, QC file export,
and a 120-frame main-scene smoke. Engine errors fail even when Godot exits with zero;
regression scenes must also print their completion marker. Every engine step
has a timeout (default 180 seconds, adjustable with `--timeout`).

Import/runtime checks use a temporary copy of `project.godot`, `src/`, and
`assets/` if present. The source files include current uncommitted edits.
Protected `.codex/` and `upload/` directories are never copied or scanned by
this runner. Logs and a machine-readable `summary.json` remain under
`builds/verification/<UTC timestamp>/`, including HEAD and working-tree status.
Independent runtime checks continue after a regression failure, but the overall
command still exits nonzero. No hosted CI is triggered.

## Infinite win/loss camera verification — 2026-09-22

Full 27-step Godot 4.7.2 verification passed without engine errors or warnings at
`builds/verification/20260922T050216647933Z`, based on published main `adda641`.

- Core presentation checks run three complete repeating cycles, with non-still
  motion and Continue readiness preserved across shot changes.
- The actual presentation/camera update runs 80 simulated seconds, visits all
  four scenic angles, and preserves final score, game clock and play records.
  Maximum per-frame camera displacement in that fixture is 0.479 m at 60 Hz;
  it uses interpolation rather than positional cuts. Pause freezes the shot clock.
- Season-menu checks leave each completed result rolling across eight angle
  changes, verifying that Continue remains visible and the game commits once.
- Existing full live matches cover ending, HR-before-outro ordering and restart.
  Existing match-soak coverage confirms tied regulation enters inning six, both
  halves receive the extra runner and a home lead walks off. Tie rules did not change.
- The same suite retains all recent handedness/routing, wall-visibility, chase,
  ratings, bullpen, save/migration and statistics checks. Rendered smoothness and
  subjective pacing still require human QC.

## Attribute access, tracking and chase audit — 2026-09-22

Baseline: clean local/GitHub main `3228af1`. Godot 4.7.2 / gdtoolkit 4.3.4.
Full 27-step verification passed with no engine errors or warnings at
`builds/verification/20260922T045643447476Z`, including both real live matches,
all prior routing/handedness/save/statistics/physical-ball checks, and the new
chase/visibility/UI coverage. Human rendered/feel QC remains open.

Targeted checks used only a staged copy of `project.godot` and `src` under
ignored builds; no root import or protected-directory scan.

- The expanded camera audit failed before the fix: 874 obstruction hits across
  5,760 sampled frames. The same paths then passed with zero obstruction hits
  and zero off-screen balls. Fixtures include both venues/player roles, low wall
  approaches on three lateral paths, the live pole, lateral scenery and high
  carry. Existing handed batting sightline/aim/stable-pitch checks still pass.
  These are static-mesh bounds tests, not rendered or motion-comfort approval.
  Before/after logs: `builds/qc-camera-red.log`, `builds/qc-camera-green.log`.
- Ratings pages fit the headless viewport and remain read-only; pause inspection
  still freezes a real pitch. Season tests cover new Base behavior and every
  legacy saved preset. Bullpen checks compare throwing labels to player data
  and check all HUD anchors and multiline text widths.
- `ai_chase_test.tscn` runs 720 real Four-Seam launches through the production
  flight actor, current-motion perception, count/awareness decision and swing
  initiation. Controlled counts and refreshed arms isolate the path; four-pitch
  observation groups repeat it. This is not a complete game or human distribution.
  Every recorded chase starts an actual swing; every take leaves it unstarted.
  The scene is included in `python3 tools/verify.py`.

Selected chase results (right/left batting hand; 40 launches per case):

| Aim X magnitude | Count | Actual swings R / L | Mean modeled chance R / L |
| --- | --- | --- | --- |
| 0.50 m | 0–0 | 13 / 12 | 25.9% / 25.7% |
| 0.65 m | 0–0 | 8 / 6 | 11.5% / 11.7% |
| 0.95 m | 0–0 | 3 / 4 | 2.3% / 2.2% |
| 0.50 m | 0–2 | 19 / 19 | 40.3% / 40.1% |
| 0.50 m | 3–0 | 10 / 10 | 15.0% / 14.9% |

Zone half-width is 0.43 m; aim is not the actual plate crossing or visual read.
The audit's mean visual-read X magnitudes for the first three rows were about
0.487 / 0.632 / 0.931 m. Finite seed counts need not equal modeled probabilities.
No universal no-chase defect reproduced; this does not resolve the reported
15 consecutive takes. Keep that human issue open for F3 evidence. No AI,
trajectory, fatigue, field-boundary or contact-transfer tuning was made.

## Field-scale research, no gameplay changes — 2026-09-22

Baseline local/GitHub `aa02b7e` was clean. The full 26-step pinned-engine suite
passed at `builds/verification/20260922T042906959168Z`. No `src/`, game resource,
model, camera, physics or save changes accompany this research.

Opt-in `python3 tools/audit_field_scale.py` passed a disposable-copy import and
432 Jolt trajectory comparisons at `builds/field-scale-audit/20260922T042840Z/`,
without engine errors/warnings. Its GDScript parser/lint and Python compilation
checks also pass. It is outside the normal gameplay regression suite because
these are sensitivity measurements, not desired hit-rate assertions.

The report `FIELD_SCALE_AND_PROGRESSION_AUDIT.md` records contact construction,
omitted defenders/obstacles/AI, current versus hypothetical scoring layouts,
measured avatar bounds, a separate Single-floor control example, primary sources,
recommendations and human-QC gates. JSON/logs stay in ignored builds; the tool
reproduces them. These synthetic contacts must not enter the human F3 dataset
or be described as match balance, aesthetic approval or permission to retune.

## Pitch identity and labels audit — 2026-09-22

The physical correction and expanded checks below supersede this first pass's
unresolved diagnosis. Resource identity alone did not establish correct flight.

Reconciled local/GitHub main `61999fa`. Final full `python3 tools/verify.py`
passed all 23 steps on Godot 4.7.2 and gdtoolkit 4.3.4 at
`builds/verification/20260922T034413264888Z`. The earlier audit run also passed
before restoring full picker labels; the final run includes that correction.

`pitch_routing_test.tscn` covers all 142 authored repertoire entries across
48 players, each via number-key dispatch and button signals (284 launches).
Three additional player launches use deliberately reversed Drop/Four-Seam
orders through Mechanics Lab return, replacement and inning transitions. An
AI delivery separately checks its preselected resource identity. Assertions
compare visible names, selected resources, flight parameters/state and F3 IDs;
verify the selected aerodynamic recipe and content immutability; and reject
key/button changes during flight. Twenty season save/restores check that lineup
reordering preserves player, Pitcher and Fielder identities and their definitions.
Nine full authored Pitch names fit without clipping at all three HUD anchors.

No crossed Drop/Four-Seam identity was reproduced. Both recipes and all other
pitch resources/solver files are unchanged since the first Season Shell
(`937ce2f`); the new pitching strategy selects among those recipes. The picker
did abbreviate delivery names, now corrected. Number keys remain repertoire
slots, not universal pitch-family keys. Half-inning/new-Pitcher resets remain
slot 1; all authored season pitchers owning Drop start with Four-Seam in that slot.
These facts do not establish the cause of the user's exact incident without a
record or reproduction. Headless checks do not approve rendered feel or balance.

## Human QC follow-up: physical pitches, switch hitters, stats and venues

On 2026-09-22, the human recording showed left-handed Casey Rivers. A targeted
physical reproduction failed before the correction (`builds/pitch-handedness-red.log`):
left-handed Four-Seam produced downward lift and Drop upward lift. Spin had been
mirrored like a position instead of an axial vector. The fix preserves vertical
identity and mirrors lateral flight, hole direction and seeded perturbations.
No pitch recipe, rating, aerodynamic coefficient or fatigue curve was retuned.

Final full `python3 tools/verify.py` passed **26 steps**, without engine warnings
or errors, on Godot **4.7.2** and gdtoolkit **4.3.4**:
`builds/verification/20260922T040843826880Z`. This includes the earlier 25-step
pass plus the new switch-hitter input/stance/contact checks. A subsequent
neutral-final opening-role text correction passed disposable import and the
affected venue/stats scene again (`builds/final-role-import.log` and
`builds/final-role-venue.log`).

- **Physical pitch identity:** 320 paired trajectories across all nine families,
  three effort levels and mirrored targets, with nominal and seeded execution
  at fatigue 0, 0.8 and 1. Sampled position and velocity at three depths agree
  under lateral reflection within 0.002 m / m/s. Drop, Four-Seam and Riser have
  explicit vertical-sign assertions for both throwing hands.
- **Measured induced movement:** against the same launch with lift/asymmetry
  disabled, Four-Seam is +2.294 m for both hands (left was -2.316 m), Drop is
  -3.504 m for both hands (left was +3.353 m), and Riser is +4.127 m for both
  hands (left was -4.316 m). These are diagnostic deltas, not literal rise above
  release, target tuning values or human balance samples.
- **Reach limits:** one nominal low-effort Eephus target is unsolved in both
  hands. Three executed Eephus pairs do not cross the plate in either hand.
  The test asserts equal reach and compares movement where crossing occurs;
  it does not claim every fatigued/low-effort launch is hittable. Existing
  failed-pitch recovery checks remain in the suite; no broad retuning followed.
- **Selection pathways:** existing 48-player/142-slot keyboard/button coverage,
  actual resource/recipe/F3 identity, transition fixtures and reordered save
  restores pass alongside the new physical assertions. Full names remain visible.
- **Switch hitters:** both Tess Vale and Val Morgan, starting on either side.
  Viewport-dispatched button clicks change sides exactly once without starting
  delivery. B, visible cue, scorebug, avatar, bat and actual swing intent agree;
  early contact pulls to the corresponding field. Intro/pause/delivery/timeout
  locks, ordinary hitters, next-batter availability and all HUD anchors are checked.
- **Pause statistics:** both teams and tabs show roster identities, seven ratings,
  full pitch names and actual completed-hit attribution. Inspecting during a live
  pitch leaves its position, match clock and performance snapshot unchanged;
  bounds, scrolling/footer and Esc → Pause → resume pass.
- **Venues:** twelve-game progression and save/reload, five regular home/five
  away fixtures, hosted semifinals and neutral final; actual loaded field, intro,
  pregame name, legal anchors and identical collision signatures. Away decoration
  adds no colliders. Neutral-final opening text matches either nominal role.
- **Regression coverage:** real AI/contact/Jolt matches complete at both parks;
  scoring, saves/backup/migrations, mixed old/new stats, abandoned-game exclusion,
  camera geometry, pitch execution, input/pause, HR presentation, menu bounds,
  season progression and QC export pass. Live-match scores are scripted-player
  outcomes, not evidence of human difficulty balance.

The AI-read regression's previous fastball relative-improvement assertion depended
on the inverted left-handed flight. It now bounds mean error for every sampled
family and retains relative improvement for sliders. Current measurements and
this limitation are explicit in `SEASON_ENRICHMENT_AUDIT.md`; production AI batting
logic was not altered to satisfy the check.

All engine imports used disposable source copies. Protected directories were
excluded. These checks do not prove absence of every bug or replace human QC.
Rendered away-field appearance, switch cue readability, pause comfort and the
corrected pitches' subjective feel remain on the human route in `PITCH_BAT_LAB_TEST.md`.
No display/Vulkan renderer was available here; no rendered approval is claimed.

## Season flow / performance verification — 2026-09-21

Baseline main `6511a82` passed the full pinned-engine suite at
`builds/verification/20260921T172439177685Z` before gameplay hooks were edited.
The implementation passed all 22 verification steps at
`builds/verification/20260921T173411007379Z`, with no engine errors or warnings.
This includes the new `season-flow` scene plus all existing season, camera,
presentation, input, live-match, physics, core, export and smoke checks.

New coverage verifies:

- Correct player attribution before batting-cursor advancement, loaded walks,
  hit types, strikeouts, sacrifice RBI, substitution and walk-off handling.
- A twelve-game season through the actual match scoring methods, with stats
  saved/reloaded after every game and duplicate result commits rejected.
- Schema-2 score-history migration, malformed-stat rejection and stable player
  identity across lineup changes. The existing schema-1 migration also passes.
- Draft comparison context, hub → pregame → recap → next pregame navigation,
  visible fixed footers, horizontal bounds at 1280×720 and preserved lineup scroll.
- Balanced statistics from the existing drafted live match, which exercises
  actual AI, contact and Jolt; completed appearances and runs reconcile to the
  match state. The scripted human takes every Pitch, so this is not balance data.

After the full run, a final regular-season-standings label and targeted assertions
for mixed old/new stat history and abandoned-game exclusion were added. Both
affected scenes passed again; logs are `builds/season-flow-test.log` and
`builds/season-flow-shell.log`, with import in `builds/season-flow-import.log`.
Final parser/lint and staged whitespace checks also passed.

There is no rendered screenshot or human-feel approval from this environment.
Playtest the compactness, scrolling, keyboard focus, opponent context, result
recap, old-save coverage and reload behavior using `PITCH_BAT_LAB_TEST.md`.
No sport tuning or claim of passing the human fun gate accompanies this work.

## Automatic playtest records

Each completed play saves the current session to `user://qc/plays-*.json`.
The file contains engine version, source commit when running from a Git checkout,
tracked-dirty status, loaded field geometry, and the existing detailed records.
Each record includes `mode` (`match` or `mechanics_lab`). Exported games or
checkouts without Git report `commit: unknown`, rather than inventing a revision.
Revision metadata is captured on the first save; restart after changing code.

F3 still prints the existing JSON and now shows the absolute saved-file path.
The Godot editor's **Project > Open User Data Folder** also leads to the `qc`
folder. No console copying is needed. Saves replace the same session snapshot
via a temporary file. Repeated F3 presses do not add samples. Resetting creates
a new session file and preserves earlier sessions on disk. Saves contain
completed plays only; an interrupted active play is not a completed sample.
Save errors produce a warning, and F3 reports failure rather than claiming success.

Share the JSON files alongside any short videos/screenshots showing a problem.
Do not count both a saved file and its F3 console dump as separate samples.
Use `session_id` plus record order to identify entries. Follow the fair-ball
sampling rules in `PITCH_BAT_LAB_TEST.md` before proposing tuning.

## First runtime findings (2026-09-20)

Godot `4.7.2.stable.official.ed1daf0bf` now runs in the development environment.
The initial run passed import, QC export, and main-scene smoke but reported three
pre-existing assertion failures: exhausted Slider center regression, and two
low-effort Eephus aim targets. These also failed before the export/tooling edits.
The invalid scene-tree setup in the match-suspension test was corrected.

### Follow-up: full verification passing

The Eephus solver returned its best crossing even when it badly missed the
requested target. It now accepts only the existing 1.25 cm tolerance and
otherwise uses the safe retry path. The tested velocity-5 Pitcher at minimum
effort launches at 12.71 m/s: an angle scan confirms insufficient height for
the center/high fixtures. Tests cover rejection, a lower mathematical probe,
and accurate low/center/high targeting at 90% effort for both hands. An actual
delivery/retry test verifies no stamina/count/record cost for an unsolved throw.

The Slider assertion compared fresh and exhausted final lateral position,
conflating command correction with substantial loss of break. Instrumentation
showed the correction matching its intended weighted target (e.g. 4.226 m wide
to 0.507 m wide at 88% pull). Its replacement checks the same degraded
trajectory before/after correction, target accuracy, and unchanged speed/spin.
Existing fatigue velocity/spin-loss and plate-reach checks remain intact.

Full verification passes after this focused change. No physics coefficients
or fatigue tuning changed. Eight clearance cases with unsolved minimum-effort
Eephus targets retry at normal effort explicitly, preserving 180 launched
flights and all seven-anchor/camera checks. This is test coverage, not a silent
effort adjustment in the game.

## Extended runtime coverage — 2026-09-20

- `player_flow_test.tscn`: real lab scenes and the input dispatcher exercise
  keyboard, mouse, and controller release during pause, a fresh delivery after
  cancellation, refused/safe Match-Lab transitions, setup input isolation, and
  Escape navigation. Timed Contact and Power input produces real Jolt balls;
  checks cover duplicate swings, ball pause, resolution, unskippable result
  holds, next-Batter readiness, an early miss followed by automatic delivery,
  and restart during ball-in-play without stale callbacks. Paused camera tests
  check actual transform changes, frozen actor/Swing/timer state, and smooth
  restoration in gameplay, setup, intro, and Mechanics Lab. A center-Pitch
  fixture and test-only full-trajectory knowledge isolate batting input;
  they are not a human skill model or balance sample. Test exports stay outside
  `user://qc` and are removed. Headless dispatcher tests do not validate OS
  focus changes, rendered UI hit areas, or actual controller hardware.
- `match_soak_test.tscn`: 100 seeded complete state-machine matches and their
  exact replays. Uses scripted outcome inputs, not pitch physics. Checks count
  bounds, foul caps, score monotonicity, hit/run accounting, duplicate-start
  protection, completion budgets, and finished-state guards. A separate
  scoreless-regulation fixture verifies both extra-inning runners and a walkoff.
- `live_match_test.tscn`: two complete live-scene matches with automatic
  between-pitch cadence, timed player release, AI pitching/batting, actual
  contact and Jolt ball-in-play. The scripted player takes every pitch when
  batting and uses center targets at normal effort when pitching. Neither
  scores nor results are injected. A 20-second simulated progress watchdog
  and overall frame/process budgets catch stalls. Each match continues through
  its settled outro and a fresh-game restart while preserving its saved QC file.
  Synthetic records stay in
  dedicated test files, outside `user://qc`, and are removed after the run.
- `playtest_feedback_test.tscn`: nested pause/settings, saved display preferences,
  GUI-consumed release cancellation, repertoire selection and delivery locks,
  panel bounds at every scorebox anchor, batting zone opacity, 100 seeded quiet
  sets, and remote Pitcher control at a same-frame Single crossing. Checks that
  stopped balls and Double floors stay safe and ineligible pursuit stays still.
- `pitch_quality_test.tscn`: 324 seeded trajectories across all nine families at
  fresh, 20% remaining and empty Stamina. Checks above-ground plate arrival,
  broadly hittable ordinary-target locations, gentler working-band speed loss,
  and weaker stuff/command at empty Stamina. This is not a human batting model.
- `playtest_followup_test.tscn`: actual HR carry and walk-off timing, pause during
  carry, single scoring, wider celebration shot, tactical timeout limits and
  pitch-choice preservation, fatigue-based AI substitutions, no mound re-entry,
  retained batting/fielding eligibility, chase-choice samples and Esc-only pause.
- `physical_ball_test.tscn`: twelve isolated actual Jolt launches through the
  production field, ball body, contact signals, and lab physics loop. Checks
  short settling, grounded crossings of both internal lines, ground/fly wall
  contacts, HR clearance, untouched Deep Air, pitcher clean/bobble/miss, and
  actual Pitcher movement to cleanly field a slow grounder before Single,
  safe charging control after Single, and a nearby airborne catch.
  Primary defense is disabled only in these fixtures to isolate each rule.
  Ground and wall cases require actual collision-contact evidence.

Physics scenes use `--fixed-fps 60` for accelerated fixed-step execution,
without changing the configured 60 Hz Jolt rate or the 240 Hz Pitch solver.
This is not a claim of cross-platform bit-exact Jolt determinism.

The physical test exposed a production bug: PitcherDefense rejected ball
centers below 0.05 m, excluding a rolling ball with a 0.0365 m radius. The
cutoff now rejects only below-world positions. The fixed mound radius is still
0.60 m, and the moving/stopped, bobble, and result-floor rules are unchanged.
The clean fixture crosses Single before the mound attempt; bobble remains safe
and miss can continue to the wall. This is a collision-envelope fix, not tuning.

The two scripted live matches completed with 131/90 records and 37 ball-in-play
events each in the initial successful run. Their passive batting policy is
deliberately unrepresentative. Do not use these records or the hand-picked
launches as the meaningful human F3 distribution sample.

Rendered camera review remains pending: this environment has no configured
display server or Vulkan ICD. Headless checks do not render camera screenshots
and cannot approve line spacing, visual occlusion, or Mobile-renderer appearance.

The new line-scoring, 180-flight pitch-clearance, and defender-separation
assertions produced no failures. That is finite automated coverage, not proof
of every wild curve, actual match result distribution, or camera sightline.
Headless checks do not validate Mobile rendering or whether gameplay feels fun.
Human QC and the initial meaningful F3 sample remain necessary. No scoring,
Contact/Power transfer, fatigue tuning, or aerodynamic coefficients changed.


## Presentation polish regression coverage

`presentation_polish_test.tscn` checks five distinct bounded PCM waveforms,
audio-player routing, pause-time mute and saved reload, discarded muted events,
feedback handedness/misses/lifetime, HUD bounds at all anchors, all nine tooltip
entries and Stamina bar color thresholds, physical-ball trail/shadow lifecycle, bobble
and clean-control cues, wall cues, strikeout holds and delayed terminal outro.
Actual player-contact and physical-HR fixtures also check their cue hooks.

This checks events, data, timing and layout bounds. It does not listen to the
mix, render the shadow/trail, assess hover readability, or certify accessibility.
Sound and rendered comfort still require the human checks in `PITCH_BAT_LAB_TEST.md`.

Final verification: `builds/verification/20260921T051512553496Z` passed all stages
on Godot 4.7.2 with no errors or warnings. Audio fixtures allow two mixer/update
cycles at teardown before exiting the accelerated headless run.

## Final sport audit and Season Shell coverage

`camera_audit_test.tscn` checks both hands, plate/mound/aim projection bounds,
pointer round-trip on the actual contact plane, stable Pitch framing, useful
zone size and 90 sampled corridor rays per actor against the loaded bat and
Batter mesh bounds. The original 0.34 m side offset failed six bat-ray cases;
0.18 m passes with the prior height/depth/FOV intact. This is geometric evidence,
not a rendered camera optimum or all-pose visibility guarantee. Feedback also
checks inside against the visible Batter's actual side.

`season_shell_test.tscn` runs 60 seasons across missed playoffs, semifinal
elimination and championship paths. It checks each directed matchup exactly
once, one game per club per round, playoff seeds/venues, unique rosters, duplicate
result guards, complete standings/brackets, draft and midseason save replacement,
deterministic restore, corrupt-file preservation, menu bounds and actual lab
handoffs. Final scores are injected in the menu fixture to isolate navigation;
the separate live test uses real gameplay. Finishing saves before the outro is
dismissed; closing an unfinished game preserves the pending fixture.

The second complete `live_match_test.tscn` match now uses a drafted four-player
roster with the human-controlled team at home. Both home and away live matches
complete through the production AI/contact/Jolt rules and restart cleanly. The
scripted player still takes every Pitch, so their scores are not balance evidence.

Full verification passed at `builds/verification/20260921T054111248304Z`, including
the new season/camera checks and main-menu smoke, with no errors or warnings.
The main scene now tests menu startup; the dedicated scenes still test gameplay.
The final pause-menu change also passed a targeted import, lint and season test:
Leave Game is disabled after completion, with a hint to resume to the result.
Follow `PITCH_BAT_LAB_TEST.md` for the remaining rendered sport and season-flow QC.

## Ten-point season enrichment verification

Full Godot 4.7.2 verification passed at
`builds/verification/20260921T145620873351Z`, with no engine errors or warnings.
Static parse/lint, import, all earlier physics/input/quality suites, camera
geometry, two complete live matches and main-scene startup remain covered.

- `season_enrichment_test.tscn`: 48-player handedness and arsenal distribution,
  300 draft seeds with unique offers and at most one rare arsenal, 1,200 sets of
  count/personality/difficulty decisions, 240 physical Pitch read fixtures across
  both hands, schema-1 migration to schema 2, saved-pool continuity, duplicate-ID
  rejection, switch-hitting locks and actual roster-to-Fielder identity/rating.
- `season_shell_test.tscn`: 60 completed seasons now each save and restore the
  complete league/playoff results identically. Covers primary corruption with
  valid backup recovery and no-backup refusal, visible seven-stat headings,
  selection versus confirmation, difficulty handoff, midgame edit rejection,
  footer visibility and horizontal bounds of visible main-viewport menu controls.
  Popup windows have their own coordinates and are not mistaken for clipped body UI.
- `camera_audit_test.tscn`: in addition to corridor/aim checks, right-handed
  Batters must project screen-left of the plate, and left-handed Batters screen-right.
  Existing signed bat-path assertions now match that baseball convention.
- The final two authored style corrections (Nico Vega and Rowan Chase) received
  a targeted enrichment rerun; Breaking specialists must own and favor a breaking
  Pitch. Neither those definitions' ratings nor their arsenals changed in that correction.

The original cached Godot executable was found truncated before testing; it was
re-extracted from the intact cached archive and returned the exact pinned version.
That tooling repair did not change project source or the engine baseline.

The finite perception sample and strategy counts are documented in
`SEASON_ENRICHMENT_AUDIT.md`. They are not a human result-distribution sample,
nor proof of menu aesthetics, controller hardware or optimal batting feel.
