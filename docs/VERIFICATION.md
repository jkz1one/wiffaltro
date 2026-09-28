# Fast verification and playtest records

## Paid income sponsors, 2026-09-28

Full Godot4.7.2 gate `20260928T225022827419Z` passed43/43, including every existing gameplay,
camera, AI, ownership, growth, Gear, shop and save check. Seven complete live games passed:
two legacy, one maximum-development, one Gear, one Kit/Gloves, one Shoes/Alley and one genuine
paid-sponsor season game. Each retained its applicable outro/restart coverage. The sponsor game
produced129 records and22 balls in play, settled actual attributed statistics, rejected a
second result payment and saved/restored the exact cash total. Earlier focused sponsor/current
Gear/recruitment/shop gate `20260928T224829125993Z` passed12/12. The full gate includes the final
postgame-display, terminal-season and next-visit migration assertions added after that run.

Contract coverage includes all three caps, repeated Ks by one pitcher, distinct pitcher IDs,
repeated extra-base types, sparse/zero results, opponent exclusion, absent statistics, actual
called-ball versus completed-walk attribution and no unowned income. Purchases use real earned
cash and full immutable receipts, exclude active unique sponsors, and replay idempotently.
A completed game pays base income plus exactly the active sponsors' derived amounts. Altered
journal evidence or missing/mismatched result statistics are rejected. Later sponsor sale
retains prior money, removes future earning ability and cannot refund a sold receipt twice.
A whole season including playoffs replays, and final-game income opens no extra shop.

Real viewport UI checks cover all three identities at1000×650 and700×400: effect/price/status
review, initial Cancel focus, bounded scrollable confirmation, cancel, purchase, failed-write
rollback, immutable old save bytes, reload, active ownership, next-match launch and explicit
resale. A D01-to-A08 replacement spends10+4−12=2 remaining Cash, records full12 paid and retains
no old copy. Cancellation and failed replacement preserve both sides of the transaction.
Midgame sales are blocked; leaving an unfinished game pays nothing. The completed-result retry
fixture records base18+earned8 once, retains28 Cash on retry, and displays “Shift Crew: +8 Cash” once
on postgame. This fixture tests state flow; the separate full physical game supplies live evidence.

A genuinely paid schema9 Gloves save migrates with identical cash, Gear and offers and no
load-only rewrite. Rerolls of the current visit retain the old generator. Sponsor eligibility
starts next visit; saves/replay pass on both sides of that boundary. All previous Gear catalogue
definitions remain unchanged, as does the preserved repository PROGRESSION_BLUEPRINT.md.
Fresh main remains `f1dc209b6de11e45aedbd1568fa1b2d841dd2420`, an ancestor of the rebuild branch.

Only three of35 sponsor candidates are enabled. These checks do not approve Working prices,
rarities, acquisition pace or economy balance, and do not grant AI purchases/offscreen effects.
Native rendered visual and human feel acceptance remain open under the documented display
socket limitation. Actual headless input/layout checks are not presented as screenshots.


## Proposed Bands, Shoes and Alley mappings, 2026-09-28

Godot4.7.2 focused gate `20260928T214319750293Z` passed9/9, including the four new mappings
and a complete Shoes/Alley game (87 records,32 balls in play), outro and restart. Full gate
`20260928T214443841019Z` passed40/41: all source/import, ownership, save, UI, roster, progression,
physics, camera, AI, soak and both new/Misc whole-game checks passed. The older four-game
live scene exited0 after two matches without its success marker; the runner correctly failed
it. This is not recorded as a clean full-suite pass. Isolated rerun
`20260928T215029881372Z` passed8/8 with all four complete legacy/progression/equipped games,
outros and restarts, so all41 check types have passing evidence across the full and focused
runs. The initial early exit remains recorded; it was not reproduced in the isolated rerun.

Final UI gate `20260928T214750450379Z` passed12/12 across mapped Gear, prior Misc, prior Gear,
recruitment and paid-development shop inputs, plus seven shared checks. Expanded narrow-window
coverage exposed confirmation height overflow, including older Misc reviews. The fix replaces
the unbounded built-in text with a focusable scrollable review while retaining visible44px
Confirm/Cancel controls. Tests cover1000×650 and700×400 shops, no horizontal clipping, bounded
review height, visible controls, initial Cancel focus, scrolling to the final transaction
text, full effect/status disclosure, cancellation, purchase, save/reload, real next-match
handoff and resale. Existing replacement and write-failure rollback checks remain enabled.

