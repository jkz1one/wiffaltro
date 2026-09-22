# Plastic-Ball Baseball Roguelite — Source of Truth

**Version:** v0.4.33
**Status:** FROZEN BASELINE WITH HUMAN PLAYTEST AMENDMENTS
**Supersedes:** v0.4.32 and all earlier planning notes
**Change rule:** Do not reopen frozen decisions unless implementation, playtesting, research, or a clear design contradiction gives us a concrete reason.

---

## 1. Executive Summary

### One-line concept

A fast arcade plastic-ball baseball roguelite where **one run equals one season**, every pitch and swing is player-controlled, and temporary team builds combine with a persistent evolving club and home stadium.

### Short pitch

You build a tiny four-player plastic-ball team through new Pitches, Hitting Abilities, Fielding Abilities, Gear, Endorsements, and limited seasonal development while competing through a real 10-game league and playoffs. Pitching and hitting are skill-driven, while defense is streamlined through one strategically positioned automated fielder, automatic pitcher defense, and ghost runners. Opponents develop alongside you, fields become increasingly strange, and every season produces a different build. When the season ends, temporary team power resets, but your club identity, records, unlocks, and home stadium persist.

### Reference shorthand

**Backyard Baseball × Balatro**, with deep plastic-ball pitching, physical ballparks, small two-way rosters, real standings, and a persistent stadium career layer.

This is shorthand only. The game does **not** map Balatro systems one-to-one.

---

## 2. Design Pillars

### Pitching is a headline mechanic

Pitch repertoires, delivery slots, sequencing, stamina, execution, and plastic-ball movement must be deep enough to support builds by themselves.

### Physical fields are rules

Park geometry is not scenery. It affects hit outcomes, defense, positioning, rebounds, and strategy.

### Small roster, strong identity

Four active two-way players means every roster decision matters.

### Build resets, club persists

Seasonal power is disposable. Club identity, history, unlocks, and stadium progression provide the long-term attachment.

### Readable absurdity

Early seasons teach understandable baseball. Later Leagues, Pitches, Endorsements, and fields can become increasingly strange without losing mechanical clarity.

---

## 3. Core Progression Loop

### Preseason

Choose **League + Difficulty** → receive/select a four-player roster → configure persistent home stadium → set batting order and loadouts.

### Regular season

Play game → earn Season Cash and Hype → postgame shop → improve players/build → opponents evolve → standings update → limited Free Agent decisions → trade deadline → final roster/build push.

### Postseason

Top four qualify → higher-seed semifinal → neutral-site championship.

### Season end

Temporary build resets → career history is recorded → Club Funds are awarded → post-season player-card rewards and other unlocks resolve → jerseys/emblems/stadium can be improved → begin another season.

---

# 4. Baseball Rules

## Roster

**4 active two-way players.**

Every player can hit, pitch, and field, but has distinct strengths.

No bench in the baseline game.

## Player stats

- Contact
- Power
- Fielding
- Velocity
- Break
- Control
- Stamina

No Speed, Arm, or Discipline stat in v1 unless prototype evidence creates a clear need.

Handedness, natural delivery, repertoire, repertoire capacity, and similar identity elements are properties rather than stats.

The initial 48-character pool has 10 left-handed throwers; 46 players have the
same default batting and throwing hand. Two are switch hitters (one in 24).
Throwing hand is fixed. Switch hitters may choose their batting side before
confirming a new plate appearance, never after the delivery plan starts.
AI switch hitters choose the opposite side from the opposing Pitcher's hand.
From the catcher-facing camera, right-handed Batters stand screen-left of the
plate (world +X), left-handed Batters screen-right (world -X). Avatar, independent
bat, camera offset, contact handedness and inside/outside feedback must agree.

## Game length

- 5 innings
- 3 outs per half inning
- 4 balls
- 3 strikes
- Two-strike fouls remain at two strikes
- A caught foul is an Out; an uncaught foul remains a Strike under the count rule
- A clean play on a still-moving fair ground ball before it crosses the authored
  Single line is a ground Out. Once the ball stops or crosses that line, the
  Primary Fielder may prevent further advancement but cannot erase the Single.
  A clean moving-ground-ball control inside the Pitcher's fixed 0.60 m mound
  envelope remains a narrow Out exception; a stopped ball is safe. A bobble
  on the plate side of the Single line is an immediate dead-ball foul.
- 10-run mercy rule after 3 completed innings
- Extra innings begin with a ghost runner on second

Five innings and the mercy threshold remain subject to real match-length testing, but they are the prototype baseline.

## Batting order

Fixed before the game and cycles normally.
The player may edit freely between games, including immediately before Play
Game. There is no once-per-game batting-order reshuffle: it risks duplicating or
skipping turns in a four-player roster. Pitcher and Primary Fielder changes
remain separate, available between Batters. Future League exceptions must state
their rule explicitly instead of silently changing this baseline.

---

# 5. Ghost Runner / Base System

No physical baserunners in v1.

Bases exist as a simulated state.

Baseline advancement:

- Single: batter to first; existing runners advance one base
- Double: batter to second; existing runners advance two bases
- Triple: batter to third; existing runners score
- Home Run: all runners score
- Walk: forced advancement only
- Ordinary out: runners hold unless a tag/sacrifice rule applies

No:

- manual baserunning
- stealing
- leads
- pickoffs
- rundowns/pickles

## Sacrifice flies

Ghost runners can tag without visible runners.

Advancement is determined by the physical defensive situation, primarily:

- catch location/depth
- defensive return time
- fielder ability
- standardized ghost-runner advancement time

A shallow catch may allow no advancement. A deep catch may allow a runner from third to score. Extremely deep/awkward catches may allow other runners to advance.

No dedicated runner Speed stat is required initially.

---

# 6. Hitting

## Controls

Hybrid arcade aiming + timing.

The player:

1. aims a forgiving contact region
2. chooses **Contact Swing** or **Power Swing**
3. commits to the swing

Mouse batting may combine aim and commitment: moving the pointer positions the
contact region, left click commits to Contact, and right click commits to
Power. Keyboard/controller reticle aim remains an equivalent supported input,
not merely a diagnostic path.

Each player-controlled offensive plate appearance begins in a deliberate
ready state. The player confirms once after the current Batter steps in, which
preserves a future pre-at-bat window for consumables and tactical choices.
Pitches within that same plate appearance continue automatically after a
readable dead-ball hold; there is no extra acceptance click between Pitches.
Opponent Pitcher set and windup cadence varies within a bounded readable range,
including a separate quiet pause before the windup starts. This adds variation
without rushing the delivery animation. When the player is pitching,
the automatic hold returns to a ready state and the player sets the tempo by
choosing when to begin the next click-and-hold delivery. Pitch, aim, effort,
Pitcher, and legal defensive choices remain available during the appropriate
ready state.

