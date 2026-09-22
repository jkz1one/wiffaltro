# Field scale, character proportions and stadium progression

2026-09-22. Audited local and GitHub `main` at
`aa02b7e0b441c73cb822ed0f1037d7400655c8ff` with a clean checkout.
Authoritative gameplay remains Source v0.4.27 / Technical v0.1.22.

**Status: researched recommendation, not approval to change gameplay.**
The user reports that pitching now feels excellent and asks whether proportions,
field/hitting scale and later stadium progression should change. This pass adds
documentation and an isolated research tool. It changes no game resources,
models, cameras, physics, difficulty, saves or season fixtures.

## Recommended decisions

1. **Keep the current field and hitting scale. Reject a blanket 1.3× change.**
   There is no human evidence that the current sport needs a larger playing area.
   The isolated comparison shows that scaling hitting and distance together does
   not preserve outcomes. Keep the current baseline as the reference park.
2. **Preserve the pitching setup across ordinary stadium variants.** Keep mound
   distance, plate/zone, release geometry, pitch simulation and live pitch cameras
   fixed. Stadium prestige must not silently alter ball aerodynamics or timing.
   Explicit future learned pitches/approved effects are a separate content decision.
3. **Develop simplified adult-athlete silhouettes at approximately current height.**
   Separate the legs/hips/torso and reduce relative head size in a later graybox
   comparison. Do not uniformly enlarge the present avatar. This commits to a
   proportion goal, not production meshes, textures, faces or a final render style.
4. **Use stadium grandeur as a strong progression signal.** Stands, lights,
   architecture, crowd presentation, entrances and broadcast framing can grow
   substantially without moving scoring lines. Keep the ball's background quiet.
5. **Use field dimensions as authored strategic variety, not the universal difficulty
   meter.** Some advanced venues can be deeper or larger after builds justify them.
   A late compact park can also be dangerous. Do not make every game longer or
   automatically move fences to counter the player's upgrades.
6. **Preserve the existing home-stadium contract.** Structural changes happen
   between seasons; Opening Day locks the layout. Away parks and the neutral
   championship provide variation. Ordinary home fixtures do not gradually stretch.
7. **Keep Leagues, Difficulty and venue prestige distinct.** League remains the
   ruleset/Deck analogue; Difficulty is pressure within that League. Neither is
   defined solely by field size. Phase 5 effects come before mechanical park tuning.

These are recommendations to adopt as design direction. Specific new dimensions,
avatar measurements and difficulty schedules remain proposals requiring a bounded
prototype and human QC. The present sport is a valid endpoint if it already feels right.

## What the repository actually contains

### Current geometry and coupled systems

| Element | Current | A literal 1.3× version | Assessment |
| --- | ---: | ---: | --- |
| Mound distance | 13.716 m | 17.8308 m | Changes pitch travel and apparent delivery; preserve current |
| Single plane | 11.25 m | 14.625 m | Passes behind the fixed mound if only boundaries move |
| Deep Air plane | 17 m | 22.1 m | Changes untouched airborne Double eligibility |
| Back wall | 23.4 m | 30.42 m | Changes HR, Triple and grounded Double opportunities |
| HR clearance height | 3.25 m | 4.225 m | Additional independent power requirement; do not scale by default |
| Fixed pitcher exception radius | 0.60 m | 0.78 m | Changes defensive exception; preserve current |
| Avatar top above origin, upright | about 1.75 m | 2.275 m | Does not fix relative head/body proportions |

Sources: `starter_field.tres`, `PitchBatLab`, `PitcherDefense`, `PlayerAvatar`.
Rows describe different consequences of a blanket transform, not a proposed preset.

The Single line currently precedes the mound by 2.466 m. At 1.3× scoring depths
with the mound fixed, it would instead be 0.909 m beyond the mound. The current
pitcher exception deliberately operates after ordinary Single eligibility.
Changing that relationship is a sport-rule change, not a visual adjustment.
An isolated resolver example confirms the consequence: the same moving grounder
cleanly controlled by the Primary Fielder at x=5, z=13 is a **Single** now and an
**Out** with the Single line at 14.625 m. No catch probability is involved.