Bands checks cover actual control82/94/95.5/97/98.5/100/112%, both ramp boundaries and exact
workload values, unchanged velocity/movement/command, no first-batter dependency, neutral sale,
and successful real human/AI release debits at low/mid/high effort. Shoe checks show actual
CLEAN↔BOBBLE changes, unchanged reach/height/reaction eligibility, no stale assignment factors,
and actual primary-fielder and pitcher control entry points for both human/AI ownership.
The complete Shoe match additionally exercises ordinary planner/Jolt/AI integration.

Alley checks retain both hands, Contact/Power, fair-only Power cost, unchanged speed magnitude
for Contact, quality, spray, spin and classification. Eligibility rejects weak contact,
grounders and high popups; proposed quality/angular shoulders are continuous. Real authored
Contact has only a very narrow qualifying band; its proposed benefit is negligible and the
purchase review explicitly says so. This remains a design/calibration limitation, not balance
acceptance. No change to core Contact attack angle was made to conceal it.

A genuinely purchased schema8 Gloves receipt migrates to schema9 without changes to paid Gear,
cash, current stock, or save bytes on load. Same-visit rerolls retain the old generation;
new-catalogue eligibility starts next visit. Save/replay succeeds before and after that boundary.
Every candidate has live UI acquisition/reload/sale coverage. Catalogue1/2 fingerprints remain
frozen. Fresh main remains `f1dc209b6de11e45aedbd1568fa1b2d841dd2420` and is an ancestor of the
rebuild branch; preserved gameplay/camera/AI changes were not replaced.

Native pixel/visual and human feel acceptance remain open under the documented display socket
limitation (`builds/verification/native-ui-display-20260928.log`). These are real headless
viewport input/layout checks and live physical simulations, not native screenshots. Proposal
mappings remain unapproved; source values remain Working and ownership rules remain Approved.


## Reconstruction: first-batter, timing and reaction Misc, 2026-09-28

Pinned Godot4.7.2 gate `20260928T211802693954Z` passed39/39 steps, retaining all prior
ownership/save/roster/development/shop/gameplay/camera/AI checks and four complete live games,
then adding focused Misc coverage and a fifth complete Kit/Gloves game. The latter completed
its outro/restart and verified actual participating pitchers consumed their first-batter window.
Final UI gate `20260928T212242225821Z` passed8/8 after renaming the hub/postgame routes to
Season Shop. Earlier focused Misc gate `20260928T211615657511Z` passed8/8; the existing
Gear/recruitment/shop gate `20260928T211234667436Z` passed10/10. Engine errors remain failures
regardless of completion markers. Main remains `f1dc209b6de11e45aedbd1568fa1b2d841dd2420`.

Kit checks cover eight-foul battles, balls, walks, Ks, hits and outs, duplicate release notices,
canceled windups, each reliever's own window, inning persistence, fresh-game reset, multiple
release participants and tracking before item ownership. Equip does not recover stamina and
Kit does not grant illegal pitcher re-entry. The real launch path debits the correct first/later
workload multiplier for human and AI control; PA completion advances the same state.

Gloves checks cover Contact/Power, both batting hands, neutral/contact/power Bats, exact1.08
window widths, swept contact inside the added early/late bands and misses beyond them. Barrel
positions, swing start/duration, spatial radii/depth, actual quality and timing error remain
unchanged. Weak edge contact stays weak; fair exit speed receives the0.96 penalty once while
fouls retain their normal velocity. Tracker expiry honors the new endpoint. Actual human/AI
swing trackers receive both modifiers, and the fifth live game exercises equipped AI contact.

Goggles checks compare baseline/equipped reaction, unchanged movement/reach/Fielding, no planning
before the reduced gate, planning within the newly gained interval, neutral behavior and a
positive floor. Real human/AI lab assignments receive the same fielder and pitcher-pursuit delays.
The existing immediate comebacker-control rule is preserved rather than inventing a catch delay.

Each new Misc item is acquired through actual700×400 viewport clicks: exact effect/price review,
Cancel, confirmed purchase, immutable receipt, save/reload, paid next-match handoff and resale.
Existing Gear coverage continues to verify replacement, write-failure rollback and old save bytes.
A genuinely purchased schema7 Rosin receipt migrates with unchanged cash/stock; the three new
Misc become eligible only next visit. Schema8 replay is stable both before and after that visit.

All39 full checks ran against the completed physics/domain/UI implementation. The subsequent
changes were shop-route wording and its existing input fixture; the final focused UI gate covers
that exact wording. Native screenshots/visual feel and human balance approval remain open under
the display limitation recorded below. Desktop capture remains available:

```sh
python3 tools/verify.py --only season-misc --rendered-ui
```

Bands need a0–100% contract-to-82–112% engine effort mapping; Shoes need handling-error semantics
for the deterministic resolver. These and Alley/tier/sponsor/AI-purchasing dependencies remain
explicitly unfinished. No new effect is claimed approved merely because its automated checks pass.


## Reconstruction: paid Gear and shared physical effects, 2026-09-28

Full pinned Godot4.7.2 gate `20260928T205008883850Z` passed37/37 steps, including the new
Gear scene, all existing shop/recruitment/ownership/save/development/gameplay/camera/AI gates,
four complete live games, soak, physical-ball checks and main-scene smoke. Focused gate
`20260928T204819273765Z` passed9/9 shared/Gear/paid-development steps before the final
force/trajectory and complete equipped-game additions. Fresh main remained
`f1dc209b6de11e45aedbd1568fa1b2d841dd2420`; no preserved gameplay commits were replaced.

Gear coverage includes bounded mixed offers, at least two categories, owned-identity exclusion,
no locked-tier grants, exact prices/receipts, explicit replacement using sale proceeds, duplicate
confirmation, rejection of stale/replaced receipts, insufficient funds and client price overrides,
full journal reload and neutral restoration on sale. The previous development-only seeded
fixtures explicitly retain build2; new mixed-pool domain and UI fixtures exercise build3.

Resolver checks cover both swing profiles/hands at multiple actual contact qualities, unchanged
timing geometry, fair-only exit scaling and untouched authored resources. All nine mastered
recipes, both hands and three enabled Balls pass through rated parameters, real aim solving,
plate flight and force comparisons. Gravity/drag, natural wobble and mastery timing are preserved.
Seeded release dispersion verifies the Rosin/hybrid product separately from speed/orientation
noise. The real lab launches with both human and AI control, debits Rosin workload once and
hands Bat modifiers to the actual swing tracker. Opponents cannot inherit the player's equipment.

Actual viewport clicks cover normal and700×400 layouts, 44px actions, fixed navigation, focus on
Cancel, exact replacement/sale descriptions and Cash, cancellation, injected write failure,
unchanged prior save bytes, purchase, replacement, sale, reload and next-match handoff. Schema5/6
migration preserves old stock without rewriting on load, activates Gear next visit and survives
schema7 replay. Existing recruiting tests continue to protect held cards and unresolved packs.

The live gate retains the two legacy and one maximum-development games, then adds a fourth
maximum-development game with both teams equipped. All four finish and retain normal outro/
restart behavior. The equipped fixture is a controlled stress case, not paid AI shopping or a
balance sample. Initial checks caught an omitted trusted resale policy and an opponent scope
mistake; both were corrected before this full passing gate. Completion markers never override
engine errors.

Rendered inspection is still open under the native-display failure documented below. The Gear
scene supports the same desktop screenshot route; no screenshots or visual approval are claimed:

```sh
python3 tools/verify.py --only season-gear --rendered-ui
```

Remaining acceptance includes human play/feel, balance, remaining Misc mappings, Alley IDs and
trajectory contracts, earned tiers, permanent unlocks, sponsor combinations and paid AI purchases.


## Reconstruction: recruiting, returns and historical rosters, 2026-09-28

Full pinned-engine gate `20260928T202321643180Z` passed36/36 steps, including recruitment,
paid-shop UI, all existing ownership/development/save/season checks, preserved gameplay,
camera and AI regressions, three complete live-match fixtures and main-scene smoke. Final
recruitment gate `20260928T202515533329Z` passed8/8 after adding explicit unbought-appearance
history and team-held-card preservation checks. Earlier focused gates
`20260928T201848137648Z` and `20260928T202144151410Z` each passed11/11.

The new catalogue gate covers48 unique identities and144 authored fresh profiles, exact
Gray/Morgan examples, Alex's split mastery exception, stage additions/prices, unchanged
repertoire/capacity and fresh pitch cap3. Domain fixtures check current/opponent exclusions,
fixed offers across rerolls/reload, no offer after Game6, missing targets, insufficient Cash,
price override rejection, immutable full fees, zero release income and duplicate confirmation.
Seeded round trips use genuinely purchased stock: returning originals retain earned development,
returning signed recruits keep their first fee and get no second catch-up, and earned Eephus4
survives return and JSON replay rather than being downgraded to the fresh cap3.