The Batter may request one tactical timeout per plate appearance during the
opponent's quiet set, before windup begins. This returns to the ready prompt
without changing count, Stamina, or the already selected Pitch. It cannot cancel
a windup or live Pitch. Normal pause is unlimited and separate from this rule.

The batting camera stays nearly centered on the Pitch lane with only a very
small handed offset. This preserves depth without letting the loaded bat
obstruct the incoming ball or changing plate-local contact math. A visible handed Batter and bat must mirror the
current roster player; the bat is presentation for the authored ContactResolver,
not a second physics authority. The bat and Batter are independent presentation
actors so equipment animation/lifecycle does not become character geometry.
Each bat must visibly load at the Batter's back shoulder, drive across the
plate toward the front shoulder, and mirror that complete path for opposite
handedness. The ready pose is already the load: committed motion begins with
the forward drive through a readable slot, the barrel reaches its
square-across-plate presentation at the profile's authored sweet-spot time,
extends through the ball, then decelerates toward the front shoulder without
wrapping through a full circular recovery. The independent Batter actor's
hands and torso must move with that same profile timing so the bat does not
appear detached from a static character. Subtle aim-driven load height/tilt
remains partially visible through contact rather than disappearing at the
instant the Swing becomes authoritative.

The virtual contact center moves through the aimed plate point on the Swing
Profile's authored attack-angle plane. Matching the bat path to the descending
Pitch therefore increases timing forgiveness naturally, while a mismatched
path changes vertical offset, launch, and spin. The pointer still chooses the
intended X/Y contact point; this attack-plane travel is not a hidden aim assist.

Opponent Batters have readable approach memory. Repeating a recognized Pitch
or visible location increases awareness and execution, while changing speed,
shape, and location reduces predictability. They may consider visible flight,
count, handed inside/outside geometry, and player ratings, but never the
pitcher's hidden intended target or unreleased input.
The location read projects current visible position and velocity a short distance
toward the contact plane, with gravity. It does not treat the ball's X/Y several
meters in front of the plate as its final location. It is an imperfect estimate,
not access to the future solver trajectory; late break, chase, takes and misses remain.

## Contact Swing

- larger spatial/timing forgiveness
- lower maximum exit-velocity ceiling

## Power Swing

- smaller spatial/timing forgiveness
- higher exit-velocity ceiling

## Direction

Timing influences spray:

- early → pull
- centered → center
- late → opposite field

Vertical bat/ball relationship influences:

- grounder
- line drive
- fly ball
- launch angle
- backspin tendency

Stats and modifiers should amplify user execution rather than replace it.

---

# 7. Pitching

## Core loop

Choose **Pitch → target location → effort/execution → release**.

No steering after release.

The player's release timing is an execution input, not a post-release steering
system. Control widens the useful timing window, fatigue narrows it, and the
result feeds the existing command/error model. A held delivery auto-releases so
the match cannot remain stuck indefinitely.

Mouse pitching projects the pointer onto the plate plane. Pressing and holding
left click begins the same execution meter as the keyboard/controller delivery;
releasing commits the Pitch. Mouse and keyboard feed the same pre-flight aim,
effort, and execution pipeline, with no instant-quality shortcut and no
mid-flight steering.

The prototype release meter places its command sweet spot late in the motion.
The short tail beyond that spot is a bounded overdrive choice: fast Pitches may
gain a little velocity and breaking Pitches a little movement, but command and
Stamina efficiency worsen. This is release execution layered on top of effort,
not a replacement for effort and not a free power bonus.

Effort applies to every Pitch rather than belonging only to fastballs. A harder
Eephus, Slider, Drop, or other off-speed Pitch is still that Pitch, but travels
faster within a bounded range. Higher effort costs more Stamina and is harder
to command; lower effort trades speed for efficiency. Effort must preserve
Pitch identity rather than collapsing every max-effort Pitch into a Four-Seam.

## Pitch terminology

For game-facing terminology, a **Pitch** already includes its delivery/arm slot.

Therefore:

- Overhand Sinker
- Sidearm Sinker
- Submarine Sinker

are three different Pitches.

Internally, code may use `PitchDefinition`, but player-facing documents should simply say **Pitch**.

## Standard deliveries

- Overhand
- Three-Quarter
- Sidearm
- Submarine

Underhand or stranger deliveries may appear later.

Every player has a **Natural Delivery**.

Alternate deliveries are allowed but normally incur soft penalties such as:

- worse Control
- greater execution difficulty
- less movement consistency
- higher Stamina cost

Traits, Gear, Endorsements, or other effects may reduce, remove, or reverse those penalties.

## Pitch categories

### Fastballs

Velocity/power-oriented.

Examples:

- Four-Seam Fastball
- Two-Seam Fastball
- Sinker
- Cutter

### Breaking Balls

Movement/shape-oriented.

Examples:

- Slider
- Sweeper
- Curveball
- Slurve

### Off-Speed

Timing/deception-oriented.

Examples:

- Changeup
- Splitter
- Forkball
- Screwball

### Unconventional

Extreme trajectory, instability, or timing disruption.

Examples:

- Eephus
- Knuckleball
- Knuckle-Curve
- increasingly fictional Pitches

## Pitch design law

Every named Pitch must answer:

**Why would I throw this instead of another Pitch?**

A Pitch should not exist only as a minor numerical variant.

Identity can come from:

- velocity
- release point
- break direction
- break timing
- arc
- deception
- instability
- stamina efficiency
- Control demands
- risk/reward

---

# 8. Pitch Physics

Pitch names are tactical identities, not hardcoded canned curves.

Pitch flight may depend on:

- initial velocity
- release point
- spin rate
- effective/true spin
- spin axis
- ball orientation
- perforation/hole orientation
- ball condition/surface profile
- drag
- lift
- stability
- wind
- delivery geometry

Important physics principle:

**Movement magnitude and movement direction are separate concepts.**

Higher spin does not automatically mean “more Break.” Effective spin, spin axis, velocity, release, orientation, and plastic-ball asymmetry combine to determine flight.

Plastic-ball behavior may deliberately exaggerate familiar baseball pitch shapes.

Throwing handedness mirrors lateral flight, not vertical pitch identity. Drop
must still dive for a left-handed Pitcher; Four-Seam backspin and Riser lift
must not become topspin. The 2026-09-22 human recording exposed an incorrect
spin reflection. Spin, hole orientation and seeded perturbations now mirror
consistently while preserving the right-handed recipes and existing coefficients.

## Knuckleball

Not implemented as arbitrary random zig-zagging.

Low spin and unstable orientation should cause changing aerodynamic forces. Any deterministic wobble/noise should be seeded for reproducibility.

## Eephus

Handled by the same flight model using very low initial velocity and a high arc rather than by a special fake trajectory.

---

# 9. Repertoire

Approximate repertoire capacities:

- poor pitcher: ~2 Pitches
- normal pitcher: ~3
- good pitcher: ~4
- elite pitcher: ~5–6
- rare/special pitcher or modifiers: potentially 6–8+