Deep Air already preserves a Double floor on untouched airborne balls. Moving
only the wall leaves that rule intact; making the ball travel longer does not
automatically create more finely spaced scoring tiers. There is no Triple line.
Do not add one to compensate for extra field depth.

Defense covers actual distance at rating-based speeds (Primary Fielder
3.8–5.2 m/s), with finite reaction delay/reach and a three-second planning horizon.
Larger areas can create gaps while deeper fences prevent some HRs. Those effects
can oppose each other. Both clubs bat and defend on the same field, so a larger
park is not inherently a harder opponent or a higher required score.

The code is only partly parameterized. Scoring planes and defender anchors are
data, but the starter renderer still uses a 45×36 m ground slab ending at z=30,
a 38 m wide physical wall and fixed-width scoring stripes. At a 30.42 m wall,
the wall would exceed the current ground slab, and the fair corridor would be
about 55.68 m wide. Even the present analytic corridor at the wall is about
43.04 m wide, exceeding the physical wall's 38 m width. The mathematical wall
crossing resolves these edge plays, but the visual/collision/rule extents are not
a general stadium generator. Record this near-foul-edge limitation; it does not
justify changing current scoring during this research pass.

Field Setup has a fixed orthographic size of 29 m. Establishing shots, scenery,
HR carry, dead-ball bounds and defender layouts also need explicit support for
larger parks. Merely adding a scale property would not complete that work.

### Character proportions

Runtime mesh bounds confirm an upright top near 1.75 m, a 0.40 m head and a
0.56 m wide, 1.18 m high torso capsule. There are separate hand spheres but no
separate legs/feet. The silhouette is roughly 4.4 head heights tall. Enlarging
the whole avatar preserves that ratio and creates a 2.275 m version at 1.3×.

**Inference, not rendered approval:** the large head, undivided capsule and lack
of leg articulation are stronger explanations for the toy-like impression than
insufficient world height. My earlier suggestion to make everyone taller was
premature. Use current overall height for the first proportion experiment.

A provisional graybox target is approximately six to seven head heights, with
clear legs, hips and shoulders, while keeping hands/bat aligned to the existing
swing and release. A roughly 0.27 m head at 1.75 m is one comparison candidate,
not an anatomical standard or frozen number. Preserve functional hand targets,
hit testing and the zone; use the existing camera audit for both batting sides.
Reject a change that requires moving the pitch camera to hide new obstruction.

## Isolated runtime comparison

Reproduce after `python3 tools/setup_verify.py`:

```sh
python3 tools/audit_field_scale.py
```

Evidence: `builds/field-scale-audit/20260922T042840Z/`.
The unchanged gameplay also passed the full 26-step `python3 tools/verify.py`
suite at `builds/verification/20260922T042906959168Z`.
Godot 4.7.2 / Jolt, 60 Hz, production `ContactResolver`, `BattedBallBody`, fresh
ball aerodynamic configuration and `BallPlayResolver`. The tool imports only a
disposable copy of `project.godot`, `src/` and `assets/`, plus its diagnostic scene.
It never imports the root checkout or copies protected directories.

There are 216 authored contact conditions: Contact/Power swing; Power rating
3/6/9; incoming speed 14/20/26 m/s; normalized vertical error -0.4/0/0.3/0.6;
normalized timing error -0.3/0/0.3; Contact rating fixed at 6. Each launches at
normal exit speed and at exit speed ×1.3, for **432 physical trajectories**.
The same trajectories are observed against four hypothetical scoring layouts.
The 1.3 speed factor acts on exit velocity, not the Power rating or swing timing.

| Uncaught Power-swing fixture | HR clearances out of the same 108 contacts |
| --- | ---: |
| Current wall, current hitting | 46 |
| Wall 10% deeper, current hitting | 36 |
| Wall 30% deeper, current hitting | 16 |
| Current wall, exit speed +30% | 70 |
| Wall 30% deeper, exit speed +30% | 58 |

Moving both wall and exit speed by 30% does not recover the original result.
Contact-swing HR clearances go from 0/108 currently to 13/108 with extra speed
at the current wall, or 1/108 with both wall and speed enlarged.

Without physical walls, median first-ground depth changes from 16.44 to 22.72 m
for Contact and 28.65 to 37.30 m for Power. Median time to first ground changes
from 1.09 to 1.28 s and 1.70 to 1.96 s respectively. Altering exit speed changes
defensive opportunity and tempo as well as distance; the responses differ by swing.

