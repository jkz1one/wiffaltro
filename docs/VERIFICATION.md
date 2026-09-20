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
two live matches, physical-ball fixtures, QC file export, and a 120-frame
main-scene smoke. Engine errors fail even when Godot exits with zero;
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
  and overall frame/process budgets catch stalls. Synthetic records stay in
  dedicated test files, outside `user://qc`, and are removed after the run.
- `physical_ball_test.tscn`: nine isolated actual Jolt launches through the
  production field, ball body, contact signals, and lab physics loop. Checks
  short settling, grounded crossings of both internal lines, ground/fly wall
  contacts, HR clearance, untouched Deep Air, and pitcher clean/bobble/miss.
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
deliberately unrepresentative. Do not use these records or nine hand-picked
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