All known Pitches are normally available every pitch.

Modifiers may temporarily alter availability.

There is no generic default “Straight” pitch.

## Learning Pitches

Pitches can be acquired during a season.

If the player is at capacity, learning a new Pitch requires forgetting one.

Season-learned Pitches reset at season end.

Permanent progression unlocks Pitches into future availability pools rather than permanently teaching them to a character.

---

# 10. Stamina and Pitching Changes

Pitchers may remain in at **0 Stamina**.

Low/zero Stamina creates increasing risk through:

- Control deterioration
- reduced velocity
- less consistent movement
- execution failures
- hangers

Fatigue is deliberately back-loaded. It is virtually unnoticeable through 50%,
ramps gently through 83% fatigue, then steepens below 17% Stamina remaining.
At zero Stamina, Pitches approach batting-practice quality while
still reaching the plate.

The human-QC baseline increases match Stamina capacity by 8%. At 20% remaining,
Pitches should still be usable. Flight compensation happens after weakening the
stuff and before adding command error, so lost movement does not routinely make
the ball unreachable. Slower, flatter, less accurately located Pitches are the
penalty; underground deliveries are not the intended fatigue mechanic.

A hanger should emerge from reduced velocity, lost movement, execution error,
and a seeded tendency for tired edge targets to leak toward the heart. Fatigue
may progressively regress command toward center, but must not replace every
target with one deterministic center-cut result.

Pitching changes:

- only between batters
- once a player has thrown a Pitch and is removed, they cannot pitch again that game
- removed pitchers remain eligible to bat and serve as Primary Fielder
- pre-Pitch lineup previews do not consume a pitching appearance
- Stamina remains where it was
- no default passive regeneration

The starter AI checks at legal between-Batter boundaries and replaces a Pitcher
at 17% Stamina or less if an eligible fresher arm exists. It does not rotate by
inning or reuse removed pitchers. If no replacement exists, the current arm stays.

---

# 11. Defense

## Defensive assignments

At the beginning of a defensive half-inning, the team has:

- one active Pitcher
- one active Primary Fielder

The Primary Fielder must be one of the other three players.

The remaining two players are inactive defensively at that moment.

## Between batters

The player may change:

- Pitcher
- Primary Fielder

Selections persist until changed.

Every authored Primary Fielder anchor must maintain clear physical separation
from the Pitcher. A valid strategic grid position may never spawn both visible
defenders on top of one another.

If the current fielder becomes the Pitcher, another player must be selected as the Primary Fielder.

## Before each pitch

The Primary Fielder can be positioned at seven legal anchors arranged in a
persistent 3×3 tactical grid:

| Depth | Left | Center | Right |
|---|---|---|---|
| Deep | Deep Left | Deep Center | Deep Right |
| Middle | Middle Left | Pitcher lane — unavailable | Middle Right |
| Shallow | Shallow Left | Pitcher lane — unavailable | Shallow Right |

The starter field reserves the shallow- and middle-center cells for the
Pitcher's delivery sightline and comebacker responsibility. Deep Center remains
available for true center-field coverage. Shallow side anchors may be level
with or in front of the mound, provided they remain laterally clear of Pitch
flight and both gameplay-camera sightlines. The starter shallow side anchors
are at X +/-5.5 m, Z 8.5 m. Position persists until changed.

Opponent defense also repositions between batters among the same legal anchors.
Its authored baseline uses the visible Batter's handedness and Power to choose
among shallow/middle/deep and pull/center/opposite anchors, with deterministic
seeded variation rather than hidden knowledge of the coming contact.

Position locks once the pitching motion begins.

The Primary Fielder stays at the selected anchor through delivery and Pitch
flight, then may charge forward after contact. It must move around the Pitcher,
not through them. Local body clearance follows the actual Pitcher position and replaces any blanket
behind-mound movement restriction. This does not enlarge the Pitcher's 0.60 m
ball-control radius. Collision-induced stumbles/errors remain deferred.

The positioning UI may enter a temporary overhead Field Setup view with seven
legal anchor choices and two visibly disabled Pitcher-lane cells, then return
to the normal pitching camera before play.

## Pitcher defense

The Pitcher automatically participates on:

- comeback liners
- weak grounders
- close mound-area plays
- possible hard deflections

The Pitcher retains a 0.60 m control radius around the visible actor. After
contact and a 0.20 s reaction delay, they may pursue nearby moving grounders and
air balls with a reachable predicted intercept within 5.0 m of the original mound.
Fielding-scaled speed is 3.6–4.6 m/s, below Primary Fielder pursuit speed.
They must physically reach the ball and respect the Primary Fielder's body
clearance. This does not permit movement into a live Pitch or distant pursuit.
Air catches still require actual horizontal and vertical reach, with no remote control.

Charging ground-ball control follows the ordinary Single rule. Only clean
moving control inside the original fixed mound envelope can erase a Single
floor; stopped balls, bobbles, and Double-or-higher floors remain safe. The
ball's swept frame segment establishes any scoring floor reached before control
and prevents fast comebackers from tunneling through the reaction envelope.

## Fielding outcomes

Base defense should be deterministic/readable rather than built primarily on hidden random percentages.

The interaction must also match the visible play: a Primary Fielder cannot
cleanly control a ball outside the authored horizontal or vertical reach
envelope merely because the planner predicted a nearby intercept. Movement,
reach, reaction delay, and clean-control difficulty remain separately tunable.

Possible outcomes:

- clean field/catch
- bobble
- deflection
- miss

Fielding difficulty can consider:

- ball speed
- trajectory
- reach
- arrival timing
- bounce complexity
- Fielding stat
- applicable Fielding Ability

---

# 12. Ball-in-Play / Hit Resolution

Governing principle:

**Defense determines whether the ball is stopped. The field determines what an unstopped ball is worth.**

Baseline starter-field rules:

- caught fly → Out
- ground ball cleanly controlled before safe territory → Out
- fair ball beating defense into ordinary safe territory → Single
- untouched deep airborne ball → Double
- ground/bouncing ball reaching back wall/fence → Double
- back wall/fence struck on the fly → Triple
- HR boundary cleared on the fly → Home Run

The Single and Deep Air planes must create distinct readable territories rather
than sit as neighboring stripes. On the starter field, the Single plane sits at
11.25 m, 2.466 m in front of the mound; the Deep Air plane sits at 17.0 m; and
the back wall remains at 23.4 m. This creates a 5.75 m ordinary-safe band and a
separate 6.4 m final band. The Pitcher's fixed 0.60 m mound envelope is an
explicit comebacker exception to the ordinary Single floor. The Deep Air plane
is not a universal “Double line”: only an untouched airborne ball earns its
Double floor there. Grounders still require the wall for a Double.

The 0.75 m Single adjustment follows explicit human playtest feedback. The prior
100,000-ball proxy evaluated 10.5 m, not 11.25 m; its result percentages must not
be presented as validation of this revision. A new normal-play F3 sample is required.