Actual viewport clicks cover700×400 recruit inspection/comparison, the exact outgoing player,
cancel, confirm, rejected disk writes, rollback of both build and reordered lineup, preserved
defensive slot assignments, a paid team-held receipt and actual next-match definitions. Old and
new roster performance histories restore together; replacing an old participant with a future
recruit is rejected. Former-player totals stay visible and within menu bounds. The migration
fixture includes an actually paid held card and an unresolved paid pack, preserving both and
starting recruiting only on the next visit. No load-only rewrite is performed.

Initial JSON reload checks caught deep-comparison differences between authored integers and
Godot's parsed floats. Quote validation now normalizes both representations, while still
rejecting changed fields/values. The engine-error gate and completion markers remain strict.

No rendered visual or balance approval is claimed. The native-display limitation recorded in
the preceding checkpoint remains open. The new scene also supports the desktop capture route:

```sh
python3 tools/verify.py --only recruitment --rendered-ui
```

The scene's performance records are controlled state/save fixtures, not human play or measured
economy. Its live launch verifies roster/profile handoff; the full suite separately completes
three live games. This does not validate paid AI recruiting, permanent eligibility, extra reserves,
Doubleheader workload, learned abilities or whole-season economic balance.

## Reconstruction: paid development and real UI input, 2026-09-28

Full pinned-engine gate `20260928T195505241012Z` passed35/35 steps, including the new
paid-domain/UI scenes, all ownership/save/season regressions, preserved gameplay/AI/camera
checks, three complete live-match fixtures and main-scene smoke. Focused gate
`20260928T195354889110Z` also passed9/9 shared and scene steps for `paid-development` and
`paid-shop-ui`. These checks use actual code and disposable saves, including uncommitted source.

Paid-domain coverage includes cancelled previews, exact authoritative prices, two held slots,
immediate use while full, exact receipt consumption, duplicate requests across reload, stale
quotes, insufficient funds, foreign/capped targets, explicit paid lesson replacement with
remembered mastery, fixed pack identity, zero/reduced eligible families, pending paid choices,
escalating/reset rerolls and no refund on skip. Whole-season win/loss fixtures retain terminal
income, allow intermediate playoff shops and reject shopping after completion.

Schema5 checks restore wallet, growth, offers and held receipts from one replayable aggregate.
Injected write failure preserves both the prior save bytes and live build. Forged payouts and
version downgrades fail closed. The first import/runtime attempt exposed an incorrectly typed
empty draft roster; that defect was fixed. Completion markers never override engine errors.

The UI scene dispatches actual mouse motion/press/release through Godot's viewport, including
the correct embedder for nested modal windows. It checks Working-season warning cancellation,
draft/hub/lineup/ratings bounds,1000×650 and700×400 shop layouts,44-pixel actions, always-visible
Back, focus, exact recipient confirmation, targeting/cancel/confirm, sold stock removal, pack
reload, a blocked next-game launch while unresolved and a real paid-build match launch after
resolution. Deferred focus now resolves current controls rather than detached old rows.

**Rendered inspection is still open.** A fresh native-display attempt with the recovered
portable Xvfb exited1: `Cannot establish any listening sockets`, after both local and Unix
listeners failed. No rendered screenshots, aesthetic approval or human game-feel approval are
claimed. Local diagnostic: `builds/verification/native-ui-display-20260928.log`.

On a desktop with a usable display, the same scene can capture each screen for visual review:

```sh
python3 tools/verify.py --only paid-shop-ui --rendered-ui
```

Captures go to the verification run's `ui-captures/` directory. This optional UI run uses the
compatibility renderer and rejects headless capture; it does not validate Mobile-renderer
materials, physical-device input, motion comfort or whole-game balance. Inspect readability,
clipping, dialog placement and the actual rendered match separately before visual sign-off.

## Reconstruction: playable four-stat/mastery calibration, 2026-09-28

Gate `20260928T191242881476Z` passed 14/14 steps: development-playtest,
season-development, pitch-handedness, pitch-routing, season-shell, pitch-quality,
core regressions and the seven shared checks. Gate `20260928T191455946223Z` passed
11/11: ownership-integration, venue-stats, season-flow, live-match and shared checks.

The new scene proves a measured physical improvement at every broad-stat level1–10,
all 90 ordinary recipe/level/hand combinations reach the aimed plate, each movement
or speed step changes actual flight, and reliable recipes reduce sampled execution
spread without removing their natural identity. It also checks neutral legacy resources,
noncompounding mastery, no hidden Velocity/Break scaling, command/speed separation,
confirmation/cancellation, isolated save/reload, and the real menu-to-exhibition path.
Human and AI launches pass the restored mastery into the live pitch actor.