**Limits:** this is a sensitivity experiment, not a realistic contact distribution,
human hit rate, completed-match simulation or recommended balance target. Bodies
use Jolt ground contact; hypothetical walls use the production scoring-plane
logic without wall bounce meshes. Defenders, obstacles, aim adaptation, AI,
fatigue, future abilities and human execution are absent. Thus there are no
defensive Outs in the 432-ball comparison, and many grounders eventually reach
the virtual wall. Do not treat its Single/Double mix as match balance. The separate
ground-control example tests a specific rule difference, not defensive frequency.
Avatar measurements are mesh bounds, not an aesthetic playtest.

## Primary research and what it does, and does not, establish

- **Balatro:** the developer/publisher description identifies chip requirements,
  blinds, a final ante, distinct Deck modifiers and separate difficulties.
  [Official Steam page](https://store.steampowered.com/app/2379780/Balatro/).
  **Application:** borrow visible escalating demands and meaningful build choices.
  Wiffaltro's opponent contests both offense and defense; fence distance is not
  equivalent to Balatro's chip requirement. A conventional baseball win must not
  secretly require a second score quota. Exact future curve remains untested.
- **Park effects:** Statcast compares players' event frequencies across parks and
  controls for handedness; park effects are measured per outcome.
  [MLB Statcast park factors](https://baseballsavant.mlb.com/leaderboard/statcast-park-factors).
  **Application:** assess HRs, non-HR hits and defense separately for Wiffaltro.
  Real baseball park-factor values cannot calibrate a one-fielder plastic-ball game.
- **Geometry precedent:** Baseball standardizes pitching distance while permitting
  different outfields. [MLB field dimensions](https://www.mlb.com/glossary/rules/field-dimensions).
  **Application:** preserve our central interaction while considering outer-field variety.
- **Defense:** Catch probability depends on required distance, available time,
  direction and wall proximity. [MLB catch probability](https://www.mlb.com/glossary/statcast/catch-probability).
  **Application:** a range-only comparison cannot certify the defense on an enlarged field.
- **Readable stylization:** Valve describes validating distinctive silhouettes
  without interior detail and limiting environmental visual noise to support
  gameplay. [Illustrative Rendering in Team Fortress 2](https://cdn.fastly.steamstatic.com/apps/valve/2007/NPAR07_IllustrativeRenderingInTeamFortress2.pdf).
  **Application:** settle readable athletic proportions with plain meshes first.
  Do not copy TF2 anatomy, shading or art direction as Wiffaltro's final style.
- **Validation:** Valve distinguishes direct observation from quantitative methods
  and treats design as hypotheses evaluated through playtesting.
  [Valve's Approach to Playtesting](https://cdn.fastly.steamstatic.com/apps/valve/2009/GDC2009_ValvesApproachToPlaytesting.pdf).
  **Application:** these fixtures identify risk; only the user's play can establish
  whether a larger park or a different silhouette improves this game.

## Proposed progression model

| Layer | What changes | What stays independent |
| --- | --- | --- |
| League | Persistent season rules and permitted park families | Difficulty is separately selected/tracked |
| Difficulty | Opponent capability, tactics and approved resource pressures | No automatic world/physics scaling |
| Season stage | Opponent development, standings stakes and playoff presentation | Home layout remains fixed |
| Venue layout | Declared geometry, anchors and authored ground rules | No hidden response to the player's purchases |
| Venue prestige | Stands, lights, crowd, architecture and presentation | Does not demand longer hits |
| Club career | Owned venue pieces, branding and legal layout options | Temporary roster/build power still resets |

This preserves the frozen Deck/League analogy and home-remodeling rule. Treating
all later Leagues as simply larger fields would erase their intended ruleset
identity. Advanced League/Difficulty combinations may draw from a broader or
more demanding **curated** park pool, but must support multiple viable builds.

During a ten-game season, opponent strength and standings can escalate while
the player repeatedly returns to the same recognizable home. Away venues can
have different identities. Playoff crowds, entrances and the neutral final can
feel substantially grander. A strict field-size increase after every match is
incompatible with that home/away structure and is not recommended.

Larger future parks should test a build's decisions. A deep park may reward gap
contact and good defense while challenging marginal HRs. A small late park may
reward power but make pitching mistakes more costly. Those are hypotheses to
test, not guarantees of balance. Show the fixture/layout ahead of the relevant
shop so the player can prepare; never choose a park after inspecting purchases
in order to cancel their benefit. Upgrade gains must remain perceptible.

Do not make Power purchases mandatory to clear an expanding distance threshold.
Contact, plate discipline, pitching and fielding builds must remain legitimate
ways to win. More spectacular upgrades can create conditional opportunities,
synergies and better execution payoffs; they need not multiply exit speed
indefinitely. Conventional runs/outs remain legible. A combo that clears the old
wall decisively should be allowed to feel powerful at that park.

### Parameters without a speculative stadium engine

For the first mechanically distinct park, author one explicit `FieldDefinition`.
Keep the existing Single and Deep Air rules, pitching core and HR height fixed;
consider **wall +10%** as a controlled prototype only after the shell and first
Phase 5 slice pass human QC. It is not selected for launch. Retain +30% as a stress
case, not a new default or guaranteed late-season destination. Future content may
justify different values; no progression ratio is frozen by this report.

First make the necessary ground, wall, lines, dead-ball margins, legal anchors
and non-pitch cameras derive from that authored layout and validate them together.
Decorations must distinguish cosmetic meshes from live, dead-rule and modifier
objects. Preserve clear pitch corridors and fair-boundary readability. Add wall
contours, material effects or unusual objects only when an approved park needs
them, not as a universal generator in advance.

Later, seed a selection of approved layouts and compatible decoration/object
slots. Persist the resolved layout ID/version and any chosen parameters when
the season is created, rather than rerolling on Continue. Avoid independently
randomizing every dimension: combinations require their own rule/defense checks.
The current two fixed venue definitions do not require a save migration; future
generated configurations would need an explicit persistence design.

### Compatibility with a persistent buildable home stadium

Keep permanent ownership/appearance separate from the selected legal field layout.
Club Funds can unlock identity and lateral layout options without endlessly
enlarging the active playing surface. A developed club can keep impressive stands
around a compact park. Make each League/Difficulty's layout restrictions visible
before the season; always offer a valid default so career purchases cannot trap
the player out of a ruleset. Preserve incompatible owned designs for other runs.

Select/remodel before Opening Day, then freeze the structural configuration.
Geometry affects both clubs, but symmetry alone is not proof of balance: the
player can build a roster around it. Evaluate both handednesses and several build
directions at equal opportunity cost. Decorative ownership must not secretly
expand reach, improve pitch control or award free seasonal power.

## Sequence and acceptance criteria

**Now:** keep v0.4.27 gameplay, complete human season-loop QC and use these decisions
to guide content authoring. No new progression or graphical implementation here.

**Next presentation experiment, when requested:** compare the current model and
one plain adult-proportion graybox at the same overall height and camera. No
textures or production rig commitment. Accept only if the user prefers it, both
hands show the correct stance, ball release/approach remains readable, and bat/
hands stay aligned through the existing swing/delivery. Pitch trajectories,
contact results, collision/reach and saved data must be unchanged for identical inputs.

**After approved catalog + first complete shop slice:** compare the reference
park with one deeper authored park using actual approved effects. Check pitching
with identical seeds/inputs, live scoring at every boundary, high-speed physical
wall contact, legal defense and coverage, camera/HR framing, real-match duration,
both handednesses, saves/reloads and older-season compatibility. Use paired
fixtures to explain mechanical differences and meaningful human F3 records to
evaluate actual play. Record baseline and upgraded builds separately; do not
substitute uniformly sampled contacts for a real player distribution.

Reject or revise the deeper park if it demands Power shopping, erases Contact
scoring, produces long empty chases, makes fielding placement irrelevant, hides
the ball, weakens a satisfying upgrade merely to restore an old HR rate, or
confuses a wall/floor result. Exact acceptable rate/time bands require the current
human baseline and approved effects; inventing them now would be false precision.

**Phase 6:** introduce a small approved venue pool alongside opponent identities
and difficulty development. **Phase 7:** connect persistent home construction.
**Phase 8:** finalize production art. Keep the first implementation proportional
to actual authored content, not every possibility described in the roadmap.