Individual parks and ground-rule objects may override baseline rules.

## Bobbles

Human rule clarification, 2026-09-22: a bobble on the plate side of the authored
Single line is an immediate dead-ball foul, whether airborne or grounded and
whether touched by the Pitcher or Primary Fielder. It awards no bases or Out;
normal foul-count rules apply, and runners hold. A later deflection, recovery
or boundary crossing cannot change that dead result.

At or beyond the Single line, the existing live-bobble rule remains: a fair
bobble establishes at least a Single, while recovery may prevent further
advancement. Bobbling does not itself add another base. A subsequent wall
contact can still produce a Double. An airborne recovery can still be a catch.

---

# 13. Field Object Architecture

Field objects fall into three gameplay categories.

## Live Object

Physical collision; ball remains live.

Examples:

- wall
- tree
- chair
- pole

## Dead Ground Rule

Collision immediately resolves an authored result.

Examples:

- pool = Double
- special window = Home Run

## Physics Modifier

Changes the ball but keeps play live.

Examples:

- ramp
- trampoline
- fan
- mud
- special bounce surface

This architecture must support absurd later fields without rewriting core ball-play rules.

---

# 14. Season Structure

## League size

6 teams total:

- player club
- 5 AI clubs

## Schedule

Double round robin:

- each opponent once home
- each opponent once away
- 10 regular-season games

Other AI-vs-AI games are resolved through lightweight simulation, producing real standings.

## Playoffs

Top 4 qualify.

- Semifinal: single elimination, higher seed hosts
- Championship: single elimination, special neutral field

The first playable shell ranks by wins, run differential, runs scored, then a
seeded preseason draw. This is a provisional tiebreak policy for testing.

### First Season Shell — 2026-09-21

The user authorized this bounded shell after the final sport audit. That is
permission to test season flow, not a declaration that camera feel or the sport
fun gate has passed. The starter implementation contains:

- Main menu: Continue Season, New Season, Exhibition, Quit.
- One provisional Backyard League with Base difficulty for new seasons. The old
  Relaxed / Standard / Tactical selector described pitching strategy only and
  has been removed; saved presets retain their original behavior. Base retains
  the previous Standard tactical baseline without retuning the sport.
  The existing environment is Yard Club Field for home games;
  Commons Park is the shared away venue for the five opposing clubs. Five regular
  games use each venue. Semifinals follow the higher-seed host; the neutral final
  uses Commons Park regardless of nominal home/away inning roles. These are two
  distinct environments with the same current scoring geometry and collisions.
- Four tryout rounds, three distinct authored player cards per round, one choice
  each. The 48-player authored pool supplies six unique four-player clubs, so
  only 24 characters are active in a given season. A new draft exposes at most
  one four- or five-pitch specialist among its twelve offers; none is guaranteed.
  Most players start with two or three Pitches. The full pool is unlocked for
  this prototype; achievement-based collection access is not implemented yet.
- A season hub with standings, schedule, directly visible seven-stat lineup,
  batting-order changes, starting Pitcher
  and Primary Fielder selection. Equipment stays at the vanilla defaults.
- Ten player games, five home and five away; home/away correctly determines the
  opening batting/pitching role. All match rules remain authoritative.
- Lightweight seeded AI results for the two other games each round; top-four
  semifinals pair 1–4 and 2–3, then a neutral final. Eliminated seasons still
  resolve the remaining bracket and display a champion.
- Postgame scores and standings, followed by the next-game hub or season results.
- The hub foregrounds the club record, league position, next opponent and
  opening defenders. Prepare Next Game opens the editable pregame lineup with
  the actual opponent starter/arsenal and home/away opening role. Postgame can
  proceed directly to that next pregame screen. Lineup edits preserve scroll.
- Draft comparisons use a selected existing player as the reference, with
  signed differences for all seven ratings and visible handedness/arsenal.
  The weakest of the roster's best ratings is a coverage hint, not an optimal
  pick recommendation or a new gameplay rating.
- Completed player games retain individual PA, hits, doubles, triples, homers,
  walks, strikeouts and RBI; Pitchers retain outs, hits/walks allowed,
  strikeouts and actual Pitches thrown. Postgame and Team Stats show these
  observations. Stats follow player IDs through lineup/defense changes and
  include playoffs. AI-only simulated scores do not fabricate player stats.
- Distinct season recaps identify missed playoffs, semifinal elimination,
  championship runner-up or champion, with recorded hitting/pitching leaders,
  final bracket and regular-season standings. The finished season remains
  inspectable until a new season is confirmed; no career archive is implied.
- Hub/season recap > Player Ratings and Team Stats > Player Ratings expose a separate
  read-only roster attribute page between games, including all seven ratings,
  full Pitches, hands and defensive assignments.
- Pause > Player Ratings & Stats inspects either team's seven ratings, full repertoire,
  batting/throwing hands, defensive assignments, remaining Stamina and used arms.
  This Game shows current batting/pitching observations, with pitch counts up to
  the current delivery and batting outcomes after completed plate appearances.
  The Bullpen labels every player's throwing hand directly beside Stamina/status.
  Inspection is read-only and freezes play; Back/Esc returns to Pause before
  resuming. This is not an in-game batting-order or equipment editing window.
- Local checkpoints after draft/lineup changes and as soon as a match is final.
  An interrupted unfinished game restarts from its beginning. There is one save
  slot, with confirmation before replacing it, and no midgame resume.
  The prior valid checkpoint is backed up locally. Version-1 saves migrate using
  their original 24-player pool; saved version-2 offers and AI strength snapshots
  do not reshuffle when the catalog grows. Recovery is reported on the menu.
  Schema 3 adds completed-game performance snapshots. Schema 1/2 scores remain
  valid; their absent statistics are explicitly reported, never backfilled.

Pitchers start each game fresh in this first shell; in-game fatigue and no
pitching re-entry remain unchanged. Intergame recovery, mechanically unusual venues,
opponent development, economy and persistent career rewards are later systems.

---

# 15. Opponents

Opponent clubs have authored strategic identities rather than random stat soup.

They visibly develop over the season through:

- better/expanded Pitch repertoires
- traits
- Gear
- Endorsements
- field identity
- strategic behavior

Rematches should feel like evolved versions of the same opponent.

Difficulty escalation follows calendar/opponent development rather than rubber-banding against the player's record.

AI must not read hidden player input.

The first tactical model weights owned Pitches by signature preference, Power /
Breaking / Corners / Balanced identity, count and previous-Pitch speed contrast.
Breaking specialists may repeat their favorite heavily; repertoire size does
not imply equal use. Three-ball counts favor strikes, two-strike counts allow
bounded expansion. The current internal tactical preset increases edge targeting
and sequencing, not invisible stat inflation, command accuracy or ball physics.
It is one possible component of overall Difficulty, not the Difficulty system.
Tactical quality also rises modestly with schedule position, never with the player's win/loss record.
These are authored gameplay heuristics, not an MLB-optimal strategy claim.

