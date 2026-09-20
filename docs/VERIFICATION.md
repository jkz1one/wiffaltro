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
GDScript parsing/lint, engine import, core regressions, QC file export, and a
120-frame main-scene smoke. Engine errors fail even when Godot exits with zero;
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

The new line-scoring, 180-flight pitch-clearance, and defender-separation
assertions produced no failures. That is finite automated coverage, not proof
of every wild curve, actual match result distribution, or camera sightline.
Headless checks do not validate Mobile rendering or whether gameplay feels fun.
Human QC and the initial meaningful F3 sample remain necessary. No scoring,
Contact/Power transfer, fatigue tuning, or aerodynamic coefficients changed.