The live-match gate now completes two preserved legacy fixtures and one deliberately
max-level progression fixture, with real AI contact/Jolt balls in play, balanced statistics,
outro and restart checks. The passive scripted player and synthetic maximum-level grants
are state-flow stress cases, not player-skill, acquisition or balance evidence. No rendered
UI, human feel/readability approval or production shop readiness is claimed.

## Reconstruction: player-development foundation, 2026-09-28

Gate `20260928T190147002897Z` passed all 8 focused steps, including the new
season-development scene. Checks cover 48 exact identities, 6/39/2/1 starting-repertoire
distribution, three Eephus holders and Alex's sole initial level-2 exception, individual
caps without combined growth budgets, lowest-active-pitch targeting, explicit replacement,
remembered mastery, isolated season instances, idempotent journal replay, invalid-save
preservation and real-file backup recovery. Live resources and physical behavior are
unchanged by this foundation; no physics or purchase integration is claimed here.

## Reconstruction: ownership integration, 2026-09-28

Gate `20260928T184921051343Z` passed 14/14 steps, including ownership-integration,
season-ownership, season-qc, season-flow, season-enrichment, season-shell and
main-scene. After the final confirmation text change, gate
`20260928T185116663089Z` passed all 10 focused steps (ownership-integration,
season-ownership, season-shell and the seven shared source/import checks).

Coverage exercises actual result payouts and duplicate protection, schema-4 reload,
legacy migration without rewriting source files, invalid-save preservation,
failed-write retry without replaying results, isolated journal backup recovery, and
the test window's preview/cancel/confirm/save/reload controls. The earlier corruption
fixture exposed an engine error from `JSON.parse_string`; recovery now uses the
error-returning parser and the normal engine-error gate remains enabled.

The ownership window uses synthetic catalog entries and a separate test save.
Production Gear/sponsor stock and effects are still absent. These headless checks
do not establish rendered UI quality, gameplay balance or human approval.

## Reconstruction: ownership core, 2026-09-28

Gate `20260928T184305090685Z` passed 8/8 steps: revision, working-tree, diff-check,
gdparse, gdlint, pinned engine version, import and season-ownership. Covered receipt-based
replacement funded by an explicit sale, cancellation, insufficient funds, wrong-slot/stale
requests, duplicate operations, free Gear, zero/blocked sponsor sale rules, held/sponsor
capacity, explicit discard on capacity reduction, JSON replay and malformed journal rejection.
Changed catalog contracts fail closed instead of silently repricing history. Fixtures have no
actual gameplay effects; human review and production shop integration remain outstanding.
An earlier gate stopped on validator return-count style lint; the validator now explicitly
allows early-return guards. No engine-error or completion-marker checks were relaxed.


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

## Clubhouse menu verification — 2026-09-22

Full 27-step pinned Godot 4.7.2 verification passed at
`builds/verification/20260922T051646771102Z`, with no engine errors or warnings.
The final tooltip/result-text styling received passing targeted import, lint,
season-menu, pause-inspection and presentation checks. Logs:
`builds/menu-final-{import,season,pause,presentation}.log`.

- Existing season tests cover all pages, horizontal bounds, visible fixed
  navigation, draft comparisons, reordered lineup/scroll preservation and saves.
- Pause inspection now opens with actual viewport-dispatched Enter, verifying
  focusable actions and frozen game state. Resume receives focus when pausing.
  All three HUD anchors still pass bullpen bounds/full-text and hand checks.
- Full-name Pitch selection, locked live controls, switch-hitter clicks, game
  handoff, camera/HR presentation and live AI/contact/Jolt matches remain covered.
- Palette calculations give approximately 13.1:1 cream on panel, 6.4:1 muted text
  on raised panel, and 10.8:1 dark text on amber action backgrounds. These are
  color-pair checks, not an accessibility or rendered-UI certification.
- An initial layout pass failed the existing 44-pixel content-margin checks;
  margins were restored and both full and final targeted checks passed.
- Native rendered inspection remains blocked. A portable Xvfb preview attempt
  could not create display sockets (`Operation not permitted`); no screenshot or
  aesthetic approval is claimed. No system package/engine version change was
  needed or made. Tools/preview files stay in ignored builds; root was not imported.

Human menu QC remains the immediate gate before enrichment implementation.

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