---

# 16. League and Difficulty

## League

League is the **Balatro Deck analogue**.

Chosen before the season.

Only a small starter set of Leagues is initially unlocked in the future launch
catalog; additional Leagues are earned. Exact count, identities and unlock
conditions remain to be authored. The current shell implements Backyard League
only; it must not display unfinished Leagues as playable.

Its structural rule persists for the run.

Early Leagues are simple. Later Leagues may radically alter:

- roster construction
- pitching rules
- Stamina
- economy
- shop structure
- field behavior
- modifier availability
- season rules

A League can eventually introduce rules such as starting with only three players and an open roster slot.

That is **not** the base game.

## Difficulty

Difficulty is the **Balatro Stake analogue**, separate from League. It governs
overall season pressure, not just AI pitching or a single stat multiplier.

Progression is tracked independently for each League. Only Base is initially
unlocked for each available League; higher tiers must be earned within that
League. Unlock milestones, tier names and pressure combinations remain undecided.
The current shell offers Base only and does not implement progression unlocks.

Higher Difficulty may increase:

- economy pressure
- opponent development
- roster constraints
- shop pressure
- AI tactical quality
- recovery pressure
- special conditions

Avoid relying on invisible stat inflation as the primary difficulty mechanism.

## Stadium and field progression goal — human amendment, 2026-09-22

Venue progression is a Phase 6 goal: later-season/playoff destinations and more
advanced Leagues can feel larger and more prestigious. Grow stands, lighting,
architecture, atmosphere and presentation independently from playing dimensions.
Selected advanced away/neutral parks may also have larger or otherwise distinct
playing areas once authored builds and human playtesting support them. Field
size is one visible strategic pressure, not the sole Difficulty scale.

Keep the present field/hitting baseline and pitching geometry/feel. No blanket
1.3× scaling, automatic fence movement after upgrades, or per-game stretching
of the home field is approved. Home structural development remains Phase 7,
between seasons with the Opening Day layout lock. Communicate any future park
rules/dimensions before the game; they must agree with physical geometry, scoring,
defense, cameras and saved fixtures. Exact dimensions, venue sequence and tier
assignments need bounded prototypes and human QC after the build catalog.

See `FIELD_SCALE_AND_PROGRESSION_AUDIT.md` for the research and sensitivity study.
This accepts the progression goal without introducing those mechanics now.

---

# 17. Player Abilities

Seasonal player development is broader than Pitches.

## Hitting Abilities

Player-specific seasonal effects that alter hitting strategy/execution.

Prototype target: **1 active Hitting Ability per player**.

Examples only:

- Two-Strike Approach
- Dead Red
- High-Ball Hitter
- Pull Happy
- Opposite Field
- First-Pitch Swinger
- Wall Hunter

## Fielding Abilities

Player-specific seasonal effects that alter defensive behavior.

Prototype target: **1 active Fielding Ability per player**.

Examples only:

- Quick First Step
- Soft Hands
- Wall Rat
- Line-Drive Reader
- Barehander
- No Fear

Fielding Abilities may apply to Pitcher defense when appropriate.

## Replacement

If a Hitting or Fielding Ability slot is already occupied, learning another replaces the current one.

Learned Hitting/Fielding Abilities reset at season end.

They are not normally sellable once learned.

## Intrinsic Trait

A player's intrinsic trait is separate from seasonal Abilities and is part of the character's base identity.

---

# 18. Seasonal Build

Short form:

**Roster + Abilities + Pitches + Gear + Endorsements**

Where:

- **Abilities** = Hitting Abilities + Fielding Abilities
- **Pitches** = repertoire items, each already including its arm slot
- **Gear** = physical equipment
- **Endorsements** = team-wide seasonal engine pieces

---

# 19. Gear

Initial Gear scope is deliberately small.

## Bat

Each player equips one active Bat.

Potential effects can touch:

- Contact forgiveness
- Power
- launch tendencies
- contact-type interactions
- Hype
- special triggers

## Ball Setup / Ball Prep

The team has one active Ball Setup by default.

It may alter:

- Break
- stability
- Control
- Velocity
- Pitch-family behavior
- plastic-ball aerodynamic behavior

Effects may later allow carrying or switching multiple ball setups.

## Inventory baseline

Prototype recommendation:

- one active Bat per player
- one active team Ball Setup
- small reserve Gear inventory
- free pregame configuration
- Gear normally locks once the first pitch is thrown
- special effects may allow midgame swaps

Gear is sellable.

---

# 20. Endorsements

Endorsements are the closest Joker-like engine system.

They are:

- team-wide
- season-local
- passive/rule/economy/build effects
- sellable/replaceable
- limited-slot

Prototype target: **around 5 active Endorsement slots**.

Exact slot count remains a tuning variable, not a sacred number.

Endorsements may be themed as absurd sponsors, from tiny local businesses to increasingly major brands.

Not all Endorsements should be money effects.

---

# 21. Shop

The first shop appears after Game 1.

A shop appears after every regular-season game.

Core offer categories:

- Gear
- Abilities
- Pitches
- Endorsements

Player-facing presentation may group Hitting/Fielding Abilities together while keeping Pitches distinct.

Free Agents appear occasionally as a special roster opportunity before the trade deadline.

Prototype target: roughly 5 normal mixed offers.

Generation should have diversity protection so obviously useless all-one-category shops are uncommon unless intentionally caused by a modifier.

## Rerolls

Paid with Season Cash.

Reroll cost escalates during the current shop visit and resets at the next shop.

## Selling

- Gear: sellable
- Endorsements: sellable
- learned Hitting/Fielding Abilities: not normally sellable
- learned Pitches: not sellable

Approximate starting sell-value target: ~50% purchase price, subject to economy simulation.

---

# 22. Rarity

Initial rarity vocabulary:

- Common
- Uncommon
- Rare
- Exotic

Anything may theoretically appear early.

High-rarity odds improve mildly later in the season.

Anti-drought protection may prevent an entire 10-game season from never surfacing interesting high-rarity content.

Rarity should primarily represent:

- specialization
- strangeness
- build-defining potential
- rule-breaking capability

not simply larger numbers.

---

# 23. Free Agents

Free Agents appear occasionally before the roster deadline.

Signing one immediately replaces one of the four active players.

No bench in the baseline.

The departing player takes with them:

- seasonal stat development
- learned Hitting Ability
- learned Fielding Ability
- learned Pitches

Equipped Gear returns to the team inventory rather than disappearing.

## Trade deadline

Current recommendation: **after Game 6**.

The Game 6 postgame shop is the final roster-change opportunity.

After leaving it, roster locks for Games 7–10 and playoffs.

Exact Free Agent appearance frequency remains a simulation/tuning decision.

## Locked-player seasonal appearances

A named player may occasionally appear as a Free Agent or special seasonal
opportunity before their permanent player card has been unlocked.

Recruiting that player grants access only for the current season. It does not:

- add them to future preseason draft pools
- mark their permanent player card as owned
- bypass their achievement or pack-eligibility requirement

Encountering a locked player may reveal their collection slot, identity, and an
appropriate unlock hint in Records & Unlocks. This creates discovery without
turning a lucky seasonal appearance into permanent progression.

---

# 24. Roster Construction

Baseline recommendation:

**Four-round tryout draft.**

Each round draws from the player's permanently draftable player-card pool:

- 3 player cards appear
- choose 1
- repeat four times

This exposes 12 candidates and produces 4 selected players without forcing a giant preseason roster screen.

Soft protections may prevent completely dysfunctional offer sets, but there are no conventional fielding positions because all players are two-way.

This remains a strong baseline but can be adjusted after prototype testing without changing core architecture.

---

# 25. Player Definitions

A player definition includes at least:

- Name/visual identity
- Handedness
- Contact
- Power
- Fielding
- Velocity
- Break
- Control
- Stamina
- Natural Delivery
- Pitch capacity
- Starting Pitches
- Intrinsic Trait

Players should be **authored named characters**, not anonymous procedural stat bundles.

Quality should emphasize specialization and tradeoffs rather than a strict universal hierarchy.

---

# 26. Seasonal Player Development

Player development should remain lighter than a traditional sports RPG.

Current prototype recommendation:

Three development breaks across the regular season, roughly after Games 3, 6, and 9.

Possible simple upgrades:

- +1 Contact
- +1 Power
- +1 Fielding
- +1 Velocity
- +1 Break
- +1 Control
- +1 Stamina

Rarer development may alter:

- Pitch capacity
- alternate-delivery penalty
- fatigue tolerance

All seasonal stat development resets after the season.

Exact cadence is not locked until the economy/run simulation is tested.

---

# 27. Season Cash

Temporary run currency.

Resets every season.

Used for:

- Gear
- Abilities
- Pitches
- Endorsements
- Free Agents
- rerolls

Winning pays substantially more than losing.

A loss still pays something.

Hype adds bonus income, but a great loss should not normally be economically equivalent to a win.

Exact numbers and price bands remain explicitly deferred to simulation.

---

# 28. Hype

Working name for the secondary performance system.

Runs remain the only score that determines who wins.

Hype can reward:

- perfect contact
- Home Runs
- extra-base hits
- unusual field interactions
- strikeouts
- called strikeouts
- three-pitch strikeouts
- escaping jams
- walkoffs
- modifier chains

Hype contributes to Season Cash payout.

Score Attack may later reuse Hype as the primary score.

The name **Hype** remains provisional.

---

# 29. Persistent Progression

Design law:

**Your club persists. Your build resets.**

## Persistent

- club name/identity
- jerseys/uniforms
- emblem/branding
- home stadium
- owned stadium pieces
- career records/history
- trophies/accomplishments
- League × Difficulty clears
- unlock pools
- owned player cards / permanently draftable player pool
- player-card collection discovery
- cosmetics

Potentially named-player career statistical history may persist as history only, not power.

## Player-card collection and unlocks

Named players are represented by baseball-style player cards in the persistent
Records & Unlocks collection. These cards are roster identities and stat
references, not temporary Gear and not permanent stat upgrades.

Each player card can occupy three distinct progression states:

1. **Encountered** — the player has appeared in a season; their collection slot
   and an appropriate unlock hint may be revealed, but they remain locked.
2. **Pack-eligible** — the player has entered the reward pool because their
   prerequisite is satisfied or they belong to the baseline pack pool.
3. **Draftable** — the card has been permanently obtained and the player can
   appear in future preseason tryout drafts.

Player-card packs can be purchased with persistent Club Bucks and offer cards
from the currently eligible pool. Whether separate free season-end packs are
also awarded remains open. Obtaining a card permanently moves that player into the draftable pool.
The reward pool may contain:

- baseline players available from the beginning
- players made pack-eligible by League/Difficulty clears, records, stadium
  milestones, or other achievements
- rare players available only after a specific hidden or visible condition

Some achievements may award a specific player card directly instead of merely
adding that player to the pack pool. The reward presentation must distinguish
clearly between **made pack-eligible** and **card obtained**.

Player-card packs use earned in-game Club Bucks, not real money.
They expand roster-building options without granting permanent universal stat
power. Packs should prioritize unobtained eligible players; exact pack size,
choice format, and duplicate protection remain tuning decisions.

## Resets every season

- roster composition
- seasonal stat upgrades
- learned Hitting Abilities
- learned Fielding Abilities
- learned Pitches
- Gear
- active Endorsements
- Season Cash
- Stamina/fatigue
- shop state
- temporary synergies/conditions

---

# 30. Club Bucks (previously Club Funds)

Persistent currency. References to Club Funds elsewhere mean this same resource.

Primarily awarded at season end. A completed losing season still awards some
Club Bucks. Missing the playoffs, reaching the playoffs, and winning the
championship must have significantly different payouts, increasing with success.
Exact amounts, runner-up versus semifinal-loss differences, and record-based
adjustments remain open. Abandoned-season rewards are not decided.

Approved 2026-09-22, blueprint BP-002: Club Bucks can purchase stadium ownership
and player-card packs. This amends the earlier earned-packs-only direction;
buying a pack does not bypass its players' eligibility requirements.

Potential payout factors:

- season completion
- record
- playoff finish
- championship
- Difficulty
- first League × Difficulty clear
- career achievements
- major records/accomplishments

Club Funds buy persistent club/stadium ownership such as:

- player-card packs
- stadium parts
- venue infrastructure
- uniforms
- emblems
- branding
- cosmetics

Avoid using Club Funds to buy permanent universal stat power.

Preferred model:

**unlock + purchase**

Progression unlocks a permanent item into the available catalog.

Club Funds purchase ownership.

Player cards obtained from purchased packs or direct achievement rewards become
permanently draftable without an additional purchase after obtaining the card.

Once owned, remodeling among owned pieces is generally free between seasons.

---

# 31. Home Stadium

The Home Stadium is the player's persistent career avatar.

Progression fantasy:

backyard  
→ organized yard  
→ neighborhood field  
→ town venue  
→ regional plastic-ball park  
→ sophisticated miniature stadium

Potential additions:

- baselines
- backstop
- fencing
- foul poles
- benches
- bleachers
- manual scoreboard
- lights
- concessions
- PA/scorer structures
- sponsor architecture
- custom landmarks
- surfaces

Geometry generally affects both teams symmetrically.

Strategic value comes from learning and building around the field, not permanent asymmetric power.

Structural remodeling occurs **between seasons**.

Opening Day locks structural configuration through the championship.

Temporary League/modifier conditions may still alter a field.

---

# 32. Secondary Modes

After Season Mode is proven:

## Score Attack

Short offense-focused score chase using Hype/physical-field interactions.

## Challenge Mode

Handcrafted scenarios and restrictions.

