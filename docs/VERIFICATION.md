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