## Practice / Wiffle Lab

Pitching/batting experimentation and tuning.

---

# 33. Visual Direction

- stylized full-3D characters
- stylized physical 3D fields
- illustrated 2D portraits/cards/UI
- DIY neighborhood/rec-league aesthetic
- progressively more organized/absurd presentation

Avoid:

- realistic sports rendering
- direct Backyard Baseball imitation
- cheap generic mobile gloss

Audio should enter early:

- plastic bat thwack
- ball whoosh
- strike target impact
- fence/wall/material impacts

## Menu clarity and style — human QC amendment, 2026-09-22

Menu quality is the immediate priority before enrichment implementation. Use a
consistent clubhouse/scorecard presentation: deep green surfaces, warm cream
text, amber primary actions/selection, restrained field-line decoration and
clear heading/body/helper hierarchy. Keep full Pitch names, seven named player
attributes and distinct throwing/batting hands. Color supplements text and
selection marks; it never replaces the numerical rating differences.

Season pages, draft/player cards, statistics, schedule, Pause, Settings, player
inspection, Pitch picker, Bullpen, Field setup and confirmation/continue controls
share this visual language. Keep the main next action prominent, secondary
navigation quieter, and navigation visible below scrolling content. Schedule
cards identify game, result/upcoming status and venue. Player Ratings names
attribute inspection explicitly; Team Stats remains recorded performance.

Pause/settings actions support keyboard focus and activation while game state
stays frozen. Do not add animation, camera movement or decorative UI over the
live pitching corridor as part of this menu pass. Human visual review remains
required before treating the menus as finished or proceeding with enrichment.

## Match presentation

A match begins with a short, skippable broadcast-style introduction. The game
automatically selects one, two, or three views from an authored camera pool and
displays a temporary game-start title before settling into the role camera.
The one-view variant is a deliberately longer take; multi-view intros vary
between two- and three-shot packages. Shots hold long enough to read rather
than cutting rapidly.
Each view may independently be still or use a subtle slow zoom, horizontal pan,
or vertical tilt selected from the authored presentation pool. Camera motion is
presentation-only and cannot alter game time or baseball state.
The player does not select these views. Game completion keeps the win/loss title
and final score over an infinite rolling loop of scenic camera angles. Each
result view lasts about 10 seconds and uses a slow zoom, pan or tilt; transitions
between angles are also slow. Continue becomes available after the initial
1.7-second settlement and stays available throughout the loop. Skipping that
settlement also keeps the camera rolling. Camera loops never advance game time,
score, records or save progression; Pause freezes the shot clock. These durations
are presentation tuning, subject to human motion-comfort QC.

When the player is defending, contact must preserve the pitching/defensive side
of the field. The camera pulls wider and tracks the physical ball from behind
the defense rather than flipping through 180 degrees to the Batter's view.
Player-offense ball-in-play tracking may retain its behind-the-Batter field
orientation. Ball visibility takes priority over a rigid camera location:
tracking may pan, rotate, change elevation or viewing distance smoothly while
preserving readable orientation. Static walls, poles and away scenery must not
hide the tracked ball. The current correction pulls toward overhead when blocked,
checks the interpolated view and eases back out when clear. Live Pitch views stay
stable; all tracking changes remain presentation-only.

Home Runs get a dedicated 4.4 s presentation hold. The scored ball continues
visibly beyond the wall for 1.25 s with camera tracking, then a wider celebration
view holds the Home Run call. A game-ending Home Run completes this sequence
before the outro. Scoring is final at clearance and cannot repeat during the carry.
The batting camera is modestly raised and tilted down to improve the plate view.
Its audited baseline is 2.10 m high, 3.38 m behind the plate, with a 0.18 m handed
offset and approximately 5.5 degrees of downward tilt. The smaller side offset
clears measured loaded-bat obstruction without changing height, FOV, aim mapping
or timing. The Batter and bat remain visible for the batting perspective.
Automated projection checks support readability, not a claim of optimal feel.

During play, a compact broadcast-style scorebug owns the persistent essentials:
team score, half/inning, count, outs, occupied bases, current Batter and Pitcher.
On player defense, a clickable Pitch panel owns repertoire selection, Pitch
count, Stamina and fatigue stage. Opponent condition remains in the scorebug
while batting. Pause > Settings moves the scorebug among bottom right, top left,
and top right and remembers the choice between launches. Routine Ball/Strike/Foul calls and compact Pitch
speed reports use small boxless text directly beneath the selected anchor.
Begin-at-bat, Strikeout, Out, hit result, and inning-change messages use larger
white text above screen center with a dark-blue outline and shadow. Batting
strike-zone and aim guides use reduced opacity; pitching guides remain unchanged.
Detailed simulation
telemetry remains in the explicit debug layer and should not duplicate or
obscure the scorebug.

Full names include authored delivery words such as Overhand and Sidearm in the
visible list, not only in tooltips. Number keys select the current Pitcher's
repertoire slots. The lab's nine-Pitch catalog is not a universal match shortcut map.

For switch hitters, a button beside the at-bat prompt names the opposite batting
side, with a small current-side cue and B shortcut. It is offered before readiness
and disappears when the at-bat begins. The side stays locked through tactical
timeouts; stance, bat, scorebug, camera and contact use the same effective hand.
Throwing handedness remains fixed. Ordinary hitters do not receive this control.

The Pitch panel uses a compact numbered list with full names and short tactical
descriptions only on hover, and a clear selected state; it collapses to the selected Pitch during delivery and
clears for Home Run presentation. Defensive controls are labeled Field and
Bullpen. Esc is the sole keyboard pause/resume shortcut, also backing out of
nested menus. Footer text must clear the Pause button. Intro skip uses click or Space.

Presentation feedback uses distinct, short sounds for bat contact, clean fielding,
bobbles, wall impacts and Home Runs. Pause > Settings includes a saved Mute sounds
option. Muting stops active cues and discards new ones; unmuting never replays them.
The prototype uses original procedural sounds, with final mix/character awaiting
human listening QC. No gameplay information may depend on sound alone.

After contact, a subtle ground shadow and short historical trail help locate the
physical ball. The trail is restricted to fast batted balls, at most 0.065 s / 0.9 m
of past travel. Neither aid forecasts Pitch movement or a landing point. Pause
freezes the aids; cleanup removes them. No new camera shake or motion blur.

A brief strip beside the scorebug reports actual timing/aim, taken locations or
chased locations after contact/plate crossing. Inside/outside follows the Batter's
handedness. Bobbles show that the ball remains live and update when resolved.
Feedback expires after 3 s, freezes during pause, and clears for the next Pitch.
The existing Stamina bar turns red at 17% remaining or less; no additional
warning text is added. Existing percentage/condition text remains. This color
change does not add a fatigue penalty.
Pitch descriptions do not occupy permanent HUD space or require a hold gesture.

Catches and strikeouts receive at least 2.25 s of result time. Existing longer
inning transitions and the 4.4 s Home Run hold remain. Non-HR game-ending results
receive 2.5 s before the outro. Live bobbles never freeze for presentation;
short bobbles freeze because their dead-ball foul result is final.
These timings are authored QC defaults, not research-proven optimums.

The starter presentation may use a lightweight blue procedural sky, with a green
backdrop available from Pause > Settings and remembered between launches.
Paused camera inspection exposes all nine authored views, with smooth movement
and restoration of the prior gameplay view on resume. This is presentation only;
it does not change lighting-dependent gameplay or field rules.

Higher-stakes games may later use longer authored cinematic packages for
clinch opportunities, elimination games, playoff-round finales, rivalries,
championships, and major milestones. Those packages must remain readable,
skippable, state-driven presentation; they cannot create or change baseball
results. Detailed broadcast research and content production are deferred until
the vanilla sport clears its fun gate.

---

# 34. Technical Baseline

Godot is the production engine assumption unless implementation exposes a concrete blocker.

Baseline:

- Godot 4.7.2
- typed GDScript
- Mobile renderer
- Jolt for 3D collision/physical ball-in-play
- Blender → glTF/GLB
- Git/GitHub
- Steam/PC + iOS + Android as first-class architectural targets
- no multiplayer requirement in v1
- consoles deferred

Pitch flight uses a custom fixed-step aerodynamic solver rather than stock rigid-body flight.

Batted-ball play uses a hybrid of custom aerodynamic forces, Jolt collision, and authored baseball-rule resolution.

See `TECHNICAL_PREPRODUCTION.md`.

---

# 35. Development Roadmap

**Current repository position (2026-09-21):** Phase 3 is implemented through
starter-field scoring/Pitcher-lane fixes and player-flow hardening. Godot 4.7.2
verification covers import/smoke, core rules, seeded matches, live full matches,
player-input flow, actual Jolt ball fixtures, and QC exports. Paused inspection
and final-score/restart flow are included in the pre-playtest handoff. Focused
hands-on QC and meaningful result-distribution sampling remain, so the
Production Gate has not been cleared.
`IMPLEMENTATION_STATUS.md` is the canonical ledger for implemented and
runtime-validated work.

## Phase 0 — Foundation

Project structure, definitions, runtime state, content manifest, math conventions, debug scaffolding.

## Phase 1 — Pitch/Bat Lab

Pitch solver, aim, execution, strike zone, swing model, contact resolution.

## Phase 2 — Ball-in-Play Lab

Batted-ball physics, field rules, one fielder, pitcher defense, bobbles, ghost bases, sacrifice advancement.

## Phase 3 — Complete Vanilla Match

Four-player rosters, batting order, counts, Stamina, pitching changes, five innings, mercy, extra innings.

## Production Gate

The core sport must be fun before building the roguelite shell.

On 2026-09-21 the user authorized the initial Phase 4 Season Shell after the
final technical audit, with hands-on camera/feel QC still open. This narrow
amendment allows season-flow testing without treating automated checks as fun-gate approval.

## Phase 4 — Season Shell

Build the complete season structure around the validated vanilla game:

- preseason flow
- four-player roster construction and loadouts
- six-team league
- 10-game double round robin
- standings and lightweight AI-game simulation
- four-team playoffs

The first Season Shell should work with mostly vanilla player power so its
schedule, pacing, standings, and reset loop can be evaluated independently.

The 2026-09-22 user request also authorizes read-only pause statistics and a
second, visually distinct away venue using unchanged field rules. This bounded
venue addition does not authorize unusual field mechanics or Phase 5 systems.

## Blueprint-first planning amendment — 2026-09-22

The user directs the immediate work to connected design of Phases 5–7, piece by
piece with a maintained decision record. Planning starts now; it does not wait
for menu QC to finish. Human QC and concrete fixes remain separate from approval
to implement progression. Phase numbers continue to organize the eventual build,
not separate the design into isolated implementation/testing sprints.

`PROGRESSION_BLUEPRINT.md` is the central working blueprint and decision log.
It distinguishes approved rules, proposals, open questions and deferred work.
Reconcile approved decisions here before coding. Derive the implementation
framework and slices from the authored effects and cross-system rules; do not
begin a generic progression engine while these decisions are still being made.

## Phase 5 — Seasonal Build Systems

Layer the run-specific build economy onto the functioning Season Shell:

- Pitches
- Hitting Abilities
- Fielding Abilities
- Gear
- Endorsements
- Season Cash and Hype
- postgame shops and rerolls
- Free Agents and the Game 6 trade deadline

## Phase 6 — Opponents, Fields, Leagues, and Difficulty

Make repeat seasons strategically distinct:

- authored opponent identities
- opponent development across rematches
- unusual physical parks and field objects
- increasingly grand venues and selected larger advanced parks, with fixed pitching geometry
- League rules, a small initially unlocked set, and later League unlocks
- overall Difficulty progression tracked per League, starting with Base only

## Phase 7 — Persistent Club Layer

Connect seasons into a career without adding permanent universal stat power:

- season history and records
- player-card packs, collection discovery, and draftable-player unlocks
- broader unlock pools
- Club Funds
- stadium development
- visual club identity

Captain-retention enrichment idea: a mid/late-game achievement might unlock
optional season-to-season retention of one captain, with a choice to release
them and a reset toward their authored draft-level stats. This is recorded in
`ENRICHMENT_NOTES.md`, not an implemented unlock or permission to keep seasonal
stat power. Exact unlock, draft-slot treatment and reset/decay policy remain open.

## Phase 8 — Production and Content Scale

Bring the validated game to production quality:

- character animation and final bat presentation
- audio, effects, and UI polish
- broader player, Pitch, Ability, Gear, Endorsement, opponent, and field content
- performance profiling
- real-device mobile testing

Phase numbers describe dependency order, not a requirement to finish every
piece of one phase before starting safe preparatory work in the next. The first
Phase 4 shell is now authorized; human sport and season-flow validation still
precede full investment in Phases 5–8.

---

# 36. Explicitly Deferred / Tunable

These are **not unresolved architecture blockers**:

- exact item prices
- exact Season Cash payouts
- exact rarity percentages
- exact Free Agent frequency
- final Endorsement slot count
- exact development-break cadence
- exact shop category weights
- final Hype name/formula
- exact number of player cards offered per post-season pack
- player-card choice/reveal format and duplicate-protection details
- exact achievement-to-player eligibility mapping
- exact five-inning/mercy balance after real timing tests
- final pitch coefficient values
- final stat ranges
- final number of authored launch-day players/Pitches/Endorsements

These are to be tuned through simulation and playtesting rather than debated abstractly.

---

# 37. Change-Control Rule

This document is the canonical gameplay and progression source of truth.

When implementation reveals a conflict:

1. identify the concrete problem
2. test whether it is tuning, architecture, or design
3. prefer the smallest coherent change
4. update this document when the decision actually changes

Do not silently let code become a competing design document.
